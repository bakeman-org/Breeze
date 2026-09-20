import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:zephyr/page/more/more.dart';

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
              children: [
                const SizedBox(height: 24),
                const _AppIconHeader(),
                const SettingsWidget(),
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
/// 在 Android / iOS 上，**连续点击 3 次**（每次间隔 < 1 秒）会弹出应用图标
/// 选择弹窗，允许在「经典 / 现代」两套图标之间切换。其他平台无效果。
///
/// 连点过程中会显示类似小米 HyperOS「开发者模式」的 toast，提示还剩几次。
class _AppIconHeader extends StatefulWidget {
  const _AppIconHeader();

  @override
  State<_AppIconHeader> createState() => _AppIconHeaderState();
}

class _AppIconHeaderState extends State<_AppIconHeader> {
  /// 现代图标在原生侧的 alternate icon 名称，需与 AndroidManifest 中
  /// 配置的 `<activity-alias android:name="...">` 保持一致。
  static const _modernIconName = 'IconModern';

  /// 经典图标的预览资源路径。
  static const _classicAsset = 'asset/image/app-icon.png';

  /// 现代图标的预览资源路径。
  static const _modernAsset = 'asset/image/app-icon-modern.png';

  /// 连点窗口：两次点击间隔不超过此值才算连点，否则计数重置。
  static const _multiTapWindow = Duration(seconds: 1);

  /// 触发切换所需的点击数。
  static const _requiredTaps = 3;

  int _tapCount = 0;
  DateTime? _lastTapAt;

  /// 当前生效的 alternate icon 名称。`null` 表示默认（经典）图标。
  String? _currentIconName;

  /// 当前生效图标对应的预览 asset 路径。
  ///
  /// header 显示的图片会跟着这个 getter 变化，所以切换图标后 header 上
  /// 的预览会立即同步为对应的图。
  String get _currentIconAsset =>
      _currentIconName == _modernIconName ? _modernAsset : _classicAsset;

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  @override
  void dispose() {
    // 页面销毁时确保 toast 也被移除，避免残留在 Overlay 上。
    _DevModeToast.dismiss();
    super.dispose();
  }

  Future<void> _loadCurrentIcon() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final name = await DynamicAppIconFlutterPlus.getAlternateIconName();
      if (mounted) {
        setState(() => _currentIconName = name);
      }
    } catch (_) {
      // 某些 ROM 不支持动态图标，静默忽略，不影响主流程。
    }
  }

  void _handleTap() {
    // 只有移动平台支持切换 alternate icon。
    if (!Platform.isAndroid && !Platform.isIOS) return;

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
      _DevModeToast.dismiss(); // 关掉倒数提示，立刻弹出选择面板
      _showIconPicker();
    } else {
      _DevModeToast.show(context, '再点击 $remaining 次切换应用图标');
    }
  }

  Future<void> _showIconPicker() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // 用 record 包装选择结果，区分两种情况：
    //   - null          → 用户直接关闭弹窗（取消）
    //   - ({name: ...}) → 用户选了某个图标，name 本身可以是 null（经典）
    final result = await showModalBottomSheet<({String? name})>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 400),
      builder: (sheetContext) => _AppIconPickerSheet(
        currentIconName: _currentIconName,
        modernIconName: _modernIconName,
        classicAsset: _classicAsset,
        modernAsset: _modernAsset,
        onSelect: (name) => Navigator.of(sheetContext).pop((name: name)),
      ),
    );
    if (result == null) return; // 用户取消
    await _selectIcon(result.name);
  }

  Future<void> _selectIcon(String? name) async {
    if (name == _currentIconName) return;
    try {
      await DynamicAppIconFlutterPlus.setAlternateIconName(name);
      if (!mounted) return;
      // setState 会触发 build，`_currentIconAsset` 随之变化，
      // header 上的图片通过 AnimatedSwitcher 平滑过渡到新图标。
      setState(() => _currentIconName = name);
      _DevModeToast.show(context, name == null ? '已切换为「经典」图标' : '已切换为「现代」图标');
    } catch (e) {
      if (!mounted) return;
      _DevModeToast.show(context, '切换应用图标失败：$e');
      debugPrint('切换应用图标失败：$e');
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
          // 切换图标时用 AnimatedSwitcher 做淡入淡出过渡。
          //
          // 注意：child 上必须挂一个随图标变化的 key（这里用 asset 路径），
          // 否则 AnimatedSwitcher 无法识别 child 已经变了，不会触发动画。
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: ClipRRect(
              key: ValueKey(_currentIconAsset),
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(_currentIconAsset, width: 88, height: 88),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 小米 HyperOS 风格的居中 toast
// ─────────────────────────────────────────────────────────────────────

/// 类 HyperOS「开发者模式」toast：屏幕中下部深色胶囊，显示一两秒后淡出。
///
/// 特点：
///   - 不占布局、不推动底部栏（走 OverlayEntry）；
///   - `IgnorePointer` 包裹，不吞点击/滚动；
///   - 同一条 toast 重复调用会重置计时，不会叠加多个。
class _DevModeToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  /// 显示位置：屏幕高度的百分比（0.35 ≈ 中下部）。
  static const _bottomFactor = 0.35;

  /// 停留时长（不含淡出动画）。
  static const _duration = Duration(milliseconds: 1400);

  static void show(BuildContext context, String message) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (_) =>
          _DevModeToastWidget(message: message, bottomFactor: _bottomFactor),
    );
    overlay.insert(_entry!);

    _timer = Timer(_duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _DevModeToastWidget extends StatefulWidget {
  const _DevModeToastWidget({
    required this.message,
    required this.bottomFactor,
  });

  final String message;
  final double bottomFactor;

  @override
  State<_DevModeToastWidget> createState() => _DevModeToastWidgetState();
}

class _DevModeToastWidgetState extends State<_DevModeToastWidget> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // 首帧后再置 1，触发 AnimatedOpacity 的淡入动画。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).size.height * widget.bottomFactor,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  // 小米的 toast 底色大约 0.78 ~ 0.82 的纯黑。
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
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
// 图标选择底部弹窗
// ─────────────────────────────────────────────────────────────────────

class _AppIconPickerSheet extends StatelessWidget {
  const _AppIconPickerSheet({
    required this.currentIconName,
    required this.modernIconName,
    required this.classicAsset,
    required this.modernAsset,
    required this.onSelect,
  });

  /// 当前生效的 alternate icon 名称；`null` 表示经典图标。
  final String? currentIconName;

  /// 现代图标在原生侧的名称。
  final String modernIconName;

  /// 经典图标的预览资源路径。
  final String classicAsset;

  /// 现代图标的预览资源路径。
  final String modernAsset;

  /// 选中回调。`null` 表示选择了「经典」。
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
          Row(
            spacing: 18,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AppIconOption(
                label: '经典',
                asset: classicAsset,
                backgroundColor: const Color(0xFFd0ffad),
                selected: currentIconName == null,
                onTap: () => onSelect(null),
              ),
              _AppIconOption(
                label: '现代',
                asset: modernAsset,
                backgroundColor: const Color(0xFFfef9fa),
                selected: currentIconName == modernIconName,
                onTap: () => onSelect(modernIconName),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppIconOption extends StatelessWidget {
  const _AppIconOption({
    required this.label,
    required this.asset,
    required this.backgroundColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final Color backgroundColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
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
                        asset,
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
                  label,
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
