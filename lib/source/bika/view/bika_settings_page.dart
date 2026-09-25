import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/auth/bika_setting.dart';

@RoutePage()
class BikaSettingsPage extends StatefulWidget {
  const BikaSettingsPage({super.key});

  @override
  State<BikaSettingsPage> createState() => _BikaSettingsPageState();
}

class _BikaSettingsPageState extends State<BikaSettingsPage> {
  static const _apiMain = 'picacomic';
  static const _apiBackup = 'go2778';

  static const Map<String, String> _qualityOptions = {
    'original': 'qualityOriginal',
    'low': 'qualityLow',
    'medium': 'qualityMedium',
    'high': 'qualityHigh',
  };

  String _qualityLabel(String key) {
    switch (_qualityOptions[key]) {
      case 'qualityOriginal':
        return t.bika.qualityOriginal;
      case 'qualityLow':
        return t.bika.qualityLow;
      case 'qualityMedium':
        return t.bika.qualityMedium;
      case 'qualityHigh':
        return t.bika.qualityHigh;
      default:
        return key;
    }
  }

  void _save(BikaNativeSetting setting) {
    saveBikaNativeSetting(setting);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setting = bikaNativeSetting;
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.settings,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 28,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            setting.account.isEmpty
                                ? t.bika.notLoggedIn
                                : setting.account,
                            style: theme.textTheme.bodyLarge,
                          ),
                          Text(
                            setting.hasAuthorization
                                ? t.bika.done
                                : t.bika.notLoggedIn,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.bika.line,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: setting.api,
                onChanged: (value) {
                  if (value == null || value == setting.api) return;
                  _save(setting.copyWith(api: value));
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: _apiMain,
                      title: Text(t.bika.lineMain),
                    ),
                    RadioListTile<String>(
                      value: _apiBackup,
                      title: Text(t.bika.lineBackup),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.bika.imageQuality,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: setting.imageQuality,
                onChanged: (value) {
                  if (value == null || value == setting.imageQuality) return;
                  _save(setting.copyWith(imageQuality: value));
                },
                child: Column(
                  children: [
                    for (final quality in _qualityOptions.keys)
                      RadioListTile<String>(
                        value: quality,
                        title: Text(_qualityLabel(quality)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
