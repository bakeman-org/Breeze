// lib/main_entry_deps/splash.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zephyr/service/app_icon/app_icon_service.dart';
import 'package:zephyr/service/app_theme/app_theme_cache.dart';

/// 闪屏主题的兜底种子色。
///
/// 只有「首次启动、缓存里还没有 seedColor」时才会用到。用 GlobalSettingState
/// 的默认种子色，保证首次启动的闪屏色和主界面默认色一致。
const Color kFallbackSeedColor = Color(0xFFEF5350);

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
class StartupSplashApp extends StatelessWidget {
  const StartupSplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = AppThemeCache.seedColor ?? kFallbackSeedColor;
    // AppThemeCache.themeMode 的静态类型是 Enum?（内部存的是 ThemeMode），
    // 这里显式收窄到 ThemeMode，否则 MaterialApp.themeMode 参数不接受 Enum。
    final themeMode = (AppThemeCache.themeMode is ThemeMode)
        ? AppThemeCache.themeMode as ThemeMode
        : ThemeMode.system;

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
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stackTrace});

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
