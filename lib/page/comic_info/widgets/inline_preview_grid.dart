// lib/page/comic_info/widgets/inline_preview_grid.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_info/models/preview_prefs.dart';
import 'package:zephyr/page/comic_info/widgets/full_image_viewer.dart';
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

/// 内嵌预览图网格。
///
/// 走和阅读器相同的图片管线：PageBloc 取章节 docs → PictureBloc 分片还原
/// → 本地文件 → Image.file。
///
/// ★ 自动展开策略（防 GPU OOM + 无需手动点击）：
///   1. 首屏只 build 前 `_initialVisibleCount` 个 tile，避免一次向 GPU
///      申请上百个纹理导致 Adreno kgsl_sharedmem_alloc 失败。
///   2. 之后通过 `_autoExpandTimer` 每 `_autoExpandInterval` 自动 +N 张，
///      直到把用户选择的范围全部填满。
///   3. 每次展开前主动清一次 ImageCache，给新一批纹理腾空间。
///   4. 每个 tile 用 cacheWidth 限制解码尺寸（缩略图 ~1.2MB vs 原图 ~8MB）。
class InlinePreviewGrid extends StatefulWidget {
  const InlinePreviewGrid({
    super.key,
    required this.comicId,
    required this.from,
    required this.type,
    required this.comicInfo,
    required this.firstEp,
    this.mode = PreviewMode.top,
    this.count = 20,
    this.startPage = 1,
    this.endPage = 20,
    this.onTotalResolved,
  });

  final String comicId;
  final String from;
  final ComicEntryType type;
  final dynamic comicInfo;
  final dynamic firstEp;

  final PreviewMode mode;
  final int count;

  /// 起止范围（1-indexed，闭区间）。
  final int startPage;
  final int endPage;

  final ValueChanged<int>? onTotalResolved;

  @override
  State<InlinePreviewGrid> createState() => _InlinePreviewGridState();
}

class _InlinePreviewGridState extends State<InlinePreviewGrid> {
  int _lastReportedTotal = -1;

  // 分批展开的窗口参数
  static const int _initialVisibleCount = 12;
  static const int _loadMoreStep = 12;
  static const Duration _autoExpandInterval = Duration(milliseconds: 300);

  int _visibleCount = _initialVisibleCount;
  int _targetLength = 0;
  Timer? _autoExpandTimer;

  @override
  void didUpdateWidget(covariant InlinePreviewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 模式 / 范围变化时重置窗口，让用户看到最新设置的首屏。
    if (oldWidget.mode != widget.mode ||
        oldWidget.count != widget.count ||
        oldWidget.startPage != widget.startPage ||
        oldWidget.endPage != widget.endPage) {
      _autoExpandTimer?.cancel();
      _autoExpandTimer = null;
      _visibleCount = _initialVisibleCount;
    }
  }

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstEp = widget.firstEp;
    if (firstEp == null) return _buildGrid(context, const <Doc>[]);

    final dynamic ep = firstEp;
    final int epsId = _asInt(_tryRead(ep, 'order'), 0);
    final String chapterId = _asString(_tryRead(ep, 'id'), '');
    final dynamic rawExtern = _tryRead(ep, 'extern');
    final Map<String, dynamic> epExtern = rawExtern is Map
        ? Map<String, dynamic>.from(rawExtern)
        : const <String, dynamic>{};
    final String requestId = _asString(epExtern['requestId'], '');
    final String storageChapterId = _asString(epExtern['storageChapterId'], '');
    final String logicalKey = _asString(epExtern['logicalKey'], '');
    final ChapterExtern chapterExtern =
        (epExtern['chapterExtern'] as ChapterExtern?) ??
        const <String, dynamic>{};

