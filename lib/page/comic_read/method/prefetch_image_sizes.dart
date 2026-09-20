// lib/page/comic_read/method/prefetch_image_sizes.dart
import 'package:flutter/widgets.dart' show Size;
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/method/image_header_size.dart';
import 'package:zephyr/page/comic_read/widgets/layout/read_layout.dart';
import 'package:zephyr/type/enum.dart';

/// 后台预解析章节图片尺寸并写入 [ImageSizeCubit]。
///
/// 列表项在图片加载前使用默认占位高度，图片解析出真实尺寸后高度突变会
/// 造成可见的布局跳动（自动平滑滚动时尤其明显）。本函数只解析**已存在
/// 于本地**（缓存/下载目录）的图片文件头尺寸，未下载的图片直接跳过，
/// 不触发任何网络请求。
///
/// ★ 优化点：
///   1. `maxCount` 限制扫描范围，避免整章几百张顺序扫；
///   2. `concurrency` 分批并发读文件头，减少与首屏图片抢 IO 的时间。
Future<void> prefetchChapterImageSizes({
  required ImageSizeCubit imageSizeCubit,
  required List<Doc> docs,
  required String comicId,
  required String from,
  required String chapterId,
  required int chapterOrder,
  required double contentWidth,
  int maxCount = 30,
  int concurrency = 4,
}) async {
  if (docs.isEmpty || imageSizeCubit.isClosed) return;

  // 收集需要解析的索引（只取前 maxCount 张未缓存的）。
  final targets = <int>[];
  for (var i = 0; i < docs.length && targets.length < maxCount; i++) {
    final cacheIndex = resolveStableSizeCacheIndex(
      chapterOrder: chapterOrder,
      localPageIndex: i,
    );
    if (imageSizeCubit.getSize(cacheIndex).isCached) continue;
    targets.add(i);
  }
  if (targets.isEmpty) return;

  // 分批并发，每批 concurrency 张。
  for (var start = 0; start < targets.length; start += concurrency) {
    if (imageSizeCubit.isClosed) return;
    final end = (start + concurrency).clamp(0, targets.length);
    await Future.wait(
      targets
          .sublist(start, end)
          .map(
            (i) => _resolveOne(
              imageSizeCubit: imageSizeCubit,
              doc: docs[i],
              index: i,
              chapterOrder: chapterOrder,
              contentWidth: contentWidth,
              comicId: comicId,
              from: from,
              chapterId: chapterId,
            ),
          ),
    );
  }
}

Future<void> _resolveOne({
  required ImageSizeCubit imageSizeCubit,
  required Doc doc,
  required int index,
  required int chapterOrder,
  required double contentWidth,
  required String comicId,
  required String from,
  required String chapterId,
}) async {
  try {
    final storageChapterId = doc.storageChapterId.trim();
    final filePath = await findCachedPicturePath(
      from: from,
      path: doc.path,
      cartoonId: comicId,
      chapterId: chapterId,
      storageChapterId: storageChapterId,
      pictureType: PictureType.page,
    );
    if (filePath.isEmpty) return;
    if (imageSizeCubit.isClosed) return;

    final rawSize = await readImageHeaderSize(filePath);
    if (rawSize == null || rawSize.width <= 0 || rawSize.height <= 0) return;
    if (imageSizeCubit.isClosed) return;

    final cacheIndex = resolveStableSizeCacheIndex(
      chapterOrder: chapterOrder,
      localPageIndex: index,
    );
    final displayHeight = contentWidth * (rawSize.height / rawSize.width);
    imageSizeCubit.updateSize(cacheIndex, Size(contentWidth, displayHeight));
  } catch (_) {
    // 单张失败不影响其余图片。
  }
}
