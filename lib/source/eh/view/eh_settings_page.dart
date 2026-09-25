import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/auth/eh_setting.dart';

@RoutePage()
class EhSettingsPage extends StatefulWidget {
  const EhSettingsPage({super.key});

  @override
  State<EhSettingsPage> createState() => _EhSettingsPageState();
}

class _EhSettingsPageState extends State<EhSettingsPage> {
  void _saveSite(String site) {
    saveEhSettingState(ehSettingState.copyWith(site: site));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setting = ehSettingState;
    final cookieItems = <(String, bool)>[
      (t.eh.memberId, setting.ipbMemberId.isNotEmpty),
      (t.eh.passHash, setting.ipbPassHash.isNotEmpty),
      (t.eh.igneous, setting.igneous.isNotEmpty),
    ];
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.settings,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                t.eh.site,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: setting.site,
                onChanged: (value) {
                  if (value == null || value == setting.site) return;
                  _saveSite(value);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: ehDomainE,
                      title: Text(t.eh.siteE),
                    ),
                    RadioListTile<String>(
                      value: ehDomainEx,
                      title: Text(t.eh.siteEx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cookie_outlined,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            setting.hasCredentials
                                ? t.eh.done
                                : t.eh.loginRequired,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in cookieItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.$1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              item.$2 ? t.eh.done : t.eh.notSet,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: item.$2
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: MiuixButton(
                        onPressed: () async {
                          await context.pushRoute(const EhLoginRoute());
                          if (!mounted) return;
                          setState(() {});
                        },
                        child: Text(t.eh.login),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MiuixSwitchPreference(
                title: t.eh.builtInHosts,
                summary: t.eh.builtInHostsDesc,
                value: setting.builtInHosts,
                onChanged: (value) {
                  saveEhSettingState(
                    ehSettingState.copyWith(builtInHosts: value),
                  );
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
