import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';

const WidgetStateProperty<Icon> kSettingSwitchThumbIcon =
    WidgetStateProperty<Icon>.fromMap(<WidgetStatesConstraint, Icon>{
      WidgetState.selected: Icon(Icons.check),
      WidgetState.any: Icon(Icons.close),
    });

/// 设置页统一外壳：小标题栏 + 居中限宽内容区。
///
/// Miuix 迁移：Scaffold + AppBar → MiuixScaffold + MiuixSmallTopAppBar。
class SettingPageShell extends StatelessWidget {
  const SettingPageShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixSmallTopAppBar(
        title: title,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 设置页分组标题。
///
/// Miuix 迁移：自绘彩色标题 → `MiuixSmallTitle`，与「更多」页一致。
Widget settingSectionTitle(
  BuildContext context,
  String title, {
  IconData? icon,
}) {
  return MiuixSmallTitle(title);
}
