import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:toastification/toastification.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';
import 'package:zephyr/service/lifecycle/notification_service.dart';
import 'package:zephyr/service/update/check_update.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/widgets/memory/memory_overlay_widget.dart';
import 'package:zephyr/widgets/toast.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/dialog.dart';
import 'package:zephyr/page/bookshelf/bookshelf.dart';
import 'package:zephyr/page/discover/view/discover_page.dart';
import 'package:zephyr/page/more/view/more.dart';
import 'package:zephyr/page/old_page/old_home/old_home_page.dart';
import 'package:zephyr/page/old_page/old_ranking/old_ranking_page.dart';

/// 导航目的地：图标名 + 标签。
class _NavDestination {
  final String icon;
  final String label;
  const _NavDestination({required this.icon, required this.label});
}

/// 从 `MiuixIcons.extended` 中按名字取图标，取不到就回退到 `home`。
///
/// Miuix 的 extended 图标集并非 Material Symbols 全量镜像，直接写
/// `byName('menu_book')!` 很容易因为名字不存在而抛
/// “Null check operator used on a null value”。这里统一走安全查找：
/// - 名字存在 → 用对应图标；
/// - 名字不存在 → 回退到 `home`（已知一定存在），debug 下打印警告。
MiuixIcon _miuixIcon(String name, {double size = 24, Color? tint}) {
  // 不显式写类型：byName 的返回类型在不同 flutter_miuix 版本里叫法不同
  // （IconData / MiuixVector / SvgData ...），交给 Dart 推断即可。
  final vector = MiuixIcons.extended.byName(name);
  if (vector == null) {
    assert(() {
      debugPrint(
        '[NavigationBar] MiuixIcons.extended 中不存在图标 "$name"，'
        '已回退到 "home"。请用 MiuixIcons.extended 里的实际名称替换。',
      );
      return true;
    }());
  }
  return MiuixIcon(
    vector: vector ?? MiuixIcons.extended.byName('home')!,
    size: size,
    tint: tint,
  );
}

@RoutePage()
class NavigationBar extends StatefulWidget {
  const NavigationBar({super.key});

  @override
  State<NavigationBar> createState() => _NavigationBarState();
}

class _NavigationBarState extends State<NavigationBar> {
  /// 当前选中的 tab
  int _selectedIndex = 0;

  /// 桌面/平板导航栏的展开状态
  late final MiuixNavigationRailState _railState;

  final debouncer = Debouncer(milliseconds: 100);
  DateTime? _lastLoginNavigateAt;
  String? _lastLoginPluginId;
  DateTime? _lastToastShownAt;
  (ToastType, String?, String, Duration)? _lastToastEvent;

  static bool _notificationsInitialized = false;
  bool _isInitializingNotifications = false;
  static bool _followUpdateChecked = false;

