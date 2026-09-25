import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/src/rust/api/qjs.dart';
import 'package:zephyr/util/impeller_config.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class DebugSettingPage extends StatefulWidget {
  const DebugSettingPage({super.key});

  @override
  State<DebugSettingPage> createState() => _DebugSettingPageState();
}

class _DebugSettingPageState extends State<DebugSettingPage> {
  @override
  void initState() {
    super.initState();
    _loadImpellerConfig();
  }

  Future<void> _loadImpellerConfig() async {
    final supported = await ImpellerConfig.isForceEnableSupported();
    final forceEnableImpeller = supported
        ? await ImpellerConfig.getForceEnableImpeller()
        : false;

    if (!mounted) return;

    final cubit = context.read<GlobalSettingCubit>();
    if (cubit.state.forceEnableImpeller != forceEnableImpeller) {
      cubit.updateState(
        (current) => current.copyWith(forceEnableImpeller: forceEnableImpeller),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      title: t.settings.debug,
      child: ListView(
        children: [
          settingSectionTitle(context, t.settings.debug),
          GroupCard(
            children: [
              _logAddress(state, cubit),
              _enableMemoryDebug(state, cubit),
              _blockRustHttpRequests(state, cubit),
              if (defaultTargetPlatform == TargetPlatform.android)
                _forceEnableImpeller(state, cubit),
              if (kDebugMode) ...[
                MiuixArrowPreference(
                  title: t.settings.colorPreview,
                  summary: t.settings.colorPreviewSubtitle,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.colorize_outlined,
                    name: 'colorize',
                  ),
                  insideMargin: MiuixSettingHelpers.itemMargin,
                  onClick: () => context.pushRoute(const ShowColorRoute()),
                ),
                MiuixArrowPreference(
                  title: t.settings.qjsRuntimeDebug,
                  summary: t.settings.qjsRuntimeDebugSubtitle,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.developer_mode_outlined,
                    name: 'developer_mode',
                  ),
                  insideMargin: MiuixSettingHelpers.itemMargin,
                  onClick: () => context.pushRoute(const QjsRuntimeDebugRoute()),
                ),
                MiuixArrowPreference(
                  title: t.settings.coremlDebug,
                  summary: t.settings.coremlDebugSubtitle,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.memory_outlined,
                    name: 'memory',
                  ),
                  insideMargin: MiuixSettingHelpers.itemMargin,
                  onClick: () =>
                      context.pushRoute(const CoreMLUpscaleDebugRoute()),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _enableMemoryDebug(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.memoryDebug,
      summary: t.settings.memoryDebugSubtitle,
      value: state.enableMemoryDebug,
      onChanged: (bool value) {
        cubit.updateState(
          (current) => current.copyWith(enableMemoryDebug: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.memory_outlined,
        name: 'memory',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _logAddress(GlobalSettingState state, GlobalSettingCubit cubit) {
    final logAddress = state.logAddress.trim();
    return MiuixArrowPreference(
      title: t.settings.logAddress,
      summary: logAddress.isEmpty ? t.settings.logAddressSubtitle : logAddress,
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.link_outlined,
        name: 'link',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
      onClick: () async {
        var inputValue = logAddress;
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.settings.logAddress),
            content: TextFormField(
              initialValue: logAddress,
              autofocus: true,
              onChanged: (value) => inputValue = value.trim(),
              decoration: const InputDecoration(
                hintText: 'https://example.com/log',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                child: Text(t.common.cancel),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text(t.common.ok),
                onPressed: () => Navigator.pop(context, inputValue),
              ),
            ],
          ),
        );

        if (result != null && result != logAddress) {
          cubit.updateState((current) => current.copyWith(logAddress: result));
          showSuccessToast(t.common.settingSaved);
        }
      },
    );
  }

  Widget _blockRustHttpRequests(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.blockRustHttpRequests,
      summary: t.settings.blockRustHttpRequestsSubtitle,
      value: state.blockRustHttpRequests,
      onChanged: (bool value) {
        setHttpRequestsBlocked(blocked: value);
        cubit.updateState(
          (current) => current.copyWith(blockRustHttpRequests: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.cloud_off_outlined,
        name: 'cloud_off',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _forceEnableImpeller(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.forceEnableImpeller,
      summary: t.settings.forceEnableImpellerSubtitle,
      value: state.forceEnableImpeller,
      onChanged: (bool value) async {
        cubit.updateState(
          (current) => current.copyWith(forceEnableImpeller: value),
        );
        await ImpellerConfig.setForceEnableImpeller(value);
        showSuccessToast(t.common.restartToTakeEffect);
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.auto_awesome_outlined,
        name: 'auto_awesome',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }
}
