import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/auth/bika_setting.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/widgets/miuix_field_colors.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaLoginPage extends StatefulWidget {
  const BikaLoginPage({super.key});

  @override
  State<BikaLoginPage> createState() => _BikaLoginPageState();
}

class _BikaLoginPageState extends State<BikaLoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final resp = await bikaLogin(
        LoginPayload(email: email, password: password),
      );
      saveBikaNativeSetting(
        bikaNativeSetting.copyWith(
          authorization: resp.token,
          account: email,
          password: password,
        ),
      );
      showSuccessToast(t.bika.loginSuccess);
      if (!mounted) return;
      context.maybePop();
    } catch (e) {
      showErrorToast(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.loginTitle,
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
                    MiuixTextField(
                      controller: _email,
                      singleLine: true,
                      label: t.bika.account,
                      useLabelAsPlaceholder: true,
                      colors: dimmedHintFieldColors(context),
                      leadingIcon: const Icon(Icons.email_outlined, size: 20),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    MiuixTextField(
                      controller: _password,
                      singleLine: true,
                      label: t.bika.password,
                      useLabelAsPlaceholder: true,
                      colors: dimmedHintFieldColors(context),
                      leadingIcon: const Icon(Icons.lock_outline, size: 20),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    MiuixButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t.bika.login),
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
