import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/platform/desktop/window_logic.dart';
import 'package:zephyr/service/lifecycle/foreground_task/foreground_task_service.dart';
import 'package:zephyr/widgets/gesture_lock.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class AppBehaviorSettingPage extends StatefulWidget {
  const AppBehaviorSettingPage({super.key});

  @override
  State<AppBehaviorSettingPage> createState() => _AppBehaviorSettingPageState();
}

class _AppBehaviorSettingPageState extends State<AppBehaviorSettingPage> {
  DesktopCloseBehavior _desktopCloseBehavior = DesktopCloseBehavior.ask;

  List<String> _splashPageList() {
    return [t.navigation.bookshelf, t.navigation.discover, t.navigation.more];
  }

  Map<String, int> _splashPageMap() {
    return {
      t.navigation.bookshelf: 0,
      t.navigation.discover: 1,
      t.navigation.more: 2,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadDesktopCloseBehavior();
  }

  Future<void> _loadDesktopCloseBehavior() async {
    if (!isDesktop) return;
    final value = await WindowLogic.loadCloseBehavior();
    if (!mounted) return;
    setState(() => _desktopCloseBehavior = value);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      title: t.settings.appBehavior,
      child: ListView(
        children: [
          settingSectionTitle(context, t.settings.appBehavior),
          GroupCard(
            children: [
              _splashPage(state, cubit),
              if (isDesktop) _desktopCloseBehaviorTile(),
              if (Platform.isAndroid) _androidKeepAlive(state, cubit),
              if (Platform.isAndroid) _backPressExit(state, cubit),
              ..._appLockSetting(state, cubit),
              _cloudFavoritePreferred(state, cubit),
              _autoFollowOnCollect(state, cubit),
              _leftHandMode(state, cubit),
              _clickCoverToStartReading(state, cubit),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _splashPage(GlobalSettingState state, GlobalSettingCubit cubit) {
    final splashPageList = _splashPageList();
    final splashPage = _splashPageMap();
    final selectedIndex = splashPageList.isEmpty
        ? 0
        : state.welcomePageNum.clamp(0, splashPageList.length - 1);

    return MiuixOverlayDropdownPreference(
      title: t.settings.splashPage,
      summary: t.settings.splashPageSubtitle,
      items: splashPageList,
      selectedIndex: selectedIndex,
      onSelectedIndexChange: (index) {
        if (index == selectedIndex) return;
        showSuccessToast(t.common.restartToTakeEffect);
        cubit.updateState(
          (current) => current.copyWith(
            welcomePageNum: splashPage[splashPageList[index]]!,
          ),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.rocket_launch_outlined,
        name: 'rocket_launch',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _cloudFavoritePreferred(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.cloudFavoritePreferred,
      summary: t.settings.cloudFavoritePreferredSubtitle,
      value: state.cloudFavoritePreferred,
      onChanged: (bool value) {
        cubit.updateState(
          (current) => current.copyWith(cloudFavoritePreferred: value),
        );
        showSuccessToast(t.common.settingSaved);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.cloud_outlined,
        name: 'cloud',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _autoFollowOnCollect(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.autoFollowOnCollect,
      summary: t.settings.autoFollowOnCollectSubtitle,
      value: state.autoFollowOnCollect,
      onChanged: (bool value) {
        cubit.updateState(
          (current) => current.copyWith(autoFollowOnCollect: value),
        );
        showSuccessToast(t.common.settingSaved);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.notifications_active_outlined,
        name: 'notifications',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _leftHandMode(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.leftHandMode,
      summary: t.settings.leftHandModeSubtitle,
      value: state.leftHandModeEnabled,
      onChanged: (bool value) {
        cubit.updateState(
          (current) => current.copyWith(leftHandModeEnabled: value),
        );
        showSuccessToast(t.common.settingSaved);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.back_hand_outlined,
        name: 'back_hand',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _clickCoverToStartReading(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.clickCoverToStartReading,
      summary: t.settings.clickCoverToStartReadingSubtitle,
      value: state.clickCoverToStartReading,
      onChanged: (bool value) {
        cubit.updateState(
          (current) => current.copyWith(clickCoverToStartReading: value),
        );
        showSuccessToast(t.common.settingSaved);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.touch_app_outlined,
        name: 'touch_app',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _androidKeepAlive(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.androidKeepAlive,
      summary: t.settings.androidKeepAliveSubtitle,
      value: state.androidKeepAliveEnabled,
      onChanged: (bool value) async {
        cubit.updateState(
          (current) => current.copyWith(androidKeepAliveEnabled: value),
        );
        try {
          if (value) {
            await ForegroundTaskService.instance.enableKeepAlive();
          } else {
            await ForegroundTaskService.instance.disableKeepAlive();
          }
          showSuccessToast(t.common.settingSaved);
        } catch (e) {
          cubit.updateState(
            (current) => current.copyWith(androidKeepAliveEnabled: !value),
          );
          showErrorToast(e.toString());
        }
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.battery_charging_full_outlined,
        name: 'battery_charging_full',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _backPressExit(GlobalSettingState state, GlobalSettingCubit cubit) {
    return MiuixSwitchPreference(
      title: t.settings.backPressExit,
      summary: t.settings.backPressExitSubtitle,
      value: state.backPressExitEnabled,
      onChanged: (bool value) {
        cubit.updateState(
          (current) => current.copyWith(backPressExitEnabled: value),
        );
        showSuccessToast(t.common.settingSaved);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.exit_to_app_outlined,
        name: 'exit_to_app',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _desktopCloseBehaviorTile() {
    final closeBehaviorItems = <DesktopCloseBehavior, String>{
      DesktopCloseBehavior.ask: t.settings.desktopCloseAsk,
      DesktopCloseBehavior.hide: t.settings.desktopCloseHide,
      DesktopCloseBehavior.close: t.settings.desktopCloseClose,
    };
    final modes = closeBehaviorItems.keys.toList();

    return MiuixOverlayDropdownPreference(
      title: t.settings.desktopCloseBehavior,
      summary: t.settings.desktopCloseBehaviorSubtitle,
      items: [for (final mode in modes) closeBehaviorItems[mode]!],
      selectedIndex: modes.indexOf(_desktopCloseBehavior),
      onSelectedIndexChange: (index) async {
        final value = modes[index];
        if (value == _desktopCloseBehavior) return;
        await WindowLogic.saveCloseBehavior(value);
        if (!mounted) return;
        setState(() => _desktopCloseBehavior = value);
        showSuccessToast(t.common.settingSaved);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.close_fullscreen_outlined,
        name: 'close_fullscreen',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  List<Widget> _appLockSetting(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    final lockSetting = state.appLockSetting;
    final isReady = lockSetting.isReady;

    return [
      MiuixSwitchPreference(
        title: t.settings.appLock,
        summary: t.settings.appLockSubtitle,
        value: lockSetting.enabled,
        onChanged: (bool value) async {
          if (value && !isReady) {
            final nextSetting = await _configureAppLock();
            if (nextSetting == null) {
              return;
            }
            cubit.updateState(
              (current) => current.copyWith(appLockSetting: nextSetting),
            );
            showSuccessToast(t.common.settingSaved);
            return;
          }

          cubit.updateState(
            (current) => current.copyWith(
              appLockSetting: current.appLockSetting.copyWith(enabled: value),
            ),
          );
          showSuccessToast(t.common.settingSaved);
        },
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.lock_outline,
          name: 'lock',
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
      ),
      MiuixArrowPreference(
        title: t.settings.appLock,
        summary: t.settings.appLockSubtitle,
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.gesture_outlined,
          name: 'gesture',
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
        onClick: () async {
          final nextSetting = await _configureAppLock();
          if (nextSetting == null) {
            return;
          }
          cubit.updateState(
            (current) => current.copyWith(appLockSetting: nextSetting),
          );
          showSuccessToast(t.common.settingSaved);
        },
      ),
      if (isReady)
        MiuixArrowPreference(
          title: t.gestureLock.pinTitle,
          summary: t.gestureLock.pinHint,
          startAction: MiuixSettingHelpers.icon(
            fallback: Icons.pin_outlined,
            name: 'pin',
          ),
          insideMargin: MiuixSettingHelpers.itemMargin,
          onClick: () async {
            final pin = await showPinCodeSetupDialog(
              context,
              title: t.gestureLock.pinTitle,
              confirmTitle: t.gestureLock.pinHint,
            );
            if (pin == null) {
              return;
            }
            cubit.updateState(
              (current) => current.copyWith(
                appLockSetting: current.appLockSetting.copyWith(
                  resetPinHash: hashPinCode(pin),
                ),
              ),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
      if (isReady)
        MiuixArrowPreference(
          title: t.common.delete,
          summary: t.settings.appLock,
          startAction: MiuixSettingHelpers.icon(
            fallback: Icons.delete_outline,
            name: 'delete',
          ),
          insideMargin: MiuixSettingHelpers.itemMargin,
          onClick: () async {
            final shouldDelete = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(t.common.delete),
                content: Text(t.settings.appLockSubtitle),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(t.common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(t.common.delete),
                  ),
                ],
              ),
            );
            if (shouldDelete != true) {
              return;
            }
            cubit.updateState(
              (current) => current.copyWith(
                appLockSetting: const AppLockSettingState(),
              ),
            );
            showSuccessToast(t.common.settingSaved);
          },
        ),
    ];
  }

  Future<AppLockSettingState?> _configureAppLock() async {
    final pattern = await showGesturePasswordSetupDialog(
      context,
      title: t.gestureLock.gestureTitle,
      confirmTitle: t.gestureLock.confirmGesture,
    );
    if (pattern == null) {
      return null;
    }

    if (!mounted) {
      return null;
    }

    final pin = await showPinCodeSetupDialog(
      context,
      title: '设置重置 PIN',
      confirmTitle: '确认重置 PIN',
    );
    if (pin == null) {
      return null;
    }

    return AppLockSettingState(
      enabled: true,
      gesturePasswordHash: hashGesturePattern(pattern),
      resetPinHash: hashPinCode(pin),
    );
  }
}
