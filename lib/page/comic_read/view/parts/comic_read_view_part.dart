// lib/page/comic_read/view/parts/comic_read_view_part.dart
part of '../comic_read.dart';

extension _ComicReadViewPart on _ComicReadPageState {
  void _prefetchImagesAroundSlot(int globalSlot, ReadSettingState readSetting) {
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final entries = seamlessCubit.resolveImageEntriesForPrefetch(
      globalSlot: globalSlot,
      readSetting: readSetting,
      count: readSetting.preloadImageCount.clamp(2, 10).toInt(),
    );

    // ★ 与列/行模式渲染时同源的 contentWidth，保证 cacheWidth 一致。
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = getConstrainedImageWidth(
      containerWidth: screenWidth,
      enableSidePadding: readSetting.sidePaddingEnabled,
      sidePaddingPercent: readSetting.sidePaddingPercent,
    );

    unawaited(
      _imagePrefetchController.prefetch(
        context: context,
        entries: entries,
        comicId: comicId,
        from: widget.from,
        count: entries.length,
        targetWidth: contentWidth,
      ),
    );
  }

  Widget _comicReadAppBar() {
    final cubit = context.read<ReaderCubit>();
    return ComicReadAppBar(
      title: epInfo.epName,
      isDesktopFullscreen: _lifecycleController.isDesktopFullscreen,
      onToggleFullscreen: _isDesktopPlatform
          ? () => unawaited(_lifecycleController.toggleDesktopFullscreen())
          : null,
      changePageIndex: (int value) {
        cubit.updateCurrentSlot(value);
        cubit.updateSliderChanged(0.0);
      },
    );
  }

  Widget _pageCountWidget() {
    final readSetting = context.read<GlobalSettingCubit>().state.readSetting;
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final seamlessEnabled = seamlessCubit.isSeamlessEnabled();
    return PageCountWidget(
      epPages: epInfo.epPages,
      getCurrentChapterStartSlot: seamlessEnabled
          ? () => seamlessCubit.currentChapterStartSlot
          : null,
      getCurrentChapterSlotCount: seamlessEnabled
          ? () => seamlessCubit.effectiveCurrentChapterSlotCount()
          : null,
      isTransitionSlot: seamlessEnabled
          ? (globalSlot) =>
                seamlessCubit.isTransitionSlot(globalSlot, readSetting)
          : null,
    );
  }

  Widget _bottomWidget(BuildContext innerContext) {
    final readSetting = context.read<GlobalSettingCubit>().state.readSetting;
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final seamlessEnabled = seamlessCubit.isSeamlessEnabled();
    final slider = SliderWidget(
      itemScrollController: _itemScrollController,
      pageController: _pageController,
      getCurrentChapterSlotCount: seamlessEnabled
          ? () => seamlessCubit.effectiveCurrentChapterSlotCount()
          : null,
      mapGlobalToLocalSlot: seamlessEnabled
          ? seamlessCubit.mapGlobalToLocalSlot
          : null,
      mapLocalToGlobalSlot: seamlessEnabled
          ? seamlessCubit.mapLocalToGlobalSlot
          : null,
      isTransitionSlot: seamlessEnabled
          ? (globalSlot) =>
                seamlessCubit.isTransitionSlot(globalSlot, readSetting)
          : null,
    );

    return BottomWidget(
      type: _type,
      comicInfo: comicInfo,
      sliderWidget: slider,
      order: widget.order,
      epsNumber: widget.epsNumber,
      comicId: comicId,
      from: widget.from,
      jumpChapter: _jumpChapter,
      onLandscapeChanged: _setReaderLandscape,
    );
  }
}
