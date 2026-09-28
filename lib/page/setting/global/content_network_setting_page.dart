import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/widgets.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';

@RoutePage()
class ContentNetworkSettingPage extends StatelessWidget {
  const ContentNetworkSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      title: t.settings.contentAndNetwork,
      child: ListView(
        children: [
          settingSectionTitle(context, t.settings.content),
          GroupCard(
            children: [
              editMaskedKeywords(context),
              _chineseConvertMode(state, cubit),
            ],
          ),
          settingSectionTitle(context, t.settings.network),
          GroupCard(
            children: [
              proxyToggle(context, state.proxySetting),
              _bikaImageAcceleration(state, cubit),
              MiuixSwitchPreference(
                title: t.settings.retryDownloadUntilSuccess,
                summary: t.settings.retryDownloadUntilSuccessSubtitle,
                value: state.retryDownloadUntilSuccess,
                onChanged: (value) {
                  cubit.updateState(
                    (current) =>
                        current.copyWith(retryDownloadUntilSuccess: value),
                  );
                },
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.download_outlined,
                  name: 'download',
                ),
                insideMargin: MiuixSettingHelpers.itemMargin,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _chineseConvertMode(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    final chineseConvertItems = <ChineseConvertMode, String>{
      ChineseConvertMode.off: t.settings.chineseConvertOff,
      ChineseConvertMode.simplified: t.settings.chineseConvertSimplified,
      ChineseConvertMode.traditional: t.settings.chineseConvertTraditional,
    };
    final modes = chineseConvertItems.keys.toList();

    return MiuixOverlayDropdownPreference(
      title: t.settings.chineseConvert,
      summary: t.settings.chineseConvertSubtitle,
      items: [for (final mode in modes) chineseConvertItems[mode]!],
      selectedIndex: modes.indexOf(state.chineseConvertMode),
      onSelectedIndexChange: (index) {
        final value = modes[index];
        if (value == state.chineseConvertMode) return;
        cubit.updateState(
          (current) => current.copyWith(chineseConvertMode: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.translate_outlined,
        name: 'translate',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }

  Widget _bikaImageAcceleration(
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) {
    return MiuixSwitchPreference(
      title: t.settings.bikaImageAcceleration,
      summary: t.settings.bikaImageAccelerationSubtitle,
      value: state.bikaImageAcceleration,
      onChanged: (value) {
        cubit.updateState(
          (current) => current.copyWith(bikaImageAcceleration: value),
        );
      },
      startAction: MiuixSettingHelpers.icon(
        fallback: Icons.bolt_outlined,
        name: 'bolt',
      ),
      insideMargin: MiuixSettingHelpers.itemMargin,
    );
  }
}
