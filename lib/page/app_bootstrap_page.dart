import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_router;
import 'package:zephyr/cubit/string_select.dart';
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
/// 从前的实现会把插件初始化、插件预热、云更新检查全部同步做掉，导致每次
/// 冷启动都要盯着「初始化中…」很久。现在的策略是：
///
/// 1. 只保留「必须先完成才能进入 UI」的任务同步执行；
/// 2. 插件预热 / 云更新 / 运行时初始化全部塞到后台，不阻塞导航；
/// 3. 去掉了原先 200ms 的最小延迟（纯等待，无逻辑价值）；
/// 4. 只有应用锁启用时才会真正停留在本页，其他情况几乎瞬跳。
///
/// 这样冷启动时用户看到的「初始化中…」转瞬即逝，甚至因为耗时太短
/// 完全看不到（Flutter 会跳过中间帧的绘制）。
@RoutePage()
class AppBootstrapPage extends StatelessWidget {
  const AppBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StringSelectCubit()..setDate(t.appBootstrap.initializing),
      child: const AppBootstrapView(),
    );
  }
}

/// 引导页视图层。
///
/// 只负责渲染转圈 + 状态文字，真正的启动流程在
/// [_AppBootstrapViewState._goNext] 里。
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            BlocBuilder<StringSelectCubit, String>(
              builder: (context, state) {
                return Text(state, style: const TextStyle(fontSize: 24));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 启动流程主入口。
  ///
  /// 流程分两段：
  ///
  /// **同步段（阻塞导航）** —— 必须在用户进入主界面前完成：
  ///   - `registerPersistentCallbacks` / `registerDartTools`：注册原生回调；
  ///   - `initRustFunctions`：Rust 侧 FFI 函数注册；
  ///   - `ForegroundTaskService.listenEvents`：注册前台任务事件监听；
  ///   - `ensureCompatibleMigration`：数据库结构迁移，任何 DB 读写前必须完成；
  ///   - `PluginRegistryService.init`：读插件注册表（本地文件，通常很快）。
  ///
  /// **后台段（不阻塞导航）** —— 耗时较长且不阻塞首屏：
  ///   - `warmupPluginInfos`：提前把插件元信息读进内存，加快后续插件页面打开；
  ///   - `scheduleSilentCloudUpdate`：云更新检查（原本就延迟 1 分钟触发）；
  ///   - `initializeActivePluginRuntimes`：初始化已启用插件的运行时。
  ///
  /// **应用锁**：仅当启用时才会真正停留本页做校验，否则一路导航到主界面。
  Future<void> _goNext() async {
    // 用于更新转圈下方显示的状态文字。已 mounted 时才会执行。
    void updateStatus(String msg) {
      if (mounted) context.read<StringSelectCubit>().setDate(msg);
    }

    // ───── 同步段：必须完成的初始化 ─────
    registerPersistentCallbacks();
    registerDartTools();
    initRustFunctions();
    ForegroundTaskService.instance.listenEvents();

    // 数据库迁移：任何 DB 读写前必须完成。
    if (mounted) await ensureCompatibleMigration(context);

    updateStatus(t.appBootstrap.initializing);

    // 插件注册表初始化：读本地文件，通常很快，但必须在进主界面之前完成，
    // 否则首屏的插件入口会拿不到数据。
    await PluginRegistryService.I.init();

    // ───── 后台段：不阻塞导航的耗时任务 ─────
    //
    // 这里不 await，让它在后台跑。即使打开插件页面时后台还没跑完，
    // PluginRegistryService 内部通常有按需加载兜底（首次访问时再拉）。
    unawaited(_runBackgroundInit());

    if (!mounted) return;

    // ───── 应用锁校验 ─────
    //
    // 只有启用锁时才阻塞导航。未启用锁的用户一路无阻直接进入主界面。
    final globalSettingCubit = context.read<GlobalSettingCubit>();
    final globalSetting = globalSettingCubit.state;
    final appLockSetting = globalSetting.appLockSetting;

    if (appLockSetting.enabled && appLockSetting.isReady) {
      final handled = await _handleAppLock(globalSettingCubit, updateStatus);
      if (!handled) return; // 校验失败 / 用户取消，留在本页
    }

    // ───── 进入主界面 ─────
    context.router.replace(const app_router.NavigationBar());
  }

  /// 后台初始化任务集合。
  ///
  /// 这些任务的特点是「耗时较长 + 不影响首屏渲染」，因此全部塞到后台：
  ///   - 插件信息预热：从磁盘 / 网络读取每个插件的 manifest，用于加速插件页面；
  ///   - 云更新检查：延迟 1 分钟触发的静默检查，本身就不该阻塞启动；
  ///   - 插件运行时初始化：为已启用的插件准备 JS 运行时环境。
  ///
  /// 失败只记录日志，不影响主流程。
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

  /// 执行应用锁校验流程。
  ///
  /// 返回值：
  ///   - `true`  → 校验通过，可以继续导航到主界面；
  ///   - `false` → 校验失败 / 用户取消 / 已在本方法内完成导航（忘记密码后的重置流程），
  ///               调用方应直接 return 不再导航。
  ///
  /// 抽出成独立方法是为了让 [_goNext] 的线性流程更清晰，也避免深层嵌套。
  Future<bool> _handleAppLock(
    GlobalSettingCubit globalSettingCubit,
    void Function(String) updateStatus,
  ) async {
    final appLockSetting = globalSettingCubit.state.appLockSetting;

    updateStatus(t.appBootstrap.verifyGesture);

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
        // PIN 正确：清空手势锁设置，直接进主界面。
        globalSettingCubit.updateState(
          (current) =>
              current.copyWith(appLockSetting: const AppLockSettingState()),
        );
        showSuccessToast(t.gestureLock.passwordCleared);
        updateStatus(t.gestureLock.passwordCleared);
        context.router.replace(const app_router.NavigationBar());
        return false; // 已导航，调用方不再处理
      }

      updateStatus(t.appBootstrap.pinVerifyFailed);
      return false;
    }

    // 用户取消或手势错误：留在本页。
    if (unlockResult != GestureUnlockResult.success) {
      updateStatus(t.appBootstrap.unlockCancelled);
      return false;
    }

    updateStatus(t.appBootstrap.enteringApp);
    return true;
  }
}
