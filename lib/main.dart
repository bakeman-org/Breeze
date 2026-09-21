// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/i18n/system_locale_service.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/platform/desktop/native_window.dart';
import 'package:zephyr/platform/desktop/system_tray.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/app_icon/app_icon_service.dart';
import 'package:zephyr/service/app_theme/app_theme_cache.dart';
import 'package:zephyr/service/reader/reader_desktop_fullscreen_service.dart';
import 'package:zephyr/service/startup_database_snapshot_service.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/src/rust/api/system.dart' as rust_system;
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/font/font_profile.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/util/rust_loader.dart';
import 'package:zephyr/widgets/desktop/custom_title_bar.dart';
import 'package:zephyr/widgets/desktop/intent.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

export 'package:zephyr/network/http/wind_http.dart'
    show WindHttp, FetchResponse, fetch, fetchDirect;

// ─────────────────────────────────────────────────────────────────────
// 全局单例
// ─────────────────────────────────────────────────────────────────────

ObjectBox? _objectbox;
ObjectBox get objectbox => _objectbox!;
set objectbox(ObjectBox value) => _objectbox = value;

final appRouter = AppRouter();

EventBus eventBus = EventBus();

var logger = Logger(printer: TersePrettyPrinter());

List<String> cfIpList = [];

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

final navigatorKey = GlobalKey<NavigatorState>();

/// 闪屏主题的兜底种子色。
///
/// 只有「首次启动、缓存里还没有 seedColor」时才会用到。用 GlobalSettingState
/// 的默认种子色，保证首次启动的闪屏色和主界面默认色一致。
const Color _kFallbackSeedColor = Color(0xFFEF5350);

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

class RemoteOutput extends LogOutput {
  final String url;

  RemoteOutput(this.url);

  @override
  void output(OutputEvent event) {
    _sendToServer(event.lines.join('\n'), event.level);
  }

  Future<void> _sendToServer(String message, Level level) async {
    try {
      await fetch(
        url,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: {'level': level.name, 'message': '\n$message'},
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}

class MyAlwaysLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

// ─────────────────────────────────────────────────────────────────────
// 启动入口
// ─────────────────────────────────────────────────────────────────────

/// 启动入口。
///
/// 关键点：
///   1. **移除 Sentry**。启动链路不再被 Sentry 包装。
///   2. **`await AppIconService.ensureLoaded()`**：读当前生效的应用图标，
///      让闪屏第一帧就显示正确图标（经典 / 现代）。
///   3. **`await AppThemeCache.init()`**：读轻量缓存里的 seedColor / themeMode，
///      让闪屏背景色和主界面一致，消除颜色跳变。
///   4. **runApp 立刻执行**，业务初始化在 [ZephyrApp] 的闪屏阶段跑。
///   5. **闪屏 UI 抽成公共 [AppSplashScreen]**，`AppBootstrapPage` 复用同一个。
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ GPU OOM / 图片解码失败兜底：
  //   Adreno/Mali 在高并发图片加载时可能返回纹理分配失败，
  //   默认 ErrorWidget 会显示红屏并可能阻断整棵树。
  //   这里改成「清理缓存 + 显示占位提示」，让页面还能响应返回。
  _installResourceErrorWidgetBuilder();

  if (!kIsWeb && Platform.isLinux && runWebViewTitleBarWidget(args)) {
    return;
  }

  // 预热：应用图标状态（< 10ms，platform channel）。
  await AppIconService.instance.ensureLoaded();

  // 预热：主题缓存（SharedPreferences，一次性初始化）。
  await AppThemeCache.init();

  if (kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.e(
        "Flutter Framework Error",
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.e("Async/Platform Error", error: error, stackTrace: stack);
      return true;
    };
  }

  // zero_inspector_kit 的 AlertService 会在 build 期间同步 fire
  // ValueNotifier，触发 FloatingInspectorButton 的 setState，导致
  // "setState() called during build" 异常。生产环境直接使用原生 runApp；
  // 调试需要 inspector 时，用 dart-define 手动打开。
  //flutter run --dart-define=USE_INSPECTOR=true

  const useInspector = bool.fromEnvironment('USE_INSPECTOR');
  if (kDebugMode && useInspector) {
    ZeroInspectorKit.runAppWithInspector(const ZephyrApp());
  } else {
    runApp(const ZephyrApp());
  }
}

/// 安装资源错误兜底 ErrorWidget。
///
/// GPU 纹理分配失败（Adreno kgsl_sharedmem_alloc、iOS 上类似错误）会以
/// FlutterErrorDetails 形式冒泡到 ErrorWidget.builder。默认红屏不好看，
/// 且不会主动释放缓存，容易连锁触发更多分配失败。
void _installResourceErrorWidgetBuilder() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final msg = details.exception.toString().toLowerCase();
    final isResourceError =
        msg.contains('memory') ||
        msg.contains('gpu') ||
        msg.contains('texture') ||
        msg.contains('alloc') ||
        msg.contains('adreno') ||
        msg.contains('kgsl') ||
        msg.contains('out of') ||
        msg.contains('surface');

    if (isResourceError) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        isResourceError ? '资源紧张，已尝试释放缓存。\n如仍异常请返回上一页。' : '渲染出错',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  };
}

