// lib/main_entry_deps/app_widgets.dart
//
// MyApp：应用根 widget，承载桌面窗口 / 托盘 / 主题 / 路由。
//
// 主题分工：
//   - MiuixTheme        由外层 _MiuixThemeHost 提供（见 app_services.dart）
//   - MaterialApp.theme 由本文件提供（light / dark colorScheme）
//   - MaterialUiCompatibilityBridge 把 modern material_ui 的主题
//     映射给子树里仍用 legacy package:flutter/material.dart 的 widget

import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zephyr/config/global/global.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/platform/desktop/native_window.dart';
import 'package:zephyr/platform/desktop/system_tray.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';
import 'package:zephyr/service/reader/reader_desktop_fullscreen_service.dart';
import 'package:zephyr/src/rust/api/system.dart' as rust_system;
import 'package:zephyr/util/font/font_profile.dart';
import 'package:zephyr/widgets/desktop/custom_title_bar.dart';
import 'package:zephyr/widgets/desktop/intent.dart';

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

              // ★ MiuixTheme 由外层 _MiuixThemeHost 提供（见 app_services.dart），
              //   这里只保留 legacy material 主题桥接。
              //   - MaterialApp.theme 给 legacy widget 用（见下方 theme/darkTheme）
              //   - bridge 把 modern material_ui 的主题映射到 legacy 子树
              return MaterialUiCompatibilityBridge(child: content);
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
