//lib/page/comic_read/view/comic_read.dart
import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/comic_read.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_state.dart';
import 'package:zephyr/page/comic_read/controller/reader_image_prefetch_controller.dart';
import 'package:zephyr/page/comic_read/controller/reader_orientation_controller.dart';
import 'package:zephyr/page/comic_read/cubit/reader_state.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/draggable_fab_group.dart';

part 'parts/comic_read_auto_read_part.dart';
part 'parts/comic_read_init_part.dart';
part 'parts/comic_read_interaction_part.dart';
part 'parts/comic_read_system_ui_part.dart';
part 'parts/comic_read_view_part.dart';

@RoutePage()
class ComicReadPage extends StatelessWidget {
  final String comicId;
  final int order;
  final String chapterId;
  final String requestId;
  final String storageChapterId;
  final String logicalKey;
  final ChapterExtern chapterExtern;
  final int epsNumber;
  final String from;
  final ComicEntryType type;
  final dynamic comicInfo;
  final StringSelectCubit stringSelectCubit;

  const ComicReadPage({
    super.key,
    required this.comicId,
    required this.order,
    this.chapterId = '',
    this.requestId = '',
    this.storageChapterId = '',
    this.logicalKey = '',
    this.chapterExtern = const <String, dynamic>{},
    required this.epsNumber,
    required this.from,
    required this.stringSelectCubit,
    required this.type,
    required this.comicInfo,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => PageBloc()
            ..add(
              PageEvent(
                comicId,
                order,
                chapterId,
                requestId,
                storageChapterId,
                logicalKey,
                chapterExtern,
                from,
                type,
                comicInfo: comicInfo,
              ),
            ),
        ),
        BlocProvider.value(value: stringSelectCubit),
        BlocProvider(create: (_) => ReaderCubit()),
        BlocProvider(
          create: (_) => ReaderSeamlessCubit(
            comicId: comicId,
            from: from,
            type: type,
            comicInfo: comicInfo,
            initialOrder: order,
          ),
        ),
      ],
      child: _ComicReadPage(
        comicId: comicId,
        order: order,
        chapterId: chapterId,
        requestId: requestId,
        storageChapterId: storageChapterId,
        logicalKey: logicalKey,
        chapterExtern: chapterExtern,
        epsNumber: epsNumber,
        from: from,
        type: type,
        comicInfo: comicInfo,
      ),
    );
  }
}

class _ComicReadPage extends StatefulWidget {
  final String comicId;
  final int order;
  final String chapterId;
  final String requestId;
  final String storageChapterId;
  final String logicalKey;
  final ChapterExtern chapterExtern;
  final int epsNumber;
  final String from;
  final ComicEntryType type;
  final dynamic comicInfo;

  const _ComicReadPage({
    required this.comicId,
    required this.order,
    this.chapterId = '',
    this.requestId = '',
    this.storageChapterId = '',
    this.logicalKey = '',
    this.chapterExtern = const <String, dynamic>{},
    required this.epsNumber,
    required this.from,
    required this.type,
    required this.comicInfo,
  });

  @override
  State<_ComicReadPage> createState() => _ComicReadPageState();
}