  @override
  void initState() {
    super.initState();

    _railState = MiuixNavigationRailState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      checkUpdate(context);
      _autoSync();
      manageCacheSize(context);
      DownloadQueueManager.instance.resetStuckTasks();
      DownloadQueueManager.instance.watchTasks(
        startupResumeDelay: const Duration(minutes: 1),
      );
      if (Platform.isAndroid) {
        await ForegroundTaskService.instance.syncOnAppStart();
      }
    });

    final globalSetting = objectbox.userSettingBox.get(1)!.globalSetting;
    final configuredIndex = globalSetting.welcomePageNum;
    final initialIndex = _normalizeWelcomePageIndex(
      configuredIndex,
      _buildPageList(globalSetting.oldPageRollbackEnabled).length,
    );
    _selectedIndex = initialIndex;

    ForegroundTaskService.instance.init();
    initializeNotificationsOnce();
    _scheduleFollowUpdateCheck(context);

    const duration = Duration(minutes: 5);
    Timer.periodic(duration, (Timer timer) async {
      await _autoSync();
    });

    eventBus.on<NoticeSync>().listen((event) {
      _autoSync(force: event.force);
    });

    eventBus.on<NeedLogin>().listen((event) {
      _goToLoginPage(
        event.from,
        loginScheme: event.scheme,
        loginData: event.data,
        message: event.message,
      );
    });

    eventBus.on<ToastEvent>().listen((event) {
      _showToast(event);
    });
  }

  @override
  void dispose() {
    _railState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final globalSettingState = context.watch<GlobalSettingCubit>().state;
    final backPressExitEnabled =
        Platform.isAndroid && globalSettingState.backPressExitEnabled;

    final pageList = _buildPageList(globalSettingState.oldPageRollbackEnabled);
    final destinations = _destinations(
      globalSettingState.oldPageRollbackEnabled,
    );

    final normalizedIndex = _normalizeWelcomePageIndex(
      _selectedIndex,
      pageList.length,
    );
    if (normalizedIndex != _selectedIndex) {
      _selectedIndex = normalizedIndex;
    }

    return MemoryOverlayWidget(
      enabled: globalSettingState.enableMemoryDebug,
      updateInterval: const Duration(seconds: 1),
      child: Builder(
        builder: (context) {
          final isWide =
              isTablet(context) ||
              Platform.isWindows ||
              Platform.isLinux ||
              Platform.isMacOS;

          if (isWide) {
            return _buildTabletLayout(
              pageList: pageList,
              destinations: destinations,
            );
          }
          return _buildMobileLayout(
            pageList: pageList,
            destinations: destinations,
            backPressExitEnabled: backPressExitEnabled,
          );
        },
      ),
    );
  }

  // ---------- 移动端布局：MiuixNavigationBar ----------

  Widget _buildMobileLayout({
    required List<Widget> pageList,
    required List<_NavDestination> destinations,
    required bool backPressExitEnabled,
  }) {
    return PopScope(
      canPop: !backPressExitEnabled,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExitOnBack();
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: IndexedStack(index: _selectedIndex, children: pageList),
        bottomNavigationBar: MiuixNavigationBar(
          children: [
            for (final (i, dest) in destinations.indexed)
              MiuixNavigationBarItem(
                selected: _selectedIndex == i,
                onPressed: () => setState(() => _selectedIndex = i),
                // 选中项蓝色，未选中项用 Miuix 主题的次要文字色。
                icon: _miuixIcon(
                  dest.icon,
                  tint: _selectedIndex == i
                      ? Colors.blue
                      : MiuixTheme.of(context).colors.onSurfaceVariantSummary,
                ),
                label: dest.label,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExitOnBack() async {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    await SystemNavigator.pop();
  }

  // ---------- 平板 / 桌面布局：MiuixNavigationRail ----------

  Widget _buildTabletLayout({
    required List<Widget> pageList,
    required List<_NavDestination> destinations,
  }) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Row(
        children: [
          AnimatedBuilder(
            animation: _railState,
            builder: (context, _) {
              return SizedBox(
                height: double.infinity,
                child: Column(
                  children: [
                    Expanded(
                      child: MiuixNavigationRail(
                        state: _railState,
                        children: [
                          for (final (i, dest) in destinations.indexed)
                            MiuixNavigationRailItem(
                              selected: _selectedIndex == i,
                              onPressed: () =>
                                  setState(() => _selectedIndex = i),
                              icon: _miuixIcon(
                                dest.icon,
                                tint: _selectedIndex == i
                                    ? Colors.blue
                                    : MiuixTheme.of(
                                        context,
                                      ).colors.onSurfaceVariantSummary,
                              ),
                              label: dest.label,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: t.common.search,
                        onPressed: () {
                          context.pushRoute(
                            SearchRoute(
                              searchState: SearchStates.initial(),
                              aggregateMode: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: pageList),
          ),
        ],
      ),
    );
  }

  // ---------- 导航目的地 ----------

  List<_NavDestination> _destinations(bool oldPageRollbackEnabled) {
    // ⚠️ 这里的 icon 名称只能使用 MiuixIcons.extended 中真实存在的名称。
    //
    // 目前使用的 5 个名字（home / search / messages / contacts / explore）
    // 都来自你之前 flutter_miuix 示例里确认可用的集合。如果某个名字在你的
    // flutter_miuix 版本里不存在，_miuixIcon() 会打印警告并回退到 home，
    // 不会崩溃 —— 但你会看到多个 tab 用同一个图标，需要把名字换成实际可用的。
    //
    // 想查看完整可用名，可在 initState 里临时加：
    //   for (final n in MiuixIcons.extended.names) debugPrint(n);
    final base = <_NavDestination>[
      // 书架：用 search 之外的更贴切名字，先尝试 home；若想用别的请替换
      const _NavDestination(icon: 'home', label: '书架'),
      const _NavDestination(icon: 'search', label: '发现'),
      const _NavDestination(icon: 'contacts', label: '更多'),
    ];

    if (!oldPageRollbackEnabled) {
      // 用本地化标签覆盖默认字符串
      return [
        _NavDestination(icon: base[0].icon, label: t.navigation.bookshelf),
        _NavDestination(icon: base[1].icon, label: t.navigation.discover),
        _NavDestination(icon: base[2].icon, label: t.navigation.more),
      ];
    }

    return [
      _NavDestination(icon: 'home', label: t.navigation.home),
      _NavDestination(icon: 'messages', label: t.navigation.rank),
      _NavDestination(icon: base[0].icon, label: t.navigation.bookshelf),
      _NavDestination(icon: base[1].icon, label: t.navigation.discover),
      _NavDestination(icon: base[2].icon, label: t.navigation.more),
    ];
  }

  int _normalizeWelcomePageIndex(int rawIndex, int pageCount) {
    if (pageCount <= 0) {
      return 0;
    }
    return rawIndex.clamp(0, pageCount - 1);
  }

  List<Widget> _buildPageList(bool oldPageRollbackEnabled) {
    final pages = <Widget>[
      const BookshelfPage(),
      const DiscoverPage(),
      const MorePage(),
    ];
    if (!oldPageRollbackEnabled) {
      return pages;
    }
    return [const OldHomePage(), const OldRankingPage(), ...pages];
  }

  // ---------- 以下逻辑保持原样 ----------

  Future<void> _autoSync({bool force = false}) async {
    final globalSettingCubit = context.read<GlobalSettingCubit>();
    final globalState = globalSettingCubit.state;

    if (!force && globalState.syncSetting.autoSync == false) {
      return;
    }

    if (!isSyncServiceConfigured(globalState)) {
      return;
    }

    try {
      await autoSync(
        globalState,
        globalSettingCubit: globalSettingCubit,
        comicFollowCubit: context.read<ComicFollowCubit>(),
      );
      if (globalState.syncSetting.syncNotify) {
        showSuccessToast(
          force ? t.navigation.syncSuccess : t.navigation.autoSyncSuccess,
        );
      }
    } catch (e, stackTrace) {
      logger.e(e.toString(), stackTrace: stackTrace);
      showErrorToast(
        t.navigation.syncFailedMessage(error: normalizeSearchErrorMessage(e)),
        title: force ? t.navigation.syncFailed : t.navigation.autoSyncFailed,
      );
    }
  }

  void _goToLoginPage(
    String from, {
    Map<String, dynamic>? loginScheme,
    Map<String, dynamic>? loginData,
    String? message,
  }) {
    try {
      final pluginId = from.trim();
      if (pluginId.isEmpty) {
        logger.w('Skip login navigation: empty plugin id');
        return;
      }

      final navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        logger.w('Navigator not available');
        return;
      }

      debouncer.run(() {
        if (!mounted) return;

        final now = DateTime.now();
        final recentDuplicate =
            _lastLoginPluginId == pluginId &&
            _lastLoginNavigateAt != null &&
            now.difference(_lastLoginNavigateAt!).inMilliseconds < 1500;
        if (recentDuplicate) return;

        final hasLoginRoute = navigator.widget.pages.any(
          (route) => (route.name ?? '').contains('LoginRoute'),
        );
        if (!hasLoginRoute) {
          showErrorToast(message ?? t.navigation.loginExpired);
          _lastLoginNavigateAt = now;
          _lastLoginPluginId = pluginId;
          context.navigateTo(
            LoginRoute(
              from: pluginId,
              loginScheme: loginScheme,
              loginData: loginData,
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      logger.e('Failed to navigate to login', error: e, stackTrace: stackTrace);
    }
  }

  void _showToast(ToastEvent event) {
    final now = DateTime.now();
    final toastEvent = (event.type, event.title, event.message, event.duration);
    if (_lastToastEvent == toastEvent &&
        _lastToastShownAt != null &&
        now.difference(_lastToastShownAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastToastEvent = toastEvent;
    _lastToastShownAt = now;

    ToastificationType type;
    switch (event.type) {
      case ToastType.success:
        type = ToastificationType.success;
        break;
      case ToastType.error:
        type = ToastificationType.error;
        break;
      case ToastType.warning:
        type = ToastificationType.warning;
        break;
      case ToastType.info:
        type = ToastificationType.info;
        break;
    }

    if (event.message.runes.length < 30) {
      toastification.show(
        context: context,
        title: event.title == null ? null : Text(event.title!),
        description: Text(event.message),
        type: type,
        style: ToastificationStyle.flatColored,
        autoCloseDuration: event.duration,
        showProgressBar: true,
      );
    } else {
      late String title;
      if (event.title != null) {
        title = event.title!;
      } else {
        switch (event.type) {
          case ToastType.success:
            title = t.common.success;
            break;
          case ToastType.error:
            title = t.common.error;
            break;
          case ToastType.warning:
            title = t.common.warning;
            break;
          case ToastType.info:
            title = t.common.info;
            break;
        }
      }
      commonDialog(context, title, event.message);
    }
  }

  void _scheduleFollowUpdateCheck(BuildContext context) {
    if (_followUpdateChecked) return;
    _followUpdateChecked = true;

    Future.delayed(const Duration(minutes: 1), () async {
      try {
        if (!context.mounted) return;
        await context.read<ComicFollowCubit>().checkUpdates();
      } catch (e, stackTrace) {
        logger.e('启动后追更检测失败', error: e, stackTrace: stackTrace);
      }
    });
  }

  Future<void> initializeNotificationsOnce() async {
    if (_notificationsInitialized) {
      logger.d('Notifications already initialized globally');
      return;
    }
    if (_isInitializingNotifications) {
      logger.w('Notification initialization already in progress');
      return;
    }

    try {
      _isInitializingNotifications = true;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await initializeNotifications();
      _notificationsInitialized = true;
      logger.d('Notifications initialized successfully');
    } catch (e, stackTrace) {
      logger.e(
        'Failed to initialize notifications',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isInitializingNotifications = false;
    }
  }
}
