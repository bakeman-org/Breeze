// lib/page/comic_read/widgets/success/comic_read_success_widget.dart
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_seamless_state.dart';
import 'package:zephyr/page/comic_read/method/prefetch_image_sizes.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/util/context/context_extensions.dart';

class ComicReadSuccessWidget extends StatefulWidget {
  final String comicId;
  final String from;
  final NormalComicEpInfo epInfo;
  final int chapterOrder;
  final WidgetBuilder buildInteractiveViewer;
  final WidgetBuilder buildPageCount;
  final WidgetBuilder buildAppBar;
  final WidgetBuilder buildBottom;
  final WidgetBuilder buildAutoReadControl;
  final int Function(ReadSettingState readSetting)? resolveTotalSlots;
  final void Function(
    BuildContext innerContext,
    ReadSettingState readSetting,
    int readMode,
  )
  onReady;

  const ComicReadSuccessWidget({
    super.key,
    required this.comicId,
    required this.from,
    required this.epInfo,
    required this.chapterOrder,
    required this.buildInteractiveViewer,
    required this.buildPageCount,
    required this.buildAppBar,
    required this.buildBottom,
    required this.buildAutoReadControl,
    this.resolveTotalSlots,
    required this.onReady,
  });

  @override
  State<ComicReadSuccessWidget> createState() => _ComicReadSuccessWidgetState();
}

class _ComicReadSuccessWidgetState extends State<ComicReadSuccessWidget> {
  late final List<String> _pageKeys;
  bool _initialPrefetchStarted = false;

  @override
  void initState() {
    super.initState();
    _pageKeys = _buildPageKeys();
  }

  @override
  Widget build(BuildContext context) {
    final width = context.screenWidth;

    // ★ 关键改动：不再用 FutureBuilder 等尺寸缓存。
    // persistedCache 传 null → ImageSizeCubit 走 hydrateOnInit: true，
    // 先在内存里用 _kDefaultAspect (1.42) 兜底，读到磁盘后 emit 新 state，
    // BlocSelector 自动重绘，用户无感知。
    return BlocProvider(
      create: (_) => ImageSizeCubit.create(
        defaultWidth: width,
        count: widget.epInfo.length,
        sourceTag: widget.from,
        pageKeys: _pageKeys,
        chapterOrder: widget.chapterOrder,
        persistedCache: null,
      ),
      child: Builder(
        builder: (innerContext) {
          _scheduleInitialPrefetch(innerContext);
          final cubit = innerContext.read<ReaderCubit>();
          final readMode = innerContext.select(
            (GlobalSettingCubit c) => c.state.readSetting.readMode,
          );
          final readSetting = innerContext.select(
            (GlobalSettingCubit c) => c.state.readSetting,
          );
          final backgroundColor = readSetting.resolveReaderBackgroundColor(
            Theme.of(innerContext).brightness,
          );
          final isDarkMode =
              Theme.of(innerContext).brightness == Brightness.dark;
          final filterOpacityPercent = readSetting.readFilterOpacityPercent
              .clamp(0, 100)
              .toDouble();
          final enableReaderFilter =
              isDarkMode &&
              readSetting.readFilterEnabled &&
              filterOpacityPercent > 0;

          final totalSlots = getReadModeSlotCount(
            imageCount: widget.epInfo.length,
            enableDoublePage: readSetting.doublePageMode,
            insertLeadingBlank:
                readSetting.doublePageMode &&
                readSetting.doublePageLeadingBlank,
          );
          final resolvedTotalSlots =
              widget.resolveTotalSlots?.call(readSetting) ?? totalSlots;
          cubit.updateTotalSlots(resolvedTotalSlots);
          widget.onReady(innerContext, readSetting, readMode);

          return BlocListener<ReaderSeamlessCubit, ReaderSeamlessState>(
            listenWhen: (previous, current) =>
                previous.loadedChapters.length != current.loadedChapters.length,
            listener: _onSeamlessChaptersChanged,
            child: Container(
              color: backgroundColor,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.buildInteractiveViewer(innerContext),
                  ),
                  if (enableReaderFilter)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: Container(
                          color: Colors.black.withValues(
                            alpha: filterOpacityPercent / 100,
                          ),
                        ),
                      ),
                    ),
                  widget.buildPageCount(innerContext),
                  widget.buildAppBar(innerContext),
                  widget.buildBottom(innerContext),
                  widget.buildAutoReadControl(innerContext),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 章节就绪后在后台预解析本地图片尺寸，让列表项高度提前就位，
  // 减少阅读过程中占位高度 → 真实高度的布局跳变。
  //
  // ★ 注意：这里不再读 ImageSizeCubit 的当前状态做前置判断，
  //   prefetchChapterImageSizes 内部会对每张图独立判重，hydrate
  //   完成前后都能正确跳过已缓存项，无需额外协调。
  void _scheduleInitialPrefetch(BuildContext innerContext) {
    if (_initialPrefetchStarted) return;
    _initialPrefetchStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !innerContext.mounted) return;
      final readSetting = innerContext
          .read<GlobalSettingCubit>()
          .state
          .readSetting;
      unawaited(
        prefetchChapterImageSizes(
          imageSizeCubit: innerContext.read<ImageSizeCubit>(),
          docs: widget.epInfo.docs,
          comicId: widget.comicId,
          from: widget.from,
          chapterId: widget.epInfo.epId,
          chapterOrder: widget.chapterOrder,
          contentWidth: _resolveContentWidth(innerContext, readSetting),
        ),
      );
    });
  }

  // 无缝拼接加载出新章节时，同样预解析其图片尺寸。
  void _onSeamlessChaptersChanged(
    BuildContext context,
    ReaderSeamlessState state,
  ) {
    final imageSizeCubit = context.read<ImageSizeCubit>();
    final readSetting = context.read<GlobalSettingCubit>().state.readSetting;
    final contentWidth = _resolveContentWidth(context, readSetting);
    for (final chapter in state.loadedChapters) {
      unawaited(
        prefetchChapterImageSizes(
          imageSizeCubit: imageSizeCubit,
          docs: chapter.epInfo.docs,
          comicId: widget.comicId,
          from: widget.from,
          chapterId: chapter.epInfo.epId,
          chapterOrder: chapter.order,
          contentWidth: contentWidth,
        ),
      );
    }
  }

  double _resolveContentWidth(
    BuildContext context,
    ReadSettingState readSetting,
  ) {
    return getConstrainedImageWidth(
      containerWidth: context.screenWidth,
      enableSidePadding: readSetting.sidePaddingEnabled,
      sidePaddingPercent: readSetting.sidePaddingPercent,
    );
  }

  List<String> _buildPageKeys() {
    return List<String>.generate(widget.epInfo.length, (index) {
      if (index >= widget.epInfo.docs.length) {
        return '${widget.comicId}|${widget.epInfo.epId}|index_$index';
      }

      final doc = widget.epInfo.docs[index];
      final imageId = doc.id.isNotEmpty
          ? doc.id
          : (doc.originalName.isNotEmpty ? doc.originalName : doc.path);
      return '${widget.comicId}|${widget.epInfo.epId}|$imageId';
    }, growable: false);
  }
}
