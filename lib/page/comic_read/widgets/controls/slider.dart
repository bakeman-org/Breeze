import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/util/context/context_extensions.dart';

class SliderWidget extends StatefulWidget {
  final ItemScrollController itemScrollController;
  final PageController pageController;
  final int Function()? getCurrentChapterSlotCount;
  final int Function(int globalSlot)? mapGlobalToLocalSlot;
  final int Function(int localSlot)? mapLocalToGlobalSlot;
  final bool Function(int globalSlot)? isTransitionSlot;
  final String transitionLabel;

  const SliderWidget({
    super.key,
    required this.itemScrollController,
    required this.pageController,
    this.getCurrentChapterSlotCount,
    this.mapGlobalToLocalSlot,
    this.mapLocalToGlobalSlot,
    this.isTransitionSlot,
    this.transitionLabel = '',
  });

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  Timer? _sliderIsRollingTimer;
  Timer? _comicRollingTimer;
  OverlayEntry? _overlayEntry;
  int? _lastHapticStep;

  @override
  void dispose() {
    _sliderIsRollingTimer?.cancel();
    _comicRollingTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.9,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            child: _SliderContents(configuration: widget, owner: this),
          ),
        ),
      ),
    );
  }

  void _showOverlayToast(String message) {
    final isNumeric = int.tryParse(message) != null;
    final fontSize = isNumeric ? 60.0 : 34.0;
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48.0,
                      vertical: 24.0,
                    ),
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.surfaceBright.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: message,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: context.textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 列模式跳转：按 index 定位，O(1)。
  ///
  /// 旧版先估算像素偏移 jumpTo，再用 observerController 精修，两步都在
  /// ListView 的「像素定位」框架里，跳 200 页要触发连锁构建。SPL 的
  /// jumpTo(index) 直接把锚点设到目标项，中间 199 项根本不构建。
  void _jumpColumn(int targetGlobalSlot) {
    if (!widget.itemScrollController.isAttached) return;
    widget.itemScrollController.jumpTo(index: targetGlobalSlot, alignment: 0);
  }
}

class _SliderContents extends StatelessWidget {
  const _SliderContents({required this.configuration, required this.owner});

  final SliderWidget configuration;
  final _SliderWidgetState owner;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReaderCubit>();
    final totalSlots = context.select(
      (ReaderCubit cubit) => cubit.state.totalSlots,
    );
    final readSetting = context.select<GlobalSettingCubit, ReadSettingState>(
      (cubit) => cubit.state.readSetting,
    );
    final sliderValue = context.select(
      (ReaderCubit cubit) => cubit.state.sliderValue,
    );
    final globalMaxValue = totalSlots > 0 ? totalSlots.toDouble() - 1 : 0;
    final safeGlobalSliderValue = sliderValue
        .clamp(0.0, globalMaxValue)
        .toDouble();
    final currentChapterSlotCount =
        configuration.getCurrentChapterSlotCount?.call() ?? totalSlots;
    final localMaxValue = currentChapterSlotCount > 0
        ? currentChapterSlotCount.toDouble() - 1
        : 0.0;
    final mappedLocalSliderValue =
        configuration.mapGlobalToLocalSlot?.call(
          safeGlobalSliderValue.round(),
        ) ??
        safeGlobalSliderValue.round();
    final safeSliderValue = mappedLocalSliderValue.toDouble().clamp(
      0.0,
      localMaxValue,
    );

    final insertLeadingBlank =
        readSetting.doublePageMode && readSetting.doublePageLeadingBlank;
    final sliderDisplayPage = getDisplayPageNumber(
      slotIndex: safeSliderValue.round(),
      enableDoublePage: readSetting.doublePageMode,
      insertLeadingBlank: insertLeadingBlank,
    );
    final currentGlobalSlot = safeGlobalSliderValue.round();
    final isCurrentTransitionSlot =
        configuration.isTransitionSlot?.call(currentGlobalSlot) ?? false;
    final effectiveTransitionLabel = configuration.transitionLabel.isEmpty
        ? t.reader.chapterTransition
        : configuration.transitionLabel;
    final sliderLabelText = isCurrentTransitionSlot
        ? effectiveTransitionLabel
        : sliderDisplayPage.toString();

    if (safeGlobalSliderValue != sliderValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!owner.mounted) return;
        cubit.updateSliderChanged(safeGlobalSliderValue);
      });
    }

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: context.theme.colorScheme.primary,
        inactiveTrackColor: context.theme.colorScheme.primary.withValues(
          alpha: 0.22,
        ),
        thumbColor: context.theme.colorScheme.primary,
        overlayColor: context.theme.colorScheme.primary.withValues(alpha: 0.16),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: safeSliderValue,
        min: 0,
        max: localMaxValue,
        divisions: localMaxValue > 0 ? localMaxValue.toInt() : null,
        label: sliderLabelText,
        onChangeStart: (value) {
          owner._lastHapticStep = value.round();
        },
        onChanged: (double newValue) {
          final clampedLocalValue = newValue.clamp(0.0, localMaxValue);
          final currentStep = clampedLocalValue.round();
          final targetGlobalSlot =
              configuration.mapLocalToGlobalSlot?.call(currentStep) ??
              currentStep;
          final targetGlobalValue = targetGlobalSlot.toDouble();
          if (owner._lastHapticStep != currentStep) {
            HapticFeedback.selectionClick();
            owner._lastHapticStep = currentStep;
          }

          if (sliderValue != targetGlobalValue) {
            cubit.updateSliderChanged(targetGlobalValue);
          }

          cubit.updateIsComicRolling(true);
          owner._sliderIsRollingTimer?.cancel();

          final displayPage = getDisplayPageNumber(
            slotIndex: currentStep,
            enableDoublePage: readSetting.doublePageMode,
            insertLeadingBlank: insertLeadingBlank,
          );
          final toastMessage =
              configuration.isTransitionSlot?.call(targetGlobalSlot) ?? false
              ? effectiveTransitionLabel
              : displayPage.toString();
          owner._showOverlayToast(toastMessage);

          owner._sliderIsRollingTimer = Timer(
            const Duration(milliseconds: 300),
            () {
              cubit.updateSliderRolling(true);
              cubit.updateIsComicRolling(true);
              owner._comicRollingTimer = Timer(
                const Duration(milliseconds: 350),
                () {
                  cubit.updateSliderRolling(false);
                  cubit.updateIsComicRolling(false);
                  owner._overlayEntry?.remove();
                  owner._overlayEntry = null;
                },
              );

              final globalSettingState = context
                  .read<GlobalSettingCubit>()
                  .state;

              try {
                if (globalSettingState.readSetting.readMode == 0) {
                  // ★ 直接按 index 定位，无估算，无二次校正
                  owner._jumpColumn(targetGlobalSlot);
                } else {
                  configuration.pageController.jumpToPage(targetGlobalSlot);
                }
              } catch (e) {
                logger.e(e);
              }
            },
          );
        },
        onChangeEnd: (_) {
          owner._lastHapticStep = null;
        },
      ),
    );
  }
}
