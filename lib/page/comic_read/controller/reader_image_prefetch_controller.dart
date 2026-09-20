// lib/page/comic_read/controller/reader_image_prefetch_controller.dart
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/page/comic_read/widgets/modes/read_mode_utils.dart';
import 'package:zephyr/type/enum.dart';

/// 负责把当前阅读位置之后的图片提前写入图片缓存，并预热解码。
///
/// 两步：
///   1. `getCachePicture` — 网络 → 文件缓存（磁盘）；
///   2. `precacheImage`   — 文件 → ImageCache（解码后位图）。
///
/// 第二步与 `ImageDisplay` 用**相同的 `cacheWidth`**，命中同一缓存条目，
/// 显示时直接贴出，不再走解码路径。
class ReaderImagePrefetchController {
  final Set<String> _requestedKeys = <String>{};
  bool _disposed = false;

  Future<void> prefetch({
    required BuildContext context,
    required List<ReadModeEntry> entries,
    required String comicId,
    required String from,
    required int count,
    required double targetWidth,
  }) async {
    if (_disposed || count <= 0 || entries.isEmpty) return;

    // ★ 与 ImageDisplay 保持一致的解码宽度（物理像素）。
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (targetWidth * dpr).round();

    for (final entry in entries.take(count)) {
      if (_disposed) return;
      final doc = entry.doc;
      final chapterId = entry.chapterId;
      if (entry.type != ReadModeEntryType.image ||
          doc == null ||
          chapterId == null ||
          chapterId.isEmpty) {
        continue;
      }

      final storageChapterId = doc.storageChapterId.trim();
      final resolvedChapterId = storageChapterId.isNotEmpty
          ? storageChapterId
          : chapterId;
      final key = _buildKey(
        from: from,
        comicId: comicId,
        chapterId: resolvedChapterId,
        path: doc.path,
      );
      if (!_requestedKeys.add(key)) continue;

      try {
        final cachedPath = await getCachePicture(
          from: from,
          url: doc.fileServer,
          path: doc.path,
          cartoonId: comicId,
          chapterId: chapterId,
          storageChapterId: storageChapterId,
          pictureType: PictureType.page,
          extern: doc.extern,
        );
        if (cachedPath == '404' || cachedPath.isEmpty) {
          _requestedKeys.remove(key);
          continue;
        }

        // ★ 解码预热：把文件解码进 ImageCache。
        //   与 ImageDisplay 的 cacheWidth 相同 → 同一缓存 key → 命中即用。
        if (!_disposed && context.mounted) {
          try {
            await precacheImage(
              ResizeImage(FileImage(File(cachedPath)), width: cacheWidth),
              context,
            );
          } catch (_) {
            // 单张预热失败不影响其他。
          }
        }
      } catch (_) {
        _requestedKeys.remove(key);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _requestedKeys.clear();
  }

  String _buildKey({
    required String from,
    required String comicId,
    required String chapterId,
    required String path,
  }) => '$from|$comicId|$chapterId|$path';
}
