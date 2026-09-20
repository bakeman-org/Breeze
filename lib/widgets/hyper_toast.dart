import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';

/// HyperOS 风格 toast 的类型。
///
/// 决定胶囊背景色：
///   - info / success → 深黑（HyperOS 默认配色）
///   - warning        → 深橙
///   - error          → 深红
enum HyperToastType { info, success, warning, error }

/// 类 HyperOS「开发者模式」toast。
///
/// 视觉特征：
///   - 屏幕中下部（默认距底 35% 高度）的深色胶囊；
///   - 白色单行/多行文字，大圆角；
///   - 淡入 160ms，停留默认 1.4s，自动消失。
///
/// 行为特征：
///   - 走 [OverlayEntry]，不占布局、不推动底部栏；
///   - 外层 [IgnorePointer]，不吞点击和滚动手势；
///   - 全局同一时刻只显示一条，重复调用会重置计时。
///
/// 使用示例：
/// ```dart
/// HyperToast.show(context, '操作成功');
/// HyperToast.showGlobal('下载完成');
/// HyperToast.show(context, '下载失败', type: HyperToastType.error);
/// ```
class HyperToast {
  HyperToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// 显示位置：屏幕高度的百分比（0.35 ≈ 中下部）。
  static const _bottomFactor = 0.35;

  /// 淡入淡出时长。
  static const _fadeDuration = Duration(milliseconds: 160);

  /// 默认停留时长（不含淡入淡出）。
  static const _defaultDuration = Duration(milliseconds: 1400);

  /// 有 [context] 时显示一条 toast。
  static void show(
    BuildContext context,
    String message, {
    HyperToastType type = HyperToastType.info,
    Duration duration = _defaultDuration,
  }) {
    _show(Overlay.maybeOf(context, rootOverlay: true), message, type, duration);
  }

  /// 不依赖 [context] 显示一条 toast。
  ///
  /// 通过全局 [navigatorKey] 拿当前 Navigator 的 Overlay，适用于异步回调
  /// 里拿不到稳定 context 的场景。
  static void showGlobal(
    String message, {
    HyperToastType type = HyperToastType.info,
    Duration duration = _defaultDuration,
  }) {
    _show(navigatorKey.currentState?.overlay, message, type, duration);
  }

  static void _show(
    OverlayState? overlay,
    String message,
    HyperToastType type,
    Duration duration,
  ) {
    if (overlay == null) return;

    // 先清掉上一条，保证屏幕上永远只有一条。
    dismiss();

    _entry = OverlayEntry(
      builder: (_) => _HyperToastWidget(
        message: message,
        type: type,
        bottomFactor: _bottomFactor,
        fadeDuration: _fadeDuration,
      ),
    );
    overlay.insert(_entry!);

    _timer = Timer(duration, dismiss);
  }

  /// 手动关闭当前 toast。
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _HyperToastWidget extends StatefulWidget {
  const _HyperToastWidget({
    required this.message,
    required this.type,
    required this.bottomFactor,
    required this.fadeDuration,
  });

  final String message;
  final HyperToastType type;
  final double bottomFactor;
  final Duration fadeDuration;

  @override
  State<_HyperToastWidget> createState() => _HyperToastWidgetState();
}

class _HyperToastWidgetState extends State<_HyperToastWidget> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // 首帧后再置 1，触发 AnimatedOpacity 的淡入动画。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case HyperToastType.info:
      case HyperToastType.success:
        return Colors.black.withValues(alpha: 0.8);
      case HyperToastType.warning:
        return const Color(0xFFB25A00).withValues(alpha: 0.92);
      case HyperToastType.error:
        return const Color(0xFFB3261E).withValues(alpha: 0.92);
    }
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
            duration: widget.fadeDuration,
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _backgroundColor,
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
