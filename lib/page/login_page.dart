import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';

@RoutePage()
class LoginPage extends StatefulWidget {
  final String? from;
  final Map<String, dynamic>? loginScheme;
  final Map<String, dynamic>? loginData;

  const LoginPage({super.key, this.from, this.loginScheme, this.loginData});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _account = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String title = '';
  late String from;
  String accountLabel = '';
  String passwordLabel = '';
  bool _loadingScheme = true;
  String? _schemeError;

  @override
  void initState() {
    super.initState();
    from = (widget.from ?? '').trim();
    _loadLoginScheme();
  }

  Future<void> _loadLoginScheme() async {
    if (from.isEmpty) {
      if (mounted) {
        setState(() {
          _schemeError = t.login.missingPluginId;
          _loadingScheme = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _schemeError = null;
        _loadingScheme = true;
      });
    }

    if (widget.loginScheme != null) {
      _applyLoginBundle(widget.loginScheme!, widget.loginData);
      return;
    }

    try {
      final response = await callUnifiedComicPlugin(
        from: from,
        fnPath: 'getLoginBundle',
        core: const <String, dynamic>{},
        extern: const <String, dynamic>{},
      );
      final envelope = UnifiedPluginEnvelope.fromMap(response);
      _applyLoginBundle(envelope.scheme, envelope.data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _schemeError = t.login.loadConfigFailed(error: e);
          _loadingScheme = false;
        });
      }
    }
  }

  void _applyLoginBundle(
    Map<String, dynamic> scheme,
    Map<String, dynamic>? data,
  ) {
    final fields = asJsonList(
      scheme['fields'],
    ).map((item) => asJsonMap(item)).toList();
    if (fields.length < 2) {
      if (mounted) {
        setState(() {
          _schemeError = t.login.insufficientFields;
          _loadingScheme = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        title = scheme['title']?.toString().trim() ?? '';
        accountLabel = fields.first['label']?.toString().trim() ?? '';
        passwordLabel = fields[1]['label']?.toString().trim() ?? '';
        _schemeError = null;
        _loadingScheme = false;
      });
    }

    final payload = data ?? const <String, dynamic>{};
    _account.text = payload['account']?.toString() ?? _account.text;
    _password.text = payload['password']?.toString() ?? _password.text;
  }

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _showDialog(String title, String message) async {
    if (message.contains("invalid email or password")) {
      message = t.login.invalidCredentials;
    }

    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(children: <Widget>[Text(message)]),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(t.common.ok),
              onPressed: () => context.pop(),
            ),
          ],
        );
      },
    );
  }

  void _submitForm() async {
    if (!mounted) return;
    if (_loadingScheme || _schemeError != null) {
      showErrorToast(t.login.configNotReady);
      return;
    }
    showInfoToast(t.login.loggingIn);

    try {
      final result = await callUnifiedComicPlugin(
        from: from,
        fnPath: 'loginWithPassword',
        core: {'account': _account.text, 'password': _password.text},
        extern: const <String, dynamic>{},
      );

      final _ = asJsonMap(result['raw']);
      showSuccessToast(t.login.loginSuccess);

      if (!mounted) return;
      context.maybePop();
    } catch (e) {
      logger.e(e);
      _showDialog(t.login.loginFailed, normalizeSearchErrorMessage(e));
    }
  }

  /// 清空两个输入框，让用户重新输入。
  void _clearFields() {
    setState(() {
      _account.clear();
      _password.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingScheme) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_schemeError != null) {
      // Miuix 迁移：Scaffold + AppBar → MiuixScaffold + MiuixTopAppBar。
      return MiuixScaffold(
        topBar: MiuixTopAppBar(
          title: t.login.title,
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_schemeError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadLoginScheme,
                      child: Text(t.login.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Miuix 迁移：Scaffold + AppBar → MiuixScaffold + MiuixTopAppBar。
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: title,
        actions: [
          MiuixIconButton(
            onPressed: () => context.pushRoute(GlobalSettingRoute()),
            child: const Icon(Icons.settings),
          ),
        ],
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
                    // 账号输入框：miuix 风格，前置 person 图标。
                    _MiuixLoginField(
                      controller: _account,
                      label: accountLabel,
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // 密码输入框：miuix 风格，前置 lock 图标，圆点混淆。
                    _MiuixLoginField(
                      controller: _password,
                      label: passwordLabel,
                      icon: Icons.lock_outline,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitForm(),
                    ),
                    const SizedBox(height: 24),
                    // 按钮组：清除（次要）+ 登录（主要），右对齐。
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _MiuixPillButton(
                          label: t.common.clear,
                          icon: Icons.backspace_outlined,
                          variant: _MiuixPillVariant.secondary,
                          onPressed: _clearFields,
                        ),
                        const SizedBox(width: 12),
                        _MiuixPillButton(
                          label: t.login.loginButton,
                          icon: Icons.login,
                          variant: _MiuixPillVariant.primary,
                          onPressed: _submitForm,
                        ),
                      ],
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

/// miuix 风格的单行输入框：圆角填充底 + 浮动 label + 前置图标。
/// 与 `PluginSettingsInlineTextField` 保持同一视觉（圆角 14、聚焦描边 primary）。
class _MiuixLoginField extends StatelessWidget {
  const _MiuixLoginField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
  });

  /// 输入框内容控制器。
  final TextEditingController controller;

  /// 浮动标签文案，同时用作可访问性 label。
  final String label;

  /// 左侧前置图标（账号 / 密码各一个）。
  final IconData icon;

  /// 是否隐藏输入（密码模式）。
  final bool obscure;

  /// 键盘「下一步 / 完成」按键的行为。
  final TextInputAction? textInputAction;

  /// 用户按下键盘「完成」时的回调，用于密码框直接触发登录。
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 52,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// pill 按钮的视觉变体（与设置页按钮组保持一致的语义）。
enum _MiuixPillVariant { primary, secondary }

/// miuix 风格的 pill 按钮：圆角矩形 + 可选前置图标 + 主 / 次两种变体。
class _MiuixPillButton extends StatelessWidget {
  const _MiuixPillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = _MiuixPillVariant.primary,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调；为 null 时按钮显示禁用态。
  final VoidCallback? onPressed;

  /// 可选前置图标。
  final IconData? icon;

  /// 视觉变体。
  final _MiuixPillVariant variant;

  /// 解析变体对应的（背景色, 前景色），禁用时走灰阶。
  (Color bg, Color fg) _resolveColors(ColorScheme scheme) {
    if (onPressed == null) {
      return (
        scheme.onSurface.withValues(alpha: 0.12),
        scheme.onSurface.withValues(alpha: 0.38),
      );
    }
    switch (variant) {
      case _MiuixPillVariant.primary:
        return (scheme.primary, scheme.onPrimary);
      case _MiuixPillVariant.secondary:
        return (scheme.surfaceContainerHighest, scheme.onSurface);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = _resolveColors(scheme);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
