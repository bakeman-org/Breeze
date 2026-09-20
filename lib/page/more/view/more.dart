import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/more/more.dart';
import 'package:zephyr/service/app_icon/app_icon_service.dart';
import 'package:zephyr/widgets/hyper_toast.dart';

@RoutePage()
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: ListView(
              children: const [
                SizedBox(height: 24),
                _AppIconHeader(),
                SettingsWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部 header：应用图标 + 名称。
///
/// 图标本身通过 [AppIconService] 订阅 —— 任何地方改了应用图标，这里都会
/// 同步刷新，不需要页面之间传递状态。
///
/// **连续点击 3 次**（每次间隔 < 1 秒）会弹出应用图标选择弹窗。仅在
/// Android / iOS 上生效；其他平台点击无反应。
///
/// 连点过程中会显示类似小米 HyperOS「开发者模式」的 toast，提示还剩几次。
class _AppIconHeader extends StatefulWidget {
  const _AppIconHeader();

  @override
  State<_AppIconHeader> createState() => _AppIconHeaderState();
}

class _AppIconHeaderState extends State<_AppIconHeader> {
  /// 连点窗口：两次点击间隔不超过此值才算连点，否则计数重置。
  static const _multiTapWindow = Duration(seconds: 1);

  /// 触发切换所需的点击数。
  static const _requiredTaps = 3;

  int _tapCount = 0;
  DateTime? _lastTapAt;

  @override
  void initState() {
    super.initState();
    // 触发一次加载。幂等，多次进入页面不会重复查询。
    AppIconService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    // 页面销毁时顺手关掉 toast，避免残留在 Overlay 上。
    HyperToast.dismiss();
    super.dispose();
  }

  void _handleTap() {
    // 连点切换图标只在移动平台有效。
    // 桌面端不阻断，但点击也不做任何事（否则用户会困惑「点了没反应」）。
    if (!_supportsDynamicIcon) return;

    final now = DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!) <= _multiTapWindow) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapAt = now;

    final remaining = _requiredTaps - _tapCount;
    if (remaining <= 0) {
      _tapCount = 0;
      _lastTapAt = null;
      HyperToast.dismiss();
      _showIconPicker();
    } else {
      HyperToast.show(context, '再点击 $remaining 次切换应用图标');
    }
  }

  bool get _supportsDynamicIcon =>
      AppIconService.instance.value.iconName != null ||
      // 未加载完成时也允许点击，让用户在 Android 上即便尚未加载也能触发。
      // 真正的平台判断放在 AppIconService.switchTo 里。
      true;

  Future<void> _showIconPicker() async {
    // 结果用 record 包装，区分「取消」(null) 和「选了某个图标」(可能 name 是 null)。
    final result = await showModalBottomSheet<({String? name})>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 400),
      builder: (sheetContext) => _AppIconPickerSheet(
        onSelect: (name) => Navigator.of(sheetContext).pop((name: name)),
      ),
    );
    if (result == null) return; // 用户取消

    final ok = await AppIconService.instance.switchTo(result.name);
    if (!mounted) return;

    if (ok) {
      HyperToast.show(
        context,
        result.name == null ? '已切换为「经典」图标' : '已切换为「现代」图标',
      );
    } else {
      HyperToast.show(context, '切换应用图标失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // HitTestBehavior.opaque：让整个 header 区域都能响应点击（包括图标
      // 和文字之间的留白），同时不阻断外层 ListView 的滚动手势。
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Column(
        children: [
          // 订阅 AppIconService：任何地方改了图标，这里自动刷新。
          //
          // AnimatedSwitcher 用 asset 路径作为 key，图标变化时做淡入淡出。
          ValueListenableBuilder<AppIconState>(
            valueListenable: AppIconService.instance,
            builder: (context, state, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: ClipRRect(
                  key: ValueKey(state.assetPath),
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    state.assetPath,
                    width: 88,
                    height: 88,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 88, height: 88),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Breeze',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 图标选择底部弹窗
// ─────────────────────────────────────────────────────────────────────

/// 图标选择弹窗。
///
/// 展示两个选项（经典 / 现代），并高亮当前生效的那个。选项的展示信息直接
/// 从 [AppIconService] 里拿，不重复定义 asset 路径。
class _AppIconPickerSheet extends StatelessWidget {
  const _AppIconPickerSheet({required this.onSelect});

  /// 选中回调。name 为 null 表示选择了「经典」。
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '选择应用图标',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '选择后将应用新的应用图标',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 34),
          // 订阅 AppIconService：当前选中项自动跟随。
          ValueListenableBuilder<AppIconState>(
            valueListenable: AppIconService.instance,
            builder: (context, current, _) {
              return Row(
                spacing: 18,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AppIconOption(
                    state: const AppIconState.classic(),
                    backgroundColor: const Color(0xFFd0ffad),
                    selected: current.iconName == null,
                    onTap: () => onSelect(null),
                  ),
                  _AppIconOption(
                    state: const AppIconState.modern(),
                    backgroundColor: const Color(0xFFfef9fa),
                    selected: current.iconName == AppIconService.modernIconName,
                    onTap: () => onSelect(AppIconService.modernIconName),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 单个图标选项卡片。
///
/// 所有展示信息（label / asset）都从 [AppIconState] 里取，不在 UI 层再写一遍。
class _AppIconOption extends StatelessWidget {
  const _AppIconOption({
    required this.state,
    required this.backgroundColor,
    required this.selected,
    required this.onTap,
  });

  final AppIconState state;
  final Color backgroundColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: state.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 112,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        state.assetPath,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: -5,
                        bottom: -5,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surfaceContainerLowest,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            color: colorScheme.onPrimary,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  state.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