// ─────────────────────────────────────────────────────────────────────
// ZephyrApp：顶层壳 + 闪屏
// ─────────────────────────────────────────────────────────────────────

class ZephyrApp extends StatefulWidget {
  const ZephyrApp({super.key});

  @override
  State<ZephyrApp> createState() => _ZephyrAppState();
}

class _ZephyrAppState extends State<ZephyrApp> {
  late final Future<_AppServices> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _bootstrap();
  }

  Future<_AppServices> _bootstrap() async {
    await ensureSyncDeviceId();

    final (globalSettingCubit, pluginRegistryCubit) = await _initServices();
    final comicFollowCubit = ComicFollowCubit();

    return _AppServices(
      globalSettingCubit: globalSettingCubit,
      pluginRegistryCubit: pluginRegistryCubit,
      comicFollowCubit: comicFollowCubit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppServices>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupErrorApp(
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace,
          );
        }

        final services = snapshot.data;
        if (services == null) {
          return const _StartupSplashApp();
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: services.globalSettingCubit),
            BlocProvider.value(value: services.pluginRegistryCubit),
            BlocProvider.value(value: services.comicFollowCubit),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}

class _AppServices {
  const _AppServices({
    required this.globalSettingCubit,
    required this.pluginRegistryCubit,
    required this.comicFollowCubit,
  });

  final GlobalSettingCubit globalSettingCubit;
  final PluginRegistryCubit pluginRegistryCubit;
  final ComicFollowCubit comicFollowCubit;
}

// ─────────────────────────────────────────────────────────────────────
// 闪屏
// ─────────────────────────────────────────────────────────────────────

/// 启动闪屏。
///
/// 公共 widget：[ZephyrApp] 业务初始化阶段和 [AppBootstrapPage] 都渲染它。
/// 图标来源 [AppIconService.instance.value.assetPath]（main 里已 await 加载）。
class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final assetPath = AppIconService.instance.value.assetPath;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                assetPath,
                width: 88,
                height: 88,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 88, height: 88),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// `_bootstrap` 阶段的闪屏宿主。
///
/// 主题来源：[AppThemeCache]，与主界面用同一份 seedColor / themeMode，
/// 消除「闪屏色 → 主界面色」的跳变。
class _StartupSplashApp extends StatelessWidget {
  const _StartupSplashApp();

  @override
  Widget build(BuildContext context) {
    final seed = AppThemeCache.seedColor ?? _kFallbackSeedColor;
    final themeMode = AppThemeCache.themeMode ?? ThemeMode.system;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: ColorScheme.fromSeed(seedColor: seed).surface,
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).surface,
      ),
      home: const AppSplashScreen(),
    );
  }
}

