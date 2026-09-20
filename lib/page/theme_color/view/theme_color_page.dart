// 主题色选择页。
//
// 交互参考 haka_comic 的「主题颜色」下拉选择，UI 用 flutter_miuix 的
// MiuixSpinnerPreference + MiuixCard 卡片分组。
//
// 页面结构：
//   ┌─ 预设颜色
//   │   └─ MiuixCard
//   │       ├─ MiuixOverlaySpinnerPreference  ← 预设色下拉
//   │       └─ MiuixBasicComponent            ← 当前色预览
//   └─ 说明文字
//
// 说明：预设色列表来自 color_theme_types.dart 的 colorThemeList，
//      每项包含 .color 和 .localizedLabel。

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/color_theme_types.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';

@RoutePage()
class ThemeColorPage extends StatefulWidget {
  const ThemeColorPage({super.key});

  @override
  State<ThemeColorPage> createState() => _ThemeColorPageState();
}

class _ThemeColorPageState extends State<ThemeColorPage> {
  /// 分组卡片内 preference 项的紧凑内边距。与其它设置页保持一致。
  static const _itemMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// 当前生效的种子色。初始化时从持久化的用户设置里读一次；
  /// 后续选择时同步更新「本地 UI 状态 + 全局 Cubit」。
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = objectbox.userSettingBox.get(1)!.globalSetting.seedColor;
  }

  /// 找到当前色在预设列表里的索引。找不到返回 -1。
  int get _selectedIndex {
    for (var i = 0; i < colorThemeList.length; i++) {
      // ignore: deprecated_member_use
      if (colorThemeList[i].color.value == _currentColor.value) return i;
    }
    return -1;
  }

  /// 构造微调项列表：每个预设配一个色块图标 + 标签 + 十六进制摘要。
  List<MiuixDropdownItem> get _colorItems {
    return colorThemeList.map((info) {
      return MiuixDropdownItem(
        text: info.localizedLabel,
        summary: _hex(info.color),
        icon: _ColorSwatch(color: info.color),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;

    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.settings.themeColor,
        navigationIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: MiuixIconButton(
              onPressed: () => context.router.maybePop(),
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ),
      // MiuixScaffold 的 content 区域不提供 Material 祖先；
      // 包一层透明 Material，方便内部使用 InkWell 之类的组件。
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: padding.copyWith(bottom: 32),
          children: [
            // ───────── 预设颜色 ─────────
            MiuixSmallTitle('预设颜色'),
            MiuixCard(
              child: Column(
                children: [
                  MiuixOverlaySpinnerPreference(
                    title: t.settings.themeColor,
                    summary: selectedIndex >= 0
                        ? colorThemeList[selectedIndex].localizedLabel
                        : _hex(_currentColor),
                    items: _colorItems,
                    // selectedIndex 兜底 0 只是为了让下拉列表能正常打开；
                    // summary 已经把实际颜色展示出来。
                    selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                    insideMargin: _itemMargin,
                    onSelectedIndexChange: (i) {
                      _applyColor(colorThemeList[i].color);
                    },
                  ),
                  const MiuixHorizontalDivider(),
                  // 当前色预览。色块 + 十六进制值，方便用户确认。
                  MiuixBasicComponent(
                    title: '当前颜色',
                    summary: _hex(_currentColor),
                    startAction: _ColorSwatch(color: _currentColor),
                    insideMargin: _itemMargin,
                    onClick: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 一段说明性文字，告诉用户当前选择会立刻影响整个应用的主题。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MiuixText(
                '选择的颜色会作为 Material 3 的种子色，实时应用到整个应用。',
                style: MiuixTheme.of(context).textStyles.footnote1,
                color: MiuixTheme.of(context).colors.onSurfaceVariantSummary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 应用新的种子色。
  ///
  /// 同时更新：
  ///   1. 本地 UI 状态（触发本页 rebuild，刷新 summary 和色块）；
  ///   2. 全局 Cubit 状态（触发 MyApp rebuild，全应用换主题）。
  void _applyColor(Color color) {
    setState(() => _currentColor = color);
    context.read<GlobalSettingCubit>().updateState(
      (current) => current.copyWith(seedColor: color),
    );
  }

  /// 把颜色格式化成 `#RRGGBB` 形式。
  static String _hex(Color color) {
    // 用 .value 而不是 toARGB32()，兼容不同 Flutter 版本。
    // ignore: deprecated_member_use
    final v = color.value & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

/// 色块图标。
///
/// 用作 [MiuixDropdownItem.icon] 或 [MiuixBasicComponent.startAction] 的
/// 内容。用 6px 圆角方形而非正圆，和 Miuix 菜单项的图标槽（24×24）更协调。
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
    );
  }
}
