import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_router;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/migration/compatible.dart';
import 'package:zephyr/plugin/bridge/dart_tools_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_cloud_update_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/widgets/gesture_lock.dart';
import 'package:zephyr/widgets/toast.dart';

/// 启动引导页。
///
/// UI 与闪屏完全一致（渲染 [AppSplashScreen]），视觉上与 [ZephyrApp] 无缝
/// 衔接。
///
/// 本页只做「必须在 UI 树里」的工作：
///   1. 注册回调（原生桥、Rust FFI、前台任务事件）；
///   2. 数据库兼容性迁移（需要 context 弹对话框）；
///   3. 应用锁校验（仅启用时）。
///
/// 重量级业务初始化（ObjectBox / 字体 / i18n）已在 [ZephyrApp] 完成；
/// 插件注册表初始化已在 `_initServices` 里做完，这里不再重复。
@RoutePage()
class AppBootstrapPage extends StatelessWidget {
  const AppBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBootstrapView();
  }
}

class AppBootstrapView extends StatefulWidget {
  const AppBootstrapView({super.key});

  @override
  State<AppBootstrapView> createState() => _AppBootstrapViewState();
}

class _AppBootstrapViewState extends State<AppBootstrapView> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    // 与 ZephyrApp 闪屏完全一致的 UI，避免视觉上的「第二次 loading」。
    return const AppSplashScreen();
  }

  /// 启动流程主入口。
  ///
  /// 关于 `BuildContext across async gaps`：所有 await 之后用 context 的地方
  /// 都紧跟 `if (!mounted) return;` 守卫，或提前捕获引用。
  Future<void> _goNext() async {
    if (!mounted) return;
    final globalSettingCubit = context.read<GlobalSettingCubit>();

    // 同步段：无 I/O、无 context 依赖。
    registerPersistentCallbacks();
    registerDartTools();
    initRustFunctions();
    ForegroundTaskService.instance.listenEvents();

    // 数据库迁移：需要 context 弹对话框。
    if (!mounted) return;
    await ensureCompatibleMigration(context);

    // 后台段：不阻塞导航。
    unawaited(_runBackgroundInit());

    // 应用锁校验（仅启用时）。
    final appLockSetting = globalSettingCubit.state.appLockSetting;
    if (appLockSetting.enabled && appLockSetting.isReady) {
      final handled = await _handleAppLock(globalSettingCubit);
      if (!handled) return;
    }

    // 进入主界面。
    if (!mounted) return;
    context.router.replace(const app_router.NavigationBar());
  }

  /// 后台初始化任务集合。失败只记录日志，不影响主流程。
  Future<void> _runBackgroundInit() async {
    try {
      await PluginRegistryService.I.warmupPluginInfos();
    } catch (e, st) {
      logger.w('Background plugin warmup failed', error: e, stackTrace: st);
    }

    try {
      PluginCloudUpdateService.I.scheduleSilentCloudUpdate(
        delay: const Duration(minutes: 1),
      );
    } catch (e, st) {
      logger.w('Schedule cloud update failed', error: e, stackTrace: st);
    }

    try {
      await PluginRegistryService.I.initializeActivePluginRuntimes();
    } catch (e, st) {
      logger.w(
        'Background plugin runtime init failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 应用锁校验。
  ///
  /// 返回 true 表示校验通过，调用方继续导航；false 表示失败 / 取消 / 已在
  /// 本方法内导航，调用方直接 return。
  Future<bool> _handleAppLock(GlobalSettingCubit globalSettingCubit) async {
    final appLockSetting = globalSettingCubit.state.appLockSetting;

    if (!mounted) return false;
    final unlockResult = await showGestureUnlockDialog(
      context,
      expectedHash: appLockSetting.gesturePasswordHash,
      title: t.gestureLock.appLocked,
      hint: t.gestureLock.verifyToUnlock,
      showForgotPassword: true,
    );
    if (!mounted) return false;

    // 用户点了「忘记密码」→ 走 PIN 码重置流程。
    if (unlockResult == GestureUnlockResult.forgotPassword) {
      final verified = await showPinVerifyDialog(
        context,
        expectedHash: appLockSetting.resetPinHash,
        title: t.gestureLock.resetGesturePassword,
        hint: t.gestureLock.resetPinHint,
      );
      if (!mounted) return false;

      if (verified == true) {
        globalSettingCubit.updateState(
          (current) =>
              current.copyWith(appLockSetting: const AppLockSettingState()),
        );
        showSuccessToast(t.gestureLock.passwordCleared);

        if (!mounted) return false;
        context.router.replace(const app_router.NavigationBar());
        return false;
      }

      return false;
    }

    // 用户取消或手势错误：留在本页。
    if (unlockResult != GestureUnlockResult.success) {
      return false;
    }

    return true;
  }
}
