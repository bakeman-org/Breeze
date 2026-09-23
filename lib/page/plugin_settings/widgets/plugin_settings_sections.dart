import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// section 标题 + 字段列表的容器。
/// 只负责渲染标题，具体字段由调用方拼好的 children 提供。
class PluginSettingsSectionCard extends StatelessWidget {
  const PluginSettingsSectionCard({
    super.key,
    required this.title,
    required this.colorScheme,
    required this.children,
  });

  final String title;
  final ColorScheme colorScheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}

/// 通用列表行：左侧标题 + 副标题，右侧 trailing 控件，整行可点。
/// 用于 switch / select / multiChoice / action 等「点击触发交互」的字段。
class PluginSettingsFieldRow extends StatelessWidget {
  const PluginSettingsFieldRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// select / choice / multiChoice 的选项对：label 展示，value 回传插件。
class PluginSettingsOptionPair {
  const PluginSettingsOptionPair({required this.label, required this.value});

  final String label;
  final dynamic value;
}

/// 插件设置里 pill 形按钮的视觉变体。
/// 值语义与 miuix 按钮示例页保持一致：
/// - [primary]：实心强调色按钮（主操作）；
/// - [secondary]：浅色填充的次按钮；
/// - [error]：实心错误色按钮（危险操作）；
/// - [disabled]：禁用态（浅灰底 + 灰字）。
enum PluginSettingsActionButtonVariant { primary, secondary, error, disabled }

/// miuix 风格的 pill 按钮：圆角矩形、可选前置图标、四种视觉变体。
///
/// 使用 Material `Material` + `InkWell` 手搓，避免依赖 `MiuixButton`
/// 内部对主题 / 祖先的额外约束；颜色全部走 [ColorScheme]，与页面主题一致。
class PluginSettingsActionButton extends StatelessWidget {
  const PluginSettingsActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PluginSettingsActionButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PluginSettingsActionButtonVariant variant;

  /// 解析当前变体对应的（背景色, 前景色），禁用时统一走灰阶。
  (Color bg, Color fg) _resolveColors(ColorScheme scheme) {
    if (onPressed == null ||
        variant == PluginSettingsActionButtonVariant.disabled) {
      return (
        scheme.onSurface.withValues(alpha: 0.12),
        scheme.onSurface.withValues(alpha: 0.38),
      );
    }
    switch (variant) {
      case PluginSettingsActionButtonVariant.primary:
        return (scheme.primary, scheme.onPrimary);
      case PluginSettingsActionButtonVariant.secondary:
        return (scheme.surfaceContainerHighest, scheme.onSurface);
      case PluginSettingsActionButtonVariant.error:
        return (scheme.error, scheme.onError);
      case PluginSettingsActionButtonVariant.disabled:
        // 已被上方 if 兜住，不会到这里。
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

/// 插件设置里的「内联文本框」：圆角填充底 + 浮动标签 + 左侧前置图标，
/// 视觉复刻 miuix 设置页的 [MiuixTextField]。
///
/// 设计要点：
/// - [controller] 由父组件持有（详见 `PluginSettingsContent`），
///   父组件可以直接清空 / 读取文本，无需 GlobalKey 访问子 State；
/// - 内部只管理：聚焦状态、防抖计时、最近提交值。
///
/// 提交策略（任一都会走内部 `_flush`）：
/// 1. **防抖**：输入停止 [debounce]（默认 500ms）后自动提交；
/// 2. **失焦**：输入框失去焦点时立即提交；
/// 3. **组件销毁**：dispose 前补一次提交。
class PluginSettingsInlineTextField extends StatefulWidget {
  const PluginSettingsInlineTextField({
    super.key,
    required this.controller,
    required this.field,
    required this.label,
    required this.kind,
    required this.onCommit,
    this.debounce = const Duration(milliseconds: 500),
  });

  /// 外部持有的文本控制器，由父组件统一创建与释放。
  final TextEditingController controller;

  /// 原始字段描述（含 key / fnPath / persist 等），原样透传给 [onCommit]。
  final Map<String, dynamic> field;

  /// 字段标签，同时作为输入框的浮动 label。
  final String label;

  /// 字段类型：`password` 走密码模式（圆点 + 锁图标），其余按普通文本。
  final String kind;

  /// 提交回调，签名与 `PluginSettingsContent.onCommitField` 一致。
  final Future<void> Function(Map<String, dynamic> field, dynamic value)
  onCommit;

  /// 输入停止多久后自动提交一次，默认 500ms。
  final Duration debounce;

  @override
  State<PluginSettingsInlineTextField> createState() =>
      _PluginSettingsInlineTextFieldState();
}

class _PluginSettingsInlineTextFieldState
    extends State<PluginSettingsInlineTextField> {
  late final FocusNode _focusNode;
  Timer? _debounceTimer;

  /// 最近一次已提交的值，用于跳过无变化的重复提交。
  late String _lastCommitted;

  TextEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastCommitted = _controller.text;
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    // 关闭前补一次提交，避免丢掉最后一段未落地的输入。
    // 注意：controller 由父组件释放，这里只负责 FocusNode。
    _flush();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  /// 失焦即提交，避免「防抖计时未走完用户就切走」导致最后一次输入丢失。
  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _flush();
    }
  }

  void _handleChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, _flush);
  }

  /// 内部统一提交出口：跳过与已提交值相同的场景，避免重复请求。
  void _flush() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final next = _controller.text;
    if (next == _lastCommitted) {
      return;
    }
    _lastCommitted = next;
    unawaited(widget.onCommit(widget.field, next));
  }

  @override
  Widget build(BuildContext context) {
    final obscure = widget.kind == 'password';
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: obscure,
      onChanged: _handleChanged,
      style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(
          obscure ? Icons.lock_outline : Icons.edit_outlined,
          size: 22,
          color: colorScheme.onSurfaceVariant,
        ),
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
