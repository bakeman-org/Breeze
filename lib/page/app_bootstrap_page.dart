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
/// 由于重量级初始化（ObjectBox / 字体 / i18n…）已经在 [ZephyrApp] 的
/// 闪屏阶段完成，本页只负责「路由级别」的收尾工作：
///
///   1. 注册各种回调（原生桥、Rust FFI、前台任务事件）；
///   2. 数据库兼容性迁移（任何 DB 读写前必须完成）；
///   3. 插件注册表初始化（本地文件，通常很快）；
///   4. 应用锁校验（仅当启用时）；
///   5. 切换到主界面。
///
/// 插件预热、云更新、插件运行时初始化全部挪到后台，不阻塞导航。
///
/// 冷启动时用户看到本页的时间通常 < 200ms；开了应用锁才会停留到校验完成。
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
  /// ── 关于 `BuildContext across async gaps` ──
  ///
  /// 本方法里所有 `await` 之后对 `context` 的使用，都满足以下两条中的至少一条：
  ///   1. 紧接 `if (!mounted) return;` 守卫；
  ///   2. 使用提前捕获的引用（如 [StringSelectCubit] / [GlobalSettingCubit]），
  ///      完全绕开 `context`。
  ///
  /// 这样既满足 Flutter 推荐的 `use_build_context_synchronously` 模式，
  /// 又避免了在每个 await 后面反复读写 `context.read` 的性能开销。
  ///
  /// ── 关于性能 ──
  ///
  ///   - 移除了旧实现的 200ms 最小延迟；
  ///   - warmup / 云更新 / 插件运行时初始化全部 `unawaited`；
  ///   - 只有应用锁启用时才真正停留本页。
  Future<void> _goNext() async {
    // 预先读出两个 cubit 的引用，避免 await 之后再次触碰 context。
    if (!mounted) return;
    final stringCubit = context.read<StringSelectCubit>();
    final globalSettingCubit = context.read<GlobalSettingCubit>();

    // 更新转圈下方状态文字。stringCubit 是提前捕获的引用，
    // 不涉及 context，任何时机调用都安全。
    void setStatus(String msg) {
      stringCubit.setDate(msg);
    }

    // ───── 同步段：无 I/O、无 context 依赖 ─────
    registerPersistentCallbacks();
    registerDartTools();
    initRustFunctions();
    ForegroundTaskService.instance.listenEvents();

    // ───── 数据库迁移：需要 context 弹对话框 ─────
    if (!mounted) return;
    await ensureCompatibleMigration(context);

    // 从这里开始，所有后续逻辑都使用提前捕获的 cubit，不再触碰 context。
    setStatus(t.appBootstrap.initializing);

    // 插件注册表初始化：本地文件读取，通常很快，但必须在进主界面之前完成，
    // 否则首屏的插件入口会拿不到数据。
    await PluginRegistryService.I.init();

    // ───── 后台段：不阻塞导航的耗时任务 ─────
    //
    // 即使打开插件页面时后台还没跑完，PluginRegistryService 内部通常有
    // 按需加载兜底（首次访问时再拉）。
    unawaited(_runBackgroundInit());

    // ───── 应用锁校验 ─────
    //
    // 只有启用锁时才阻塞导航。未启用锁的用户一路无阻直接进入主界面。
    final appLockSetting = globalSettingCubit.state.appLockSetting;
    if (appLockSetting.enabled && appLockSetting.isReady) {
      final handled = await _handleAppLock(globalSettingCubit, setStatus);
      if (!handled) return; // 校验失败 / 用户取消，留在本页
    }

    // ───── 进入主界面 ─────
    if (!mounted) return;
    context.router.replace(const app_router.NavigationBar());
  }

  /// 后台初始化任务集合。
  ///
  /// 这些任务的特点是「耗时较长 + 不影响首屏渲染」，因此全部塞到后台：
  ///   - 插件信息预热：从磁盘 / 网络读取每个插件的 manifest，用于加速插件页面；
  ///   - 云更新检查：延迟 1 分钟触发的静默检查，本身就不该阻塞启动；
  ///   - 插件运行时初始化：为已启用的插件准备 JS 运行时环境。
  ///
  /// 三步之间用独立的 try/catch 包裹：任何一步失败都不影响后续任务，
  /// 避免因单个插件损坏导致整个初始化链路中断。
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
  ///
  /// 关于 `BuildContext across async gaps`：
  ///   本方法里每个 await 之后的对 context 的使用都紧跟 `if (!mounted) return false;`
  ///   守卫，符合 Flutter 官方推荐的模式。
  Future<bool> _handleAppLock(
    GlobalSettingCubit globalSettingCubit,
    void Function(String) setStatus,
  ) async {
    final appLockSetting = globalSettingCubit.state.appLockSetting;

    setStatus(t.appBootstrap.verifyGesture);

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
        // PIN 正确：清空手势锁设置，直接进主界面。
        globalSettingCubit.updateState(
          (current) =>
              current.copyWith(appLockSetting: const AppLockSettingState()),
        );
        showSuccessToast(t.gestureLock.passwordCleared);
        setStatus(t.gestureLock.passwordCleared);

        if (!mounted) return false;
        context.router.replace(const app_router.NavigationBar());
        return false; // 已导航，调用方不再处理
      }

      setStatus(t.appBootstrap.pinVerifyFailed);
      return false;
    }

    // 用户取消或手势错误：留在本页。
    if (unlockResult != GestureUnlockResult.success) {
      setStatus(t.appBootstrap.unlockCancelled);
      return false;
    }

    setStatus(t.appBootstrap.enteringApp);
    return true;
  }
}
