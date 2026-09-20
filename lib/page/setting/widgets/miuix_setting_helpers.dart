import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_miuix/miuix.dart';

/// 设置页通用小工具。
class MiuixSettingHelpers {
  MiuixSettingHelpers._();

  /// 分组卡片内 preference 项的统一内边距。
  static const itemMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// 构造列表项起始图标。优先 Miuix，找不到回退 Material。
  static Widget icon({
    required IconData fallback,
    required String name,
    double size = 22,
  }) {
    final vector = MiuixIcons.extended.byName(name);
    if (vector != null) {
      return MiuixIcon(vector: vector, size: size);
    }
    return Icon(fallback, size: size);
  }

  /// `MiuixTopAppBar` 用的返回按钮。
  static Widget backButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: MiuixIconButton(
          onPressed: () => context.router.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
    );
  }
}

/// 设置分组卡片。
///
/// 把一组 preference 装进一个圆角卡片，项之间自动插入 [IndentDivider]，
/// 避免每处手写 `MiuixHorizontalDivider`。参照 flutter_miuix showcase 里
/// `PreferencesShowcase` 的 `GroupCard` 用法。
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: MiuixCard(
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const IndentDivider(),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// 带缩进的分隔线。
///
/// 左缩进 52（图标宽 + 内边距），右缩进 16，和 preference 项的文字区对齐。
/// 用 `outlineVariant` 的浅色，视觉上是分隔但不像 Material 那样突兀。
class IndentDivider extends StatelessWidget {
  const IndentDivider({super.key, this.indent = 52, this.endIndent = 16});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      endIndent: endIndent,
      color: scheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}
