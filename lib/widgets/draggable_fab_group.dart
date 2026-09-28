import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zephyr/util/fab_position_store.dart';

/// 可拖拽 + 位置持久化的悬浮按钮组容器。
///
/// 用法：作为 `Stack` 的子项（通常用 [Positioned.fill] 包裹）放在页面内容
/// 之上。内部用一个填满父级的 [Stack] + [Positioned] 渲染子项；用户拖拽子项
/// 时位置实时更新并在松手时写入 [FabPositionStore]，下次进入页面恢复位置。
///
/// 默认位置由 [defaultAlignment] 决定（左/右手模式传入不同对齐），底部会
/// 自动避开系统导航栏（[MediaQueryData.paddingOf] 的 bottom）。拖拽过程中
/// 边界 clamp 保证子项始终完全可见且可抓取。
///
/// [extraShift] 是临时渲染偏移（不写入存储）：用于阅读器在菜单可见时把按钮
/// 抬高，避免被底部菜单遮挡。
class DraggableFabGroup extends StatefulWidget {
  const DraggableFabGroup({
    super.key,
    required this.pageKey,
    this.defaultAlignment = Alignment.bottomRight,
    this.margin = 16.0,
    this.extraShift = Offset.zero,
    required this.child,
  });

  /// 持久化键。同页多个实例应使用相同 pageKey 才能共享位置。
  final String pageKey;

  /// 无存储位置时的默认对齐。通常 `leftHandMode ? bottomLeft : bottomRight`。
  final Alignment defaultAlignment;

  /// 边缘留白（屏幕四周）。
  final double margin;

  /// 临时渲染偏移（不持久化）。
  final Offset extraShift;

  /// FAB 组内容。
  final Widget child;

  @override
  State<DraggableFabGroup> createState() => _DraggableFabGroupState();
}

class _DraggableFabGroupState extends State<DraggableFabGroup> {
  final GlobalKey _childKey = GlobalKey();

  /// 子项左上角相对本容器左上角的坐标。null = 尚未测量/初始化。
  Offset? _position;
  Size? _childSize;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _position = FabPositionStore.getOffset(widget.pageKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_measured) {
      _measured = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndApply());
    }
  }

  void _measureAndApply() {
    if (!mounted) return;
    _measureChild();
    if (_position == null) {
      final stack = _stackSize();
      final child = _childSize;
      if (stack != null && child != null) {
        setState(() {
          _position = _defaultOffset(stack, child);
        });
      }
    }
  }

  void _measureChild() {
    final ctx = _childKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      _childSize = ro.size;
    }
  }

  Size? _stackSize() {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.hasSize) return ro.size;
    return null;
  }

  double get _safeBottom => MediaQuery.paddingOf(context).bottom;

  Offset _defaultOffset(Size stack, Size child) {
    final a = widget.defaultAlignment;
    final m = widget.margin;
    final sb = _safeBottom;
    double dx;
    if (a.x < 0) {
      dx = m;
    } else if (a.x > 0) {
      dx = math.max(m, stack.width - child.width - m);
    } else {
      dx = (stack.width - child.width) / 2;
    }
    double dy;
    if (a.y < 0) {
      dy = m;
    } else {
      dy = math.max(m, stack.height - child.height - m - sb);
    }
    return Offset(dx, dy);
  }

  Offset _clamp(Offset pos, Size stack, Size child) {
    final m = widget.margin;
    final sb = _safeBottom;
    final maxX = math.max(0.0, stack.width - child.width);
    final maxY = math.max(0.0, stack.height - child.height - sb);
    return Offset(
      pos.dx.clamp(m, math.max(m, maxX)),
      pos.dy.clamp(m, math.max(m, maxY)),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final stack = _stackSize();
    final child = _childSize;
    if (stack == null || child == null) return;
    final base = _position ?? Offset.zero;
    setState(() {
      _position = _clamp(base + details.delta, stack, child);
    });
  }

  void _onPanEnd(_) {
    final pos = _position;
    if (pos != null) {
      FabPositionStore.saveOffset(widget.pageKey, pos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = _position;
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: (pos?.dx ?? 0.0) + widget.extraShift.dx,
            top: (pos?.dy ?? 0.0) + widget.extraShift.dy,
            child: GestureDetector(
              onPanUpdate: pos == null ? null : _onPanUpdate,
              onPanEnd: pos == null ? null : _onPanEnd,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: pos == null ? 0.0 : 1.0,
                child: KeyedSubtree(key: _childKey, child: widget.child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