class _ComicReadPageState extends State<_ComicReadPage>
    with WidgetsBindingObserver {
  dynamic get comicInfo => widget.comicInfo;
  String get comicId => widget.comicId;

  late final ComicEntryType _type;
  late bool isSkipped = false;
  final _pageController = PageController(initialPage: 0);

  /// 列模式的按索引滚动控制器。跳页直接 `jumpTo(index)`，O(1)。
  final _itemScrollController = ItemScrollController();

  /// 列模式的可见项监听器。取代原 ListViewObserver 的 onObserve。
  final _itemPositionsListener = ItemPositionsListener.create();

  late JumpChapter _jumpChapter;
  late final ReaderActionController _actionController;
  late final ReaderVolumeController _volumeController;
  late final ReaderHistoryController _historyController;
  late final ReaderAutoReadController _autoReadController;
  late final ReaderSystemUiController _systemUiController;
  late final ReaderLifecycleController _lifecycleController;
  late final ReaderOrientationController _orientationController;
  late final ReaderInputController _inputController;
  final _imagePrefetchController = ReaderImagePrefetchController();
  NormalComicEpInfo epInfo = NormalComicEpInfo();
  NormalComicEpInfo _initialEpInfo = NormalComicEpInfo();
  BuildContext? _imageSizeContext;
  final TransformationController _transformationController =
      TransformationController();
  StreamSubscription<bool>? _volumeKeyPageTurnSubscription;
  bool _isScrollLockedByMultiTouch = false;
  bool _isUserScrollActive = false;

  bool get _isHistory =>
      _type == ComicEntryType.history ||
      _type == ComicEntryType.historyAndDownload;

  @override
  void initState() {
    super.initState();
    _type = widget.type;

    _initAutoReadController();
    _initSystemUiController();
    _initHistoryController();
    _initVolumeController();
    _initLifecycleController();
    _orientationController = ReaderOrientationController();
    _initInputController();
    _initActionController();
    _setVolumeControllerAction();
    _inputController.setActionController(_actionController);
    _inputController.init();
    _initVolumeKeyPageTurnSubscription();

    WidgetsBinding.instance.addObserver(this);
    _lifecycleController.init();
    unawaited(
      _orientationController.setLandscape(
        context.read<GlobalSettingCubit>().state.readSetting.landscapeReader,
      ),
    );
    _initJumpChapter(context.read<ReaderCubit>().state.isMenuVisible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_lifecycleController.dispose());
    _volumeKeyPageTurnSubscription?.cancel();
    _inputController.dispose();
    _imagePrefetchController.dispose();
    _volumeController.dispose();
    _pageController.dispose();
    _transformationController.dispose();
    unawaited(_orientationController.restorePortrait());
    super.dispose();
  }

  void _setReaderLandscape(bool enabled) {
    unawaited(_orientationController.setLandscape(enabled));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BlocListener<ReaderSeamlessCubit, ReaderSeamlessState>(
      listener: (context, seamlessState) {
        final order = seamlessState.currentChapterOrder;
        if (order != null && order != _jumpChapter.order) {
          _syncJumpChapterState(order: order);
        }
        setState(() {});
      },
      child: BlocBuilder<PageBloc, PageState>(
        builder: (context, state) {
          switch (state.status) {
            case PageStatus.initial:
              return const Center(child: CircularProgressIndicator());
            case PageStatus.failure:
              return ComicErrorWidget(
                state: state,
                event: PageEvent(
                  comicId,
                  widget.order,
                  widget.chapterId,
                  widget.requestId,
                  widget.storageChapterId,
                  widget.logicalKey,
                  widget.chapterExtern,
                  widget.from,
                  widget.type,
                  comicInfo: comicInfo,
                ),
              );
            case PageStatus.success:
              if (!_lifecycleController.hasBootstrappedReadState) {
                _lifecycleController.markReadStateBootstrapped();
                epInfo = state.epInfo!;
                _initialEpInfo = state.epInfo!;
                final readSetting = context
                    .read<GlobalSettingCubit>()
                    .state
                    .readSetting;
                final seamlessCubit = context.read<ReaderSeamlessCubit>();
                seamlessCubit.bootstrap(epInfo, widget.order, readSetting);

                // ★ 立刻预取首章前 N 张图片：
                //   不等 ComicReadSuccessWidget 搭好、不等尺寸缓存读完，
                //   把「PageBloc 返回」到「网络拉图」之间的等待窗口清零。
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _prefetchImagesAroundSlot(0, readSetting);
                });
              }
              return ComicReadSuccessWidget(
                comicId: comicId,
                from: widget.from,
                epInfo: _initialEpInfo,
                chapterOrder: widget.order,
                resolveTotalSlots: (readSetting) => context
                    .read<ReaderSeamlessCubit>()
                    .resolveTotalSlots(readSetting),
                buildInteractiveViewer: (_) =>
                    _inputController.buildInteractiveViewer(),
                buildPageCount: (_) => _pageCountWidget(),
                buildAppBar: (_) => _comicReadAppBar(),
                buildBottom: (innerContext) => _bottomWidget(innerContext),
                buildAutoReadControl: (_) => _autoReadControlWidget(),
                onReady: (innerContext, readSetting, readMode) {
                  _syncAutoRead(readSetting: readSetting, readMode: readMode);
                  _prefetchImagesAroundSlot(
                    context.read<ReaderCubit>().state.currentSlot,
                    readSetting,
                  );
                  _imageSizeContext = innerContext;
                  _historyController.markLoaded();
                  unawaited(
                    _historyController.handleHistoryScroll(innerContext),
                  );
                },
              );
          }
        },
      ),
    ),
  );

  @override
  void didChangeMetrics() {
    _lifecycleController.didChangeMetrics();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleController.didChangeAppLifecycleState(state);
  }

  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  /// 跳到目标全局槽位。
  ///
  /// 列模式：直接 `itemScrollController.jumpTo(index: safeTarget)`——
  /// 按索引定位，一步到位，不依赖高度估算。中间项不会被构建。
  ///
  /// 行模式：`pageController.jumpToPage(safeTarget)`（原逻辑）。
  Future<void> _jumpToGlobalSlot(
    int targetGlobalSlot, {
    int prependedSlotCount = 0,
  }) async {
    if (!mounted) return;
    final cubit = context.read<ReaderCubit>();
    final readSetting = context.read<GlobalSettingCubit>().state.readSetting;
    final seamlessCubit = context.read<ReaderSeamlessCubit>();
    final totalSlots = seamlessCubit.resolveTotalSlots(readSetting);
    final maxSlot = (totalSlots - 1).clamp(0, 999999999);
    final safeTarget = targetGlobalSlot.clamp(0, maxSlot);
    cubit.updateCurrentSlot(safeTarget);
    cubit.updateSliderChanged(safeTarget.toDouble());
    seamlessCubit.applyCurrentChapterByGlobalSlot(safeTarget, readSetting);

    final readMode = readSetting.readMode;
    if (isColumnReadMode(readMode)) {
      if (!_itemScrollController.isAttached) return;
      // ★ 关键：按 index 跳，语义等同于 Compose 的 scrollToItem。
      _itemScrollController.jumpTo(index: safeTarget, alignment: 0);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(safeTarget);
      }
    });
  }
}
