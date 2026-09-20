import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/controller/reader_volume_controller.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_slot_builder.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_transition_style.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_utils.dart';

/// 列模式列表。
///
/// 用 [ScrollablePositionedList] 而非 [ListView]：前者支持**按 index** 定位
/// （`itemScrollController.jumpTo(index: 200)`），语义等同 Compose 的
/// `LazyListState.scrollToItem(200)`——直接把锚点设到目标项，中间 199 项
/// 完全不会构建。ListView 是像素定位（`jumpTo(offset)`），必须先从锚点
/// 累加各项高度反推位置，跳页时会触发连锁构建，正是「流水式加载」的根源。
class ColumnModeWidget extends StatefulWidget {
  final List<ReadModeEntry> entries;
  final bool enableDoublePage;
  final bool isRtl;
  final String comicId;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final String from;
  final ScrollPhysics? parentPhysics;
  final bool disableScroll;
  final ReaderVolumeController volumeController;
  final ValueChanged<bool> onUserScrollActiveChanged;
  final ValueChanged<int> onGlobalSlotChanged;
  final ValueChanged<int> onTransitionAction;

  const ColumnModeWidget({
    super.key,
    required this.entries,
    required this.enableDoublePage,
    required this.isRtl,
    required this.comicId,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.from,
    this.parentPhysics,
    this.disableScroll = false,
    required this.volumeController,
    required this.onUserScrollActiveChanged,
    required this.onGlobalSlotChanged,
    required this.onTransitionAction,
  });

  @override
  State<ColumnModeWidget> createState() => _ColumnModeWidgetState();
}

class _ColumnModeWidgetState extends State<ColumnModeWidget> {
  bool get _isDoublePage => widget.enableDoublePage;

  /// 上次上报的全局槽位，用于去重。
  int? _lastReportedIndex;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    widget.itemPositionsListener.itemPositions.removeListener(
      _onPositionsChanged,
    );
    super.dispose();
  }

  /// 可见项变化时同步当前槽位。
  ///
  /// 取「可见项中间那个」作为当前页——和旧版 ListViewObserver.onObserve
  /// 的 `all[all.length ~/ 2]` 逻辑保持一致。
  void _onPositionsChanged() {
    if (!mounted) return;
    final positions = widget.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final sorted = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final middle = sorted[sorted.length ~/ 2];
    final index = middle.index;

    if (_lastReportedIndex == index) return;
    _lastReportedIndex = index;

    widget.onGlobalSlotChanged(index);

    final cubit = context.read<ReaderCubit>();
    if (cubit.state.currentSlot != index) {
      cubit.updateCurrentSlot(index);
    }

    if (cubit.state.isMenuVisible) {
      cubit.updateMenuVisible(visible: false);
      widget.volumeController.enableInterception();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hideTop = context.select(
          (GlobalSettingCubit c) => !c.state.readSetting.comicReadTopContainer,
        );
        final mediaQuery = MediaQuery.of(context);
        final readSetting = context.select(
          (GlobalSettingCubit c) => c.state.readSetting,
        );
        final backgroundColor = readSetting.resolveReaderBackgroundColor(
          Theme.of(context).brightness,
        );
        final sidePaddingEnabled = readSetting.sidePaddingEnabled;
        final sidePaddingPercent = readSetting.sidePaddingPercent;
        final topInset = mediaQuery.padding.top > 0
            ? mediaQuery.padding.top
            : mediaQuery.viewPadding.top;
        final bottomInset = mediaQuery.padding.bottom > 0
            ? mediaQuery.padding.bottom
            : mediaQuery.viewPadding.bottom;

        final double topPadding = hideTop ? 0 : topInset;
        final double bottomPadding = bottomInset + 50;

        final containerWidth = constraints.maxWidth;
        final contentWidth = getConstrainedImageWidth(
          containerWidth: containerWidth,
          enableSidePadding: sidePaddingEnabled,
          sidePaddingPercent: sidePaddingPercent,
        );
        final viewportShortEdge = math.min(
          contentWidth,
          MediaQuery.of(context).size.height,
        );

        final doublePageSlots = _isDoublePage
            ? buildReadModeDoublePageSlots(
                widget.entries,
                insertLeadingBlank: readSetting.doublePageLeadingBlank,
              )
            : const <ReadModeDoublePageSlot>[];
        final slotCount = _isDoublePage
            ? doublePageSlots.length
            : widget.entries.length;

        final transitionStyle = ReadModeTransitionStyle.column(
          shortEdge: viewportShortEdge,
        );

        final physics = widget.disableScroll
            ? const NeverScrollableScrollPhysics()
            : widget.parentPhysics;

        // 维护「用户正在滚动」标记：仅由真实拖拽（dragDetails 非空）开始，
        // 直到松手后的惯性/回弹完全结束（ScrollEnd）才复位，供自动滚动让位。
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              widget.onUserScrollActiveChanged(true);
            } else if (notification is ScrollEndNotification) {
              widget.onUserScrollActiveChanged(false);
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            itemScrollController: widget.itemScrollController,
            itemPositionsListener: widget.itemPositionsListener,
            physics: physics,
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            itemCount: slotCount,
            itemBuilder: (ctx, index) => buildReadModeSlot(
              context: ctx,
              slotIndex: index,
              singleItem: _isDoublePage
                  ? null
                  : ReadModeSlotItem(
                      entryIndex: index,
                      entry: widget.entries[index],
                    ),
              doublePageSlot: _isDoublePage ? doublePageSlots[index] : null,
              axis: ReadModeAxis.column,
              containerWidth: containerWidth,
              contentWidth: contentWidth,
              backgroundColor: backgroundColor,
              isRtl: widget.isRtl,
              comicId: widget.comicId,
              from: widget.from,
              onTransitionAction: widget.onTransitionAction,
              transitionStyle: transitionStyle,
            ),
          ),
        );
      },
    );
  }
}