    return BlocProvider(
      key: ValueKey('inline-preview:${widget.from}:${widget.comicId}'),
      create: (_) {
        return PageBloc()..add(
          PageEvent(
            widget.comicId,
            epsId,
            chapterId,
            requestId,
            storageChapterId,
            logicalKey,
            chapterExtern,
            widget.from,
            widget.type,
            comicInfo: widget.comicInfo,
          ),
        );
      },
      child: BlocBuilder<PageBloc, PageState>(
        builder: (context, state) {
          switch (state.status) {
            case PageStatus.initial:
            case PageStatus.failure:
              return _buildGrid(context, const <Doc>[]);
            case PageStatus.success:
              final docs = state.epInfo?.docs ?? const <Doc>[];
              _maybeReportTotal(docs.length);
              return _buildGrid(context, docs);
          }
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // 自动展开调度
  // ──────────────────────────────────────────────────────────────────

  /// 启动 / 继续自动展开。
  ///
  /// - `_targetLength` 是当前 sliced 的总长度（用户所选范围）；
  /// - 每 `_autoExpandInterval` 展开一批，直到 `_visibleCount >= target`；
  /// - 展开前清一次 ImageCache，避免连续分配导致 GPU OOM。
  void _scheduleAutoExpand(int target) {
    _targetLength = target;
    if (_visibleCount >= _targetLength) return;
    if (_autoExpandTimer?.isActive ?? false) return;

    _autoExpandTimer = Timer(_autoExpandInterval, () {
      if (!mounted) return;
      if (_visibleCount >= _targetLength) return;

      // 清掉已上传 GPU 的旧纹理，给即将出现的新 tile 腾空间。
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      setState(() {
        _visibleCount = (_visibleCount + _loadMoreStep).clamp(0, _targetLength);
      });

      // 还有剩余继续下一批。
      _scheduleAutoExpand(_targetLength);
    });
  }

  void _maybeReportTotal(int total) {
    if (total <= 0) return;
    if (_lastReportedTotal == total) return;
    _lastReportedTotal = total;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTotalResolved?.call(total);
    });
  }

  List<Doc> _sliceDocs(List<Doc> all) {
    if (all.isEmpty) return const <Doc>[];
    final total = all.length;
    switch (widget.mode) {
      case PreviewMode.top:
        final n = widget.count.clamp(1, total);
        return all.take(n).toList(growable: false);
      case PreviewMode.tail:
        final n = widget.count.clamp(1, total);
        return all.skip(total - n).toList(growable: false);
      case PreviewMode.range:
        final start = widget.startPage.clamp(1, total);
        final end = widget.endPage < start
            ? start
            : widget.endPage.clamp(start, total);
        return all.sublist(start - 1, end);
    }
  }

  String _buildInfoText(List<Doc> docs, List<Doc> sliced, bool hasData) {
    if (!hasData) return '正在加载章节数据…';
    final totalInChapter = docs.length;
    if (sliced.isEmpty) {
      return '所选范围超出本章页数（共 $totalInChapter 页）';
    }
    final base = switch (widget.mode) {
      PreviewMode.top => '前 ${sliced.length} 张 / 共 $totalInChapter 页',
      PreviewMode.tail => '后 ${sliced.length} 张 / 共 $totalInChapter 页',
      PreviewMode.range => () {
        final first = _displayIndex(sliced.first, docs) + 1;
        final last = _displayIndex(sliced.last, docs) + 1;
        return '第 $first-$last 页 / 共 $totalInChapter 页';
      }(),
    };
    // 仍在自动加载时附加提示。
    if (_visibleCount < sliced.length) {
      return '$base　·　自动加载中 ${_visibleCount}/${sliced.length}';
    }
    return base;
  }

  Widget _buildGrid(BuildContext context, List<Doc> docs) {
    final hasData = docs.isNotEmpty;
    final sliced = _sliceDocs(docs);

    // 自动展开调度：让 state 变化经 postFrame 通知，避免 build 期间副作用。
    if (sliced.length > _visibleCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleAutoExpand(sliced.length);
      });
    }

