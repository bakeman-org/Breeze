// lib/main_entry_deps/app_services.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/i18n/system_locale_service.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/main_entry_deps/app_widgets.dart';
import 'package:zephyr/network/proxy_apply.dart';
import 'package:zephyr/network/sync/sync_device_id.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/startup_database_snapshot_service.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/util/debouncer.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/font/font_profile.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/util/rust_loader.dart';

// ─────────────────────────────────────────────────────────────────────
// ZephyrApp：顶层壳 + 闪屏
// ─────────────────────────────────────────────────────────────────────

class ZephyrApp extends StatefulWidget {
  const ZephyrApp({super.key});

  @override
  State<ZephyrApp> createState() => _ZephyrAppState();
}

class _ZephyrAppState extends State<ZephyrApp> {
  late final Future<AppServices> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _bootstrap();
  }

  Future<AppServices> _bootstrap() async {
    await ensureSyncDeviceId();

    final (globalSettingCubit, pluginRegistryCubit) = await initServices();
    final comicFollowCubit = ComicFollowCubit();

    return AppServices(
      globalSettingCubit: globalSettingCubit,
      pluginRegistryCubit: pluginRegistryCubit,
      comicFollowCubit: comicFollowCubit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StartupErrorApp(
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace,
          );
        }

        final services = snapshot.data;
        if (services == null) {
          return const StartupSplashApp();
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: services.globalSettingCubit),
            BlocProvider.value(value: services.pluginRegistryCubit),
            BlocProvider.value(value: services.comicFollowCubit),
          ],
          // ★ 把 MiuixTheme 提到 MaterialApp 之上，让整棵树（含窗口/托盘
          //   相关子树）都能读到 MiuixTheme。MaterialApp.builder 里只保留
          //   MaterialUiCompatibilityBridge 做 legacy material 主题桥接。
          child: const _MiuixThemeHost(child: MyApp()),
        );
      },
    );
  }
}

/// [ZephyrApp] 初始化完成后注入到 [MultiBlocProvider] 的三个全局 cubit。
class AppServices {
  const AppServices({
    required this.globalSettingCubit,
    required this.pluginRegistryCubit,
    required this.comicFollowCubit,
  });

  final GlobalSettingCubit globalSettingCubit;
  final PluginRegistryCubit pluginRegistryCubit;
  final ComicFollowCubit comicFollowCubit;
}

// ─────────────────────────────────────────────────────────────────────
// MiuixTheme 宿主
// ─────────────────────────────────────────────────────────────────────

/// 在 `MaterialApp` 之上提供 `MiuixTheme`。
///
/// **为什么要独立一个 widget？**
/// `MiuixTheme` 放在 `MaterialApp` 外面可以让整棵树都读到它，
/// 但这时不能再依赖 `Theme.of(context).brightness`（没有 MaterialApp 祖先），
/// 也不能依赖 `MediaQuery.platformBrightnessOf(context)`（同样没有 MediaQuery）。
/// 所以这里用 [WidgetsBindingObserver] 直接监听平台亮度变化。
///
/// **不要**在这里再包一层 `AnimatedBuilder(animation: FontProfileController.instance)`：
/// `MyApp` 内部已经有这一层，重复包裹会让 element 复用错位。
class _MiuixThemeHost extends StatefulWidget {
  const _MiuixThemeHost({required this.child});

  final Widget child;

  @override
  State<_MiuixThemeHost> createState() => _MiuixThemeHostState();
}

class _MiuixThemeHostState extends State<_MiuixThemeHost>
    with WidgetsBindingObserver {
  Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next == _platformBrightness) return;
    if (!mounted) return;
    setState(() => _platformBrightness = next);
  }

  @override
  Widget build(BuildContext context) {
    // 只在 seedColor / themeMode 变化时重建。MiuixThemeData 本身是
    // 不可变数据，重复构建代价不高，但避免无意义重建更稳。
    return BlocBuilder<GlobalSettingCubit, GlobalSettingState>(
      buildWhen: (previous, current) =>
          previous.seedColor != current.seedColor ||
          previous.themeMode != current.themeMode,
      builder: (context, globalState) {
        final brightness = switch (globalState.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => _platformBrightness,
        };

        final miuixColors = miuixColorsFromSeed(
          seed: globalState.seedColor,
          paletteStyle: MiuixThemePaletteStyle.tonalSpot,
          dark: brightness == Brightness.dark,
        );

        return MiuixTheme(
          data: MiuixThemeData(
            colors: miuixColors,
            // 外层读不到 MiuixTheme.of(context)，直接用默认样式集。
            // 与原来 builder 里 `MiuixTheme.of(context).textStyles` 的
            // fallback 结果一致。
            textStyles: defaultTextStyles(),
            brightness: brightness,
          ),
          child: widget.child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 业务初始化
// ─────────────────────────────────────────────────────────────────────

/// 业务初始化入口。
///
/// 返回 (GlobalSettingCubit, PluginRegistryCubit) 供 [ZephyrApp] 使用。
Future<(GlobalSettingCubit, PluginRegistryCubit)> initServices() async {
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
  applyProxySetting(proxySetting);

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