/// 初始化失败的兜底页。
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  '应用启动失败',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                if (kDebugMode && stackTrace != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '详细堆栈已打印到控制台。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 业务初始化
// ─────────────────────────────────────────────────────────────────────

Future<(GlobalSettingCubit, PluginRegistryCubit)> _initServices() async {
  await initRustLib();

  LocaleSettings.setLocale(AppLocale.enUs);
  I18nHelper.setRustErrorLanguage(AppLocale.enUs);

  await Future.wait<void>([
    workerManager.init(isolatesCount: Platform.numberOfProcessors),
    () async {
      enableStacktrace(enabled: false);
      enableRustLog(enabled: kDebugMode);

      if (kDebugMode) {
        setQjsErrorStackEnabled(enabled: true);
      } else {
        setQjsErrorStackEnabled(enabled: false);
      }

      FlutterForegroundTask.initCommunicationPort();
      GestureBinding.instance.resamplingEnabled = true;

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarColor: Colors.transparent,
        ),
      );

      // ★ 图片解码缓存上限。
      //   移动端之前试过 320MB，会在「下载多部漫画 + 打开预览」时挤压
      //   GPU 纹理预算（Adreno OOM）。折中到 220MB / 100 张，
      //   桌面端 512MB / 300 张。
      final isDesktop =
          Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      final cache = PaintingBinding.instance.imageCache;
      cache.maximumSizeBytes = (isDesktop ? 512 : 220) * 1024 * 1024;
      cache.maximumSize = isDesktop ? 300 : 100;

      if (!isTabletWithOutContext()) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }(),
  ]);

  if (kDebugMode) {
    await _tryApplyHttpProxyFromEnv();
  }

  objectbox = await ObjectBox.create();
  final setting = objectbox.userSettingBox.get(1);
  if (setting == null) {
    objectbox.userSettingBox.put(UserSetting());
  }

  final globalSettingCubit = GlobalSettingCubit();
  await globalSettingCubit.initBox();
  setHttpRequestsBlocked(
    blocked: globalSettingCubit.state.blockRustHttpRequests,
  );

  await Future.wait<void>([
    () async {
      if (globalSettingCubit.state.localeFollowsSystem) {
        final systemInfo = await SystemLocaleService.getInfo();
        await globalSettingCubit.setSystemLocale(systemInfo.locale);
      } else {
        await globalSettingCubit.setLocale(globalSettingCubit.state.locale);
      }
    }(),
    FontProfileController.instance.init(),
  ]);

  final pluginRegistryCubit = PluginRegistryCubit();

  if (globalSettingCubit.state.needCleanCache) {
    await clearCache(await getCachePath());
  }

  final proxySetting = globalSettingCubit.state.proxySetting;
  if (proxySetting.enabled && proxySetting.address.trim().isNotEmpty) {
    final proxyAddress = proxySetting.address.trim();
    switch (proxySetting.type) {
      case ProxyType.http:
        final proxyUrl =
            proxyAddress.startsWith('http://') ||
                proxyAddress.startsWith('https://')
            ? proxyAddress
            : 'http://$proxyAddress';
        setHttpProxy(proxy: proxyUrl);
        SocksProxy.initProxy(proxy: 'PROXY ${_stripProxyScheme(proxyUrl)}');
      case ProxyType.socks5:
        SocksProxy.initProxy(proxy: 'SOCKS5 $proxyAddress');
        setSocks5Proxy(proxy: proxyAddress);
    }
  }

  final logAddress = globalSettingCubit.state.logAddress;

  if (logAddress.isNotEmpty) {
    if (!kDebugMode) {
      logger = Logger(
        printer: TersePrettyPrinter(),
        filter: MyAlwaysLogFilter(),
        output: RemoteOutput(logAddress),
      );
    }
    setLogHttpForward(url: logAddress);
    setQjsErrorStackEnabled(enabled: true);
  }

  setHostCacheGcEnabled(enabled: false);
  setTlsVerifyEnabled(enabled: false);

  // ★ 从 AppBootstrapPage 挪过来：插件注册表初始化不依赖 context，可以提前做。
  //   这样 AppBootstrapPage 只剩「注册回调 + 数据库迁移 + 应用锁」，
  //   1-2 帧内就能导航走，用户看不到第二次 loading。
  await PluginRegistryService.I.init();

  unawaited(saveStartupDatabaseSnapshot());

  return (globalSettingCubit, pluginRegistryCubit);
}

Future<void> _tryApplyHttpProxyFromEnv() async {
  if (!kDebugMode) return;

  final rawProxy = await _readProxyFromEnvAsset();
  if (rawProxy == null || rawProxy.isEmpty) return;

  final proxyUrl =
      rawProxy.startsWith('http://') || rawProxy.startsWith('https://')
      ? rawProxy
      : 'http://$rawProxy';

  final reachable = await _probeProxyWithTimeout(proxyUrl);
  if (!reachable) return;

  setHttpProxy(proxy: proxyUrl);
}