    final effectiveVisible = sliced.length <= _visibleCount
        ? sliced.length
        : _visibleCount;
    final visibleSliced = sliced.take(effectiveVisible).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
        const spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
            crossAxisCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 14,
                    color: context.textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _buildInfoText(docs, sliced, hasData),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  // 全部展开完成后的小提示，避免用户以为还在加载。
                  if (hasData &&
                      sliced.isNotEmpty &&
                      _visibleCount >= sliced.length)
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: context.textColor.withValues(alpha: 0.35),
                    ),
                ],
              ),
            ),
            if (!hasData || sliced.isEmpty)
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (int i = 0; i < _placeholderCount(); i++)
                    SizedBox(
                      width: tileWidth,
                      child: const PreviewPlaceholderTile(),
                    ),
                ],
              )
            else
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (int i = 0; i < visibleSliced.length; i++)
                    SizedBox(
                      width: tileWidth,
                      child: PreviewTile(
                        key: ValueKey(
                          '${visibleSliced[i].storageChapterId}|${visibleSliced[i].fileServer}|${visibleSliced[i].path}',
                        ),
                        doc: visibleSliced[i],
                        comicId: widget.comicId,
                        from: widget.from,
                        onTap: () => _openFullViewer(sliced, i),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  void _openFullViewer(List<Doc> sliced, int initialIndex) {
    if (sliced.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullImageViewer(
          docs: sliced,
          initialIndex: initialIndex.clamp(0, sliced.length - 1),
          comicId: widget.comicId,
          from: widget.from,
        ),
      ),
    );
  }

  int _placeholderCount() {
    int want;
    switch (widget.mode) {
      case PreviewMode.top:
      case PreviewMode.tail:
        want = widget.count;
        break;
      case PreviewMode.range:
        want = widget.endPage - widget.startPage + 1;
        break;
    }
    if (want <= 0) return 4;
    return want.clamp(1, 20);
  }

  int _displayIndex(Doc doc, List<Doc> all) {
    final idx = all.indexOf(doc);
    return idx < 0 ? 0 : idx;
  }

  static dynamic _tryRead(dynamic target, String name) {
    try {
      switch (name) {
        case 'order':
          return target.order;
        case 'id':
          return target.id;
        case 'extern':
          return target.extern;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static String _asString(dynamic v, String fallback) {
    if (v is String) return v;
    return fallback;
  }
}

/// 单张预览图（网格里的缩略图）。
class PreviewTile extends StatelessWidget {
  const PreviewTile({
    super.key,
    required this.doc,
    required this.comicId,
    required this.from,
    this.onTap,
  });

  final Doc doc;
  final String comicId;
  final String from;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedChapterId = doc.storageChapterId.trim().isNotEmpty
        ? doc.storageChapterId
        : comicId;

    final pictureInfo = PictureInfo(
      from: from,
      url: doc.fileServer,
      path: doc.path,
      cartoonId: comicId,
      chapterId: resolvedChapterId,
      pictureType: PictureType.page,
      extern: doc.extern,
    );

    return BlocProvider(
      create: (_) => PictureBloc()..add(GetPicture(pictureInfo)),
      child: BlocBuilder<PictureBloc, PictureLoadState>(
        builder: (context, state) {
          Widget content;
          switch (state.status) {
            case PictureLoadStatus.initial:
            case PictureLoadStatus.failure:
              content = const PreviewPlaceholderTile();
              break;
            case PictureLoadStatus.success:
              final imagePath = state.imagePath;
              if (imagePath == null || imagePath.isEmpty) {
                content = const PreviewPlaceholderTile();
              } else {
                // 缩略图用 cacheWidth 限制解码尺寸。
                final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
                final cacheWidth = (180 * dpr).round();
                content = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.fitWidth,
                    cacheWidth: cacheWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        const PreviewPlaceholderTile(),
                  ),
                );
              }
              break;
          }

          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          );
        },
      ),
    );
  }
}

/// 预览图占位块。用固定 AspectRatio 避免加载前布局塌陷。
class PreviewPlaceholderTile extends StatelessWidget {
  const PreviewPlaceholderTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AspectRatio(
      aspectRatio: 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 28,
            color: context.textColor.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
