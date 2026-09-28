import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/proxy_apply.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';

Widget changeThemeColor(BuildContext context) {
  return MiuixArrowPreference(
    title: t.settings.themeColor,
    summary: t.settings.themeColorSubtitle,
    startAction: MiuixSettingHelpers.icon(
      fallback: Icons.palette_outlined,
      name: 'palette',
    ),
    insideMargin: MiuixSettingHelpers.itemMargin,
    onClick: () {
      AutoRouter.of(context).push(const ThemeColorRoute());
    },
  );
}

Widget proxyToggle(BuildContext context, ProxySettingState proxySetting) {
  final modes = ProxyMode.values;
  final needsAddress =
      proxySetting.mode == ProxyMode.http ||
      proxySetting.mode == ProxyMode.socks5;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MiuixOverlayDropdownPreference(
        title: t.settings.proxyMode,
        summary: t.settings.proxyModeSubtitle,
        items: [for (final mode in modes) mode.label],
        selectedIndex: modes.indexOf(proxySetting.mode),
        onSelectedIndexChange: (index) {
          final value = modes[index];
          if (value == proxySetting.mode) return;
          _updateProxySetting(context, proxySetting.copyWith(mode: value));
        },
        startAction: MiuixSettingHelpers.icon(
          fallback: Icons.router_outlined,
          name: 'router',
        ),
        insideMargin: MiuixSettingHelpers.itemMargin,
      ),
      if (needsAddress) ...[
        const MiuixHorizontalDivider(),
        proxyAddressEdit(context, proxySetting),
      ],
    ],
  );
}

void _updateProxySetting(BuildContext context, ProxySettingState next) {
  context.read<GlobalSettingCubit>().updateState(
    (current) => current.copyWith(proxySetting: next),
  );
  applyProxySetting(next);
}

Widget proxyAddressEdit(BuildContext context, ProxySettingState proxySetting) {
  final currentProxy = proxySetting.address;
  return MiuixArrowPreference(
    title: t.settings.proxyAddress,
    summary: currentProxy.isEmpty
        ? t.settings.proxySubtitle
        : t.settings.proxyCurrent(currentProxy: currentProxy),
    startAction: MiuixSettingHelpers.icon(
      fallback: Icons.link_outlined,
      name: 'link',
    ),
    insideMargin: MiuixSettingHelpers.itemMargin,
    onClick: () async {
      var inputValue = currentProxy;
      final globalSettingCubit = context.read<GlobalSettingCubit>();

      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.settings.proxyAddress),
          content: TextFormField(
            initialValue: currentProxy,
            autofocus: true,
            onChanged: (value) => inputValue = value.trim(),
            decoration: InputDecoration(
              hintText: t.settings.proxyHint,
              border: const OutlineInputBorder(),
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

      if (result != null && result != currentProxy) {
        final next = proxySetting.copyWith(address: result);
        globalSettingCubit.updateState(
          (current) => current.copyWith(proxySetting: next),
        );
        applyProxySetting(next);
      }
    },
  );
}

Widget webdavSync(BuildContext context, SyncServiceType syncServiceType) {
  final title = switch (syncServiceType) {
    SyncServiceType.none => t.settings.syncConfig,
    _ => t.webdavSync.serviceTitle(
      service: switch (syncServiceType) {
        SyncServiceType.webdav => t.settings.syncServiceWebdav,
        SyncServiceType.s3 => t.settings.syncServiceS3,
        SyncServiceType.none => '',
      },
    ),
  };

  return MiuixArrowPreference(
    title: title,
    summary: t.settings.syncConfigSubtitle,
    startAction: MiuixSettingHelpers.icon(
      fallback: Icons.cloud_outlined,
      name: 'cloud',
    ),
    insideMargin: MiuixSettingHelpers.itemMargin,
    onClick: () {
      AutoRouter.of(context).push(const WebDavSyncRoute());
    },
  );
}

Widget editMaskedKeywords(BuildContext context) {
  return MiuixArrowPreference(
    title: t.settings.maskedKeywords,
    summary: t.settings.maskedKeywordsSubtitle,
    startAction: MiuixSettingHelpers.icon(
      fallback: Icons.shield_outlined,
      name: 'shield',
    ),
    insideMargin: MiuixSettingHelpers.itemMargin,
    onClick: () {
      showDialog(
        context: context,
        builder: (context) => const _KeywordManagementDialog(),
      );
    },
  );
}

class _KeywordManagementDialog extends StatefulWidget {
  const _KeywordManagementDialog();

  @override
  State<_KeywordManagementDialog> createState() =>
      _KeywordManagementDialogState();
}

class _KeywordManagementDialogState extends State<_KeywordManagementDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只需要在这里获取 Cubit
    final globalSettingCubit = context.read<GlobalSettingCubit>();

    return BlocBuilder<GlobalSettingCubit, GlobalSettingState>(
      builder: (context, state) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.settings.maskedKeywords,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.settings.maskedKeywordsSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 240,
                  ),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: state.maskedKeywords.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Text(
                                t.settings.maskedKeywordsEmpty,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              state.maskedKeywords.length,
                              (index) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          state.maskedKeywords[index],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () {
                                            final newList = List<String>.from(
                                              state.maskedKeywords,
                                            );
                                            newList.removeAt(index);
                                            globalSettingCubit.updateState(
                                              (current) => current.copyWith(
                                                maskedKeywords: newList,
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: t.settings.maskedKeywordsInputHint,
                          hintStyle: const TextStyle(fontSize: 14),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) =>
                            _addKeyword(globalSettingCubit, state),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _addKeyword(globalSettingCubit, state),
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(t.common.done),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addKeyword(GlobalSettingCubit cubit, GlobalSettingState state) {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !state.maskedKeywords.contains(text)) {
      final newList = [...state.maskedKeywords, text];
      cubit.updateState((current) => current.copyWith(maskedKeywords: newList));
      _controller.clear();
    }
  }
}
