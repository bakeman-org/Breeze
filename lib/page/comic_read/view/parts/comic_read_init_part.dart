part of '../comic_read.dart';

extension _ComicReadInitPart on _ComicReadPageState {
  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  void _initInputController() {
    _inputController = ReaderInputController(
      context: context,
      readerCubit: context.read<ReaderCubit>(),
      pageController: _pageController,
      transformationController: _transformationController,
      onToggleMenu: _toggleVisibility,
      onToggleDesktopFullscreen: _lifecycleController.toggleDesktopFullscreen,
      onRefreshState: () => _refreshState(() {}),
      isScrollLockedByMultiTouch: () => _isScrollLockedByMultiTouch,
      onUpdateScrollLock: (locked) {
        _refreshState(() {
          _isScrollLockedByMultiTouch = locked;
        });
      },
      buildColumnMode: (enableDoublePage) =>
          _columnModeWidget(enableDoublePage: enableDoublePage),
      buildRowMode: () => _rowModeWidget(),
    );
  }

  void _initActionController() {
    _actionController = ReaderActionController(
      context: context,
      pageController: _pageController,
      onBeforeTurnPage: _inputController.restoreScaleBeforeTurnPage,
      isUserScrolling: () => _isUserScrollActive,
    );
  }

  void _initAutoReadController() {
    _autoReadController = ReaderAutoReadController();
  }

  void _initSystemUiController() {
    _systemUiController = ReaderSystemUiController();
  }

  void _initVolumeController() {
    _volumeController = ReaderVolumeController();
    _volumeController.listen();
  }

  void _setVolumeControllerAction() {
    _volumeController.setActionController(_actionController);
  }

  void _initVolumeKeyPageTurnSubscription() {
    _volumeKeyPageTurnSubscription = context
        .read<GlobalSettingCubit>()
        .stream
        .map((state) => state.readSetting.volumeKeyPageTurn)
        .distinct()
        .listen((_) {
          if (!mounted) return;
          _syncVolumeInterception();
        });
  }

  void _initHistoryController() {
    final globalSettingCubit = context.read<GlobalSettingCubit>();
    final readerCubit = context.read<ReaderCubit>();
    final seamlessCubit = context.read<ReaderSeamlessCubit>();

    _historyController = ReaderHistoryController(
      comicId: comicId,
      order: widget.order,
      from: widget.from,
      comicInfo: widget.comicInfo,
      stringSelectCubit: context.read<StringSelectCubit>(),
      getStoredPageIndex: () {
        final setting = globalSettingCubit.state.readSetting;
        final globalSlotIndex = readerCubit.state.currentSlot;
        final slotIndex = seamlessCubit.isSeamlessEnabled()
            ? seamlessCubit.mapGlobalToLocalSlot(globalSlotIndex)
            : globalSlotIndex;
        final enableDoublePage = setting.doublePageMode;
        return getStoredHistoryPageIndex(
          slotIndex: slotIndex,
          enableDoublePage: enableDoublePage,
          insertLeadingBlank:
              enableDoublePage && setting.doublePageLeadingBlank,
        );
      },
      getCurrentChapterOrder: () => _jumpChapter.order,
      getEpInfo: () => epInfo,
      isHistoryEntry: () => _isHistory,
      jumpToGlobalSlot: (target) => _jumpToGlobalSlot(target),
    );

    unawaited(_historyController.init());
  }

  void _initLifecycleController() {
    _lifecycleController = ReaderLifecycleController(
      context: context,
      readerCubit: context.read<ReaderCubit>(),
      systemUiController: _systemUiController,
      volumeController: _volumeController,
      autoReadController: _autoReadController,
      historyController: _historyController,
      onRefreshState: () => _refreshState(() {}),
      onSyncSystemUi: ({force = false}) => _syncSystemUi(force: force),
      onFlushImageSizeCache: () {
        final imageContext = _imageSizeContext;
        if (imageContext != null && imageContext.mounted) {
          unawaited(imageContext.read<ImageSizeCubit>().flushNow());
        }
      },
      isDesktopPlatform: () => _isDesktopPlatform,
    );
  }

  void _syncJumpChapterState({required int order}) {
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final ref = seamlessCubit.chapterRefByOrder(order);
    final chapter = seamlessCubit.state.loadedChapters.firstWhere(
      (item) => item.order == order,
      orElse: () => seamlessCubit.state.loadedChapters.first,
    );
    if (ref != null) {
      _jumpChapter.order = order;
      _jumpChapter.chapterId = ref.id;
      _jumpChapter.requestId = ref.requestId;
      _jumpChapter.storageChapterId = ref.storageChapterId;
      _jumpChapter.logicalKey = ref.logicalKey;
      _jumpChapter.chapterExtern = Map<String, dynamic>.from(ref.extern);
      final index = seamlessCubit.catalogIndexByOrder(order);
      _jumpChapter.havePrev = index > 0;
      _jumpChapter.haveNext = index < seamlessCubit.catalogLength - 1;
    }
    epInfo = chapter.epInfo;
  }

  void _initJumpChapter(bool isMenuVisible) {
    _jumpChapter = JumpChapter.create(
      _type,
      isMenuVisible,
      comicInfo,
      widget.order,
      widget.chapterId,
      widget.requestId,
      widget.storageChapterId,
      widget.logicalKey,
      Map<String, dynamic>.from(widget.chapterExtern),
      widget.epsNumber,
      comicId,
      widget.from,
    );
  }
}
