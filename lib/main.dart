// lib/main.dart
//
// 应用入口 + 全局单例。
//
// 拆分说明（main_entry_deps/）：
//   - error_widget.dart    ErrorWidget 资源兜底
//   - splash.dart          闪屏 / 启动失败页 / kFallbackSeedColor
//   - app_services.dart    ZephyrApp / AppServices / initServices
//   - app_widgets.dart     MyApp（桌面窗口 + 托盘）
//
// 全局单例（objectbox / logger / appRouter / eventBus / ...）留在本文件：
// 项目里到处 `import 'package:zephyr/main.dart'` 取它们，动起来代价太大。
// 其它文件通过同样方式反向 import 使用这些单例，Dart 循环 import 会
// 编译期扁平化，不会双重初始化。

import 'dart:io';

import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/main_entry_deps/app_services.dart';
import 'package:zephyr/main_entry_deps/error_widget.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/service/app_icon/app_icon_service.dart';
import 'package:zephyr/service/app_theme/app_theme_cache.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

// 项目里到处 import main.dart 来用 fetch / WindHttp，必须继续 re-export。
export 'package:zephyr/network/http/wind_http.dart'
    show WindHttp, FetchResponse, fetch, fetchDirect;

// AppBootstrapPage 需要 AppSplashScreen / StartupSplashApp / StartupErrorApp。
export 'package:zephyr/main_entry_deps/splash.dart'
    show AppSplashScreen, StartupSplashApp, StartupErrorApp, kFallbackSeedColor;

// ─────────────────────────────────────────────────────────────────────
// 全局单例
// ─────────────────────────────────────────────────────────────────────

ObjectBox? _objectbox;
ObjectBox get objectbox => _objectbox!;
set objectbox(ObjectBox value) => _objectbox = value;

final appRouter = AppRouter();

EventBus eventBus = EventBus();

var logger = Logger(printer: TersePrettyPrinter());

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

final navigatorKey = GlobalKey<NavigatorState>();

// ─────────────────────────────────────────────────────────────────────
// 启动辅助类
// ─────────────────────────────────────────────────────────────────────

/// 从远程把日志发出去用的 logger output。
///
/// 只在 `logAddress` 已配置、且非 debug 时启用，用于远程排查线上问题。
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

/// 不做过滤的日志过滤器，配合 [RemoteOutput] 使用。
class MyAlwaysLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

/// 允许鼠标拖拽的滚动行为（桌面端体验）。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
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
  installResourceErrorWidgetBuilder();

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
  // flutter run --dart-define=USE_INSPECTOR=true
  const useInspector = bool.fromEnvironment('USE_INSPECTOR');
  if (kDebugMode && useInspector) {
    ZeroInspectorKit.runAppWithInspector(const ZephyrApp());
  } else {
    runApp(const ZephyrApp());
  }
}
