import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';

class ReaderActionController {
  final BuildContext context;
  final PageController pageController;
  final bool Function(bool isNext)? onBeforeTurnPage;
  final bool Function()? isUserScrolling;

  /// 列模式下「按像素滚动」的代理。
  ///
  /// 旧版用 ScrollController 直接 jumpTo/ animateTo；换成
  /// ScrollablePositionedList 后没有 ScrollController，只能通过
  /// index 跳。列模式下的「滚动」都改为整屏翻页——对阅读器而言，
  /// 一屏一屏跳比按像素更符合直觉，也绕开了 SPL 不支持 offset 的问题。
  final void Function({required int slotDelta})? onScrollBySlot;

  ReaderActionController({
    required this.context,
    required this.pageController,
    this.onBeforeTurnPage,
    this.isUserScrolling,
    this.onScrollBySlot,
  });

  ReadSettingState get _readSetting =>
      context.read<GlobalSettingCubit>().state.readSetting;

  int get _readMode => _readSetting.readMode;

  int get _currentSlot => context.read<ReaderCubit>().state.currentSlot;

  int get _totalSlots => context.read<ReaderCubit>().state.totalSlots;

  bool get _noAnimation => _readSetting.noAnimation;

  bool get _volumeKeyPageTurnEnabled => _readSetting.volumeKeyPageTurn;

  void onKeyScrollNext() {
    if (_readMode == 0) {
      _scrollBySlot(1);
    } else {
      _turnPage(isNext: true);
    }
  }

  void onKeyScrollPrev() {
    if (_readMode == 0) {
      _scrollBySlot(-1);
    } else {
      _turnPage(isNext: false);
    }
  }

  void onPageActionNext() {
    if (_readMode == 0) {
      _scrollBySlot(1);
    } else {
      _turnPage(isNext: true);
    }
  }

  void onPageActionPrev() {
    if (_readMode == 0) {
      _scrollBySlot(-1);
    } else {
      _turnPage(isNext: false);
    }
  }

  void onVolumeActionNext() {
    if (!_volumeKeyPageTurnEnabled) return;
    if (_readMode == 0) {
      _scrollBySlot(1);
    } else {
      _turnPage(isNext: true);
    }
  }

  void onVolumeActionPrev() {
    if (!_volumeKeyPageTurnEnabled) return;
    if (_readMode == 0) {
      _scrollBySlot(-1);
    } else {
      _turnPage(isNext: false);
    }
  }

  void onAutoReadTick({double? deltaMs}) {
    if (_readMode == 0) {
      _scrollBySlot(1);
    } else {
      _turnPage(isNext: true);
    }
  }

  void _scrollBySlot(int delta) {
    if (isUserScrolling?.call() ?? false) return;
    onScrollBySlot?.call(slotDelta: delta);
  }

  void _turnPage({required bool isNext}) {
    if (onBeforeTurnPage?.call(isNext) ?? false) return;
    if (!pageController.hasClients) return;

    final shouldGoForward = isNext;
    final noAnimation = _noAnimation;

    if (noAnimation) {
      final totalSlots = _totalSlots;
      if (totalSlots <= 0) return;

      final currentSlot = _currentSlot;
      final targetSlot = (currentSlot + (shouldGoForward ? 1 : -1)).clamp(
        0,
        totalSlots - 1,
      );
      pageController.jumpToPage(targetSlot);
      return;
    }

    if (shouldGoForward) {
      pageController.nextPage(
        duration: kReaderAnimationDuration,
        curve: Curves.easeInOut,
      );
    } else {
      pageController.previousPage(
        duration: kReaderAnimationDuration,
        curve: Curves.easeInOut,
      );
    }
  }
}