String _stripProxyScheme(String url) {
  var value = url.trim();
  for (final prefix in const ['https://', 'http://']) {
    if (value.startsWith(prefix)) {
      value = value.substring(prefix.length);
      break;
    }
  }
  return value;
}

Future<String?> _readProxyFromEnvAsset() async {
  try {
    final content = await rootBundle.loadString('.env.proxy');
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (!line.startsWith('proxy=')) continue;
      final value = line.substring('proxy='.length).trim();
      if (value.isNotEmpty) return value;
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<bool> _probeProxyWithTimeout(String proxyUrl) async {
  try {
    final response = await WindHttp(
      httpProxy: proxyUrl,
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      followRedirects: false,
    ).fetch('http://www.gstatic.com/generate_204');
    return response.status >= 200 && response.status < 500;
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────
// MyApp
// ─────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget with WindowListener {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WindowListener, TrayListener, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.addListener(this);
      _init();
      WindowLogic.initWindow(context).then((_) {
        windowManager.setPreventClose(true);
      });
    }
    trayManager.addListener(this);
    initSystemTray();

    if (Platform.isLinux) {
      _linuxWindowChannel.setMethodCallHandler((call) async {
        if (call.method == 'windowCloseRequested') {
          _handleCloseRequest();
        }
      });
    }

    if (Platform.isWindows) {
      rust_system.startShutdownListener().listen((shouldExit) {
        if (shouldExit) {
          _performGracefulExit();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowResized() {
    super.onWindowResized();
    WindowLogic.saveWindowState(context);
  }

  @override
  void onWindowMoved() {
    super.onWindowMoved();
    WindowLogic.saveWindowState(context);
  }

  @override
  void onWindowMaximize() {
    super.onWindowMaximize();
    WindowLogic.saveWindowStateImmediately(context);
  }

  @override
  void onWindowUnmaximize() {
    super.onWindowUnmaximize();
    WindowLogic.saveWindowStateImmediately(context);
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await WindowLogic.saveWindowStateImmediately(context);
    }
    return AppExitResponse.exit;
  }

  Future<void> _forceExit() async {
    await WindowLogic.saveWindowStateImmediately(context);
    if (Platform.isWindows) {
      NativeWindow.hide();
    } else {
      windowManager.hide();
    }
    objectbox.close();
    nuclearKillProcess();
  }

  bool _handlingCloseRequest = false;

  static const MethodChannel _linuxWindowChannel = MethodChannel(
    'breeze/linux/window',
  );

  @override
  void onWindowClose() {
    _handleCloseRequest();
  }

  Future<void> _handleCloseRequest() async {
    if (_handlingCloseRequest) return;
    _handlingCloseRequest = true;
    try {
      final closeBehavior = await WindowLogic.loadCloseBehavior();
      switch (closeBehavior) {
        case DesktopCloseBehavior.hide:
          await _hideWindow();
          return;
        case DesktopCloseBehavior.close:
          await _forceExit();
          return;
        case DesktopCloseBehavior.ask:
          break;
      }

      if (Platform.isLinux) {
        await windowManager.show();
      }

      final dialogContext = appRouter.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) {
        await _forceExit();
        return;
      }

      await showDialog(
        context: dialogContext,
        builder: (context) {
          var rememberChoice = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('提示'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('隐藏到托盘或关闭程序'),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('记住我的选择'),
                      value: rememberChoice,
                      onChanged: (value) {
                        setDialogState(() {
                          rememberChoice = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text('取消'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text('关闭'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (rememberChoice) {
                        await WindowLogic.saveCloseBehavior(
                          DesktopCloseBehavior.close,
                        );
                      }
                      await _forceExit();
                    },
                  ),
                  TextButton(
                    child: const Text('隐藏'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (rememberChoice) {
                        await WindowLogic.saveCloseBehavior(
                          DesktopCloseBehavior.hide,
                        );
                      }
                      await _hideWindow();
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _handlingCloseRequest = false;
    }
  }

  Future<void> _hideWindow() async {
    await WindowLogic.saveWindowStateImmediately(context);
    if (Platform.isWindows) {
      NativeWindow.hide();
    } else {
      windowManager.hide();
    }
  }

  Future<void> _performGracefulExit() async {
    await _forceExit();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    setState(() {});
  }

  @override
  void onTrayIconMouseDown() {
    showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      showMainWindow();
    } else if (menuItem.key == 'exit_app') {
      _performGracefulExit();
    }
  }

  void _init() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.setPreventClose(true);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: AnimatedBuilder(
        animation: FontProfileController.instance,
        builder: (context, _) {
          final globalSettingState = context.watch<GlobalSettingCubit>().state;
          final primary = globalSettingState.seedColor;

          final ColorScheme lightColorScheme = ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
          );
          final ColorScheme darkColorScheme = ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.dark,
          );

          final isLinuxDesktop = !kIsWeb && Platform.isLinux;
          const linuxFontFamily = 'Noto Sans CJK SC';
          const linuxFontFamilyFallback = <String>[
            'WenQuanYi Micro Hei',
            'Droid Sans Fallback',
          ];

          TextTheme withConfiguredFonts(TextTheme base) {
            var themed = base;
            if (isLinuxDesktop) {
              themed = themed.apply(
                fontFamily: linuxFontFamily,
                fontFamilyFallback: linuxFontFamilyFallback,
              );
            }
            return FontProfileController.instance.applyToTextTheme(themed);
          }

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter.config(),
            scrollBehavior: const AppScrollBehavior(),
            builder: (context, child) {
              Widget content = Actions(
                actions: <Type, Action<Intent>>{
                  EscapeIntent: CallbackAction<EscapeIntent>(
                    onInvoke: (intent) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        appRouter.maybePop();
                      });
                      return null;
                    },
                  ),
                },
                child: Shortcuts(
                  shortcuts: <ShortcutActivator, Intent>{
                    const SingleActivator(LogicalKeyboardKey.escape):
                        const EscapeIntent(),
                  },
                  child: Focus(autofocus: true, child: child!),
                ),
              );

              content = Listener(
                onPointerDown: (PointerDownEvent event) {
                  if (event.buttons & kBackMouseButton != 0) {
                    appRouter.maybePop();
                  }
                },
                child: content,
              );

              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                final desktopContent = content;
                content = ValueListenableBuilder<bool>(
                  valueListenable: ReaderDesktopFullscreenService
                      .instance
                      .fullscreenNotifier,
                  builder: (context, isReaderFullscreen, _) {
                    return Column(
                      children: [
                        if (!isReaderFullscreen) const CustomTitleBar(),
                        Expanded(child: desktopContent),
                      ],
                    );
                  },
                );
              }

              // Miuix 组件读 MiuixTheme 而非 MaterialApp.theme，
              // 缺少这一层就只会走内部 fallback 配色，不跟随 seedColor。
              final brightness = Theme.of(context).brightness;
              final miuixColors = miuixColorsFromSeed(
                seed: primary,
                paletteStyle: MiuixThemePaletteStyle.tonalSpot,
                dark: brightness == Brightness.dark,
              );

              return MiuixTheme(
                data: MiuixThemeData(
                  colors: miuixColors,
                  textStyles: MiuixTheme.of(context).textStyles,
                  brightness: brightness,
                ),
                child: MaterialUiCompatibilityBridge(child: content),
              );
            },
            locale: TranslationProvider.of(context).flutterLocale,
            title: appName,
            themeMode: globalSettingState.themeMode,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData.light().copyWith(
              primaryColor: lightColorScheme.primary,
              colorScheme: lightColorScheme,
              scaffoldBackgroundColor: lightColorScheme.surface,
              cardColor: lightColorScheme.surfaceContainer,
              chipTheme: ChipThemeData(
                backgroundColor: lightColorScheme.surface,
              ),
              canvasColor: lightColorScheme.surfaceContainer,
              dialogTheme: DialogThemeData(
                backgroundColor: lightColorScheme.surfaceContainer,
              ),
              textTheme: withConfiguredFonts(ThemeData.light().textTheme),
              primaryTextTheme: withConfiguredFonts(
                ThemeData.light().primaryTextTheme,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: globalSettingState.isAMOLED
                  ? Colors.black
                  : darkColorScheme.surface,
              tabBarTheme: const TabBarThemeData(
                dividerColor: Colors.transparent,
              ),
              colorScheme: darkColorScheme,
              textTheme: withConfiguredFonts(ThemeData.dark().textTheme),
              primaryTextTheme: withConfiguredFonts(
                ThemeData.dark().primaryTextTheme,
              ),
            ),
          );
        },
      ),
    );
  }
}
