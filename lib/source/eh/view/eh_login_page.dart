import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/auth/eh_setting.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class EhLoginPage extends StatefulWidget {
  const EhLoginPage({super.key});

  @override
  State<EhLoginPage> createState() => _EhLoginPageState();
}

class _EhLoginPageState extends State<EhLoginPage> {
  late final TextEditingController _memberId;
  late final TextEditingController _passHash;
  late final TextEditingController _igneous;
  late String _site;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final setting = ehSettingState;
    _memberId = TextEditingController(text: setting.ipbMemberId);
    _passHash = TextEditingController(text: setting.ipbPassHash);
    _igneous = TextEditingController(text: setting.igneous);
    _site = setting.site;
  }

  @override
  void dispose() {
    _memberId.dispose();
    _passHash.dispose();
    _igneous.dispose();
    super.dispose();
  }

  void _submit() {
    if (_saving) return;
    setState(() => _saving = true);
    saveEhSettingState(
      ehSettingState.copyWith(
        site: _site,
        ipbMemberId: _memberId.text.trim(),
        ipbPassHash: _passHash.text.trim(),
        igneous: _igneous.text.trim(),
      ),
    );
    showSuccessToast(t.eh.saved);
    if (!mounted) return;
    context.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.loginTitle,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.eh.cookieHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.eh.site,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    RadioGroup<String>(
                      groupValue: _site,
                      onChanged: (value) {
                        if (value == null || value == _site) return;
                        setState(() => _site = value);
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
                    const SizedBox(height: 8),
                    MiuixTextField(
                      controller: _memberId,
                      singleLine: true,
                      label: t.eh.memberId,
                      useLabelAsPlaceholder: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    MiuixTextField(
                      controller: _passHash,
                      singleLine: true,
                      label: t.eh.passHash,
                      useLabelAsPlaceholder: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    MiuixTextField(
                      controller: _igneous,
                      singleLine: true,
                      label: t.eh.igneous,
                      useLabelAsPlaceholder: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    MiuixButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(t.eh.login),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
