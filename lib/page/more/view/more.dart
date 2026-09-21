import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/more/more.dart';
import 'package:zephyr/service/app_icon/app_icon_service.dart';
import 'package:zephyr/widgets/hyper_toast.dart';

/// 展开时 header 的高度（图标 + 标题 + 上下间距）。
const double _kHeaderHeight = 180;

/// 展开触发阈值：pixels 需要 < -_kExpandTrigger（即拉出这么多像素才展开）。
///
/// 太小 → 轻微滑动就误触；太大 → 感觉迟钝。8 是经验值。
const double _kExpandTrigger = 8;

/// 收起触发阈值：pixels 超过这个值就收起。
const double _kCollapseTrigger = 60;

@RoutePage()
class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  /// header 是否展开。
  bool _headerExpanded = false;

  bool _onScroll(ScrollNotification n) {
    final pixels = n.metrics.pixels;

    // 到顶后继续下拉足够多 → 展开。
    if (pixels < -_kExpandTrigger && !_headerExpanded) {
      setState(() => _headerExpanded = true);
    }
    // 向上滚开顶部超过阈值 → 收起。
    else if (pixels > _kCollapseTrigger && _headerExpanded) {
      setState(() => _headerExpanded = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                physics: const BouncingScrollPhysics(),
                overscroll: false,
                scrollbars: false,
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    // ★ 用 _CollapsibleHeader 替代 AnimatedContainer。
                    //   一条 AnimationController 驱动高度/透明度/位移/缩放，
                    //   四个属性同步演变，视觉上像"从顶部柔和拉出"。
                    _CollapsibleHeader(
                      expanded: _headerExpanded,
                      expandedHeight: _kHeaderHeight,
                      child: const _AppIconHeader(),
                    ),
                    const SettingsWidget(),
                    const SizedBox(height: 240),
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

// ─────────────────────────────────────────────────────────────────────
// 可折叠 header：单 controller 驱动四属性
// ─────────────────────────────────────────────────────────────────────

class _CollapsibleHeader extends StatefulWidget {
  const _CollapsibleHeader({
    required this.expanded,
    required this.expandedHeight,
    required this.child,
  });

  final bool expanded;
  final double expandedHeight;
  final Widget child;

  @override
  State<_CollapsibleHeader> createState() => _CollapsibleHeaderState();
}

class _CollapsibleHeaderState extends State<_CollapsibleHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 340),
    vsync: this,
    value: widget.expanded ? 1.0 : 0.0,
  );

  /// easeOutCubic：起步快、尾段慢，符合"拉开"的物理感。
  ///
  /// 换成 [Curves.easeOutBack] 会有一点点过冲，也可以试。
  late final Animation<double> _curved = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(covariant _CollapsibleHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.expandedHeight;

    // ★ AnimatedBuilder 的 child 参数：把 child 提前构建好，避免每帧 rebuild。
    //
    // OverflowBox 让 child 始终按 expandedHeight 布局 —— 即使外层 SizedBox
    // 高度是 0，图标也不会被压扁，只是被 ClipRect 裁掉而已。
    final fixedChild = OverflowBox(
      maxHeight: h,
      alignment: Alignment.topCenter,
      child: widget.child,
    );

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        final t = _curved.value; // 0 = 收起, 1 = 展开

        // 高度：0 → h
        // 透明度：0 → 1
        // 位移：-24px → 0（从上方略微滑入，产生"落下"的感觉）
        // 缩放：0.88 → 1.0（从略微压扁到正常，跟"拉出"的视觉一致）
        return ClipRect(
          child: SizedBox(
            height: h * t,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * -24),
                child: Transform.scale(
                  scale: 0.88 + 0.12 * t,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: fixedChild,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 顶部 header：应用图标 + 名称
// ─────────────────────────────────────────────────────────────────────

/// 顶部 header：应用图标 + 名称。
///
/// 图标本身通过 [AppIconService] 订阅 —— 任何地方改了应用图标，这里都会
/// 同步刷新。
///
/// **只有图标图片区域**响应点击。连点 3 次（间隔 < 1 秒）弹出应用图标
/// 选择弹窗。点 Breeze 文字或周围留白**不会**触发切换。
class _AppIconHeader extends StatefulWidget {
  const _AppIconHeader();

  @override
  State<_AppIconHeader> createState() => _AppIconHeaderState();
}

class _AppIconHeaderState extends State<_AppIconHeader> {
  static const _multiTapWindow = Duration(seconds: 1);
  static const _requiredTaps = 3;

  int _tapCount = 0;
  DateTime? _lastTapAt;

  @override
  void initState() {
    super.initState();
    AppIconService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    HyperToast.dismiss();
    super.dispose();
  }

  void _handleTap() {
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
      AppIconService.instance.value.iconName != null || true;

  Future<void> _showIconPicker() async {
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
    if (result == null) return;

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        // 只有图标响应点击；点文字或留白无反应。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: ValueListenableBuilder<AppIconState>(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 图标选择弹窗
// ─────────────────────────────────────────────────────────────────────

class _AppIconPickerSheet extends StatelessWidget {
  const _AppIconPickerSheet({required this.onSelect});

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
