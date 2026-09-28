// lib/service/translation/translation_image_renderer.dart
// 渲染译文到原图并落盘为 PNG：白底圆角气泡 + 黑字（漫画通行做法）。
// 同目录 .translated/ 下存 PNG + JSON（blocks 缓存，供编辑器加载）。

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/translation/text_fit_painter.dart';
import 'package:zephyr/service/translation/translation_service.dart';

class TranslationImageRenderer {
  TranslationImageRenderer._();

  /// 将 [blocks] 渲染到 [imagePath] 指向的原图上，保存为
  /// `<原目录>/.translated/<原名>.png`；同时写 blocks JSON。
  /// 返回 PNG 路径，失败返回 null。
  static Future<String?> render({
    required String imagePath,
    required List<TranslatedBlock> blocks,
  }) async {
    if (blocks.isEmpty) return null;

    final srcFile = File(imagePath);
    if (!await srcFile.exists()) return null;

    final bytes = await srcFile.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    if (width == 0 || height == 0) {
      buffer.dispose();
      return null;
    }

    final codec = await descriptor.instantiateCodec();
    ui.FrameInfo frameInfo;
    try {
      frameInfo = await codec.getNextFrame();
    } finally {
      codec.dispose();
    }
    final origImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(origImage, Offset.zero, Paint());

    for (final block in blocks) {
      final rect = Rect.fromLTWH(
        block.rect.left * width,
        block.rect.top * height,
        block.rect.width * width,
        block.rect.height * height,
      );
      if (rect.isEmpty) continue;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(2)),
        Paint()..color = Colors.white,
      );
      drawFittedText(canvas, rect, block.translated, color: Colors.black);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final pngByteData = await image.toByteData(format: ui.ImageByteFormat.png);

    origImage.dispose();
    image.dispose();

    if (pngByteData == null) return null;
    final pngBytes = pngByteData.buffer.asUint8List();

    final outPath = translatedPathFor(imagePath);
    await DownloadAssetStore.writeBytesAtomically(pngBytes, finalPath: outPath);
    return outPath;
  }

  // ── 路径解析 ───────────────────────────────────────────────────

  /// `<原目录>/.translated/<原名>.png`。
  static String translatedPathFor(String imagePath) {
    final dir = p.dirname(imagePath);
    final base = p.basenameWithoutExtension(imagePath);
    return p.join(dir, '.translated', '$base.png');
  }

  /// `<原目录>/.translated/<原名>.json`。
  static String blocksJsonPathFor(String imagePath) {
    final dir = p.dirname(imagePath);
    final base = p.basenameWithoutExtension(imagePath);
    return p.join(dir, '.translated', '$base.json');
  }

  // ── blocks JSON 缓存 ───────────────────────────────────────────

  static Future<void> saveBlocksJson(
    String imagePath,
    List<TranslatedBlock> blocks,
  ) async {
    final path = blocksJsonPathFor(imagePath);
    await DownloadAssetStore.ensureParentDirectory(path);
    final json = jsonEncode(
      blocks
          .map(
            (b) => {
              'left': b.rect.left,
              'top': b.rect.top,
              'width': b.rect.width,
              'height': b.rect.height,
              'original': b.original,
              'translated': b.translated,
            },
          )
          .toList(),
    );
    await File(path).writeAsString(json);
  }

  static Future<List<TranslatedBlock>?> loadBlocks(String imagePath) async {
    final file = File(blocksJsonPathFor(imagePath));
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return null;
      return [
        for (final item in data)
          if (item is Map)
            TranslatedBlock(
              rect: Rect.fromLTWH(
                (item['left'] as num).toDouble(),
                (item['top'] as num).toDouble(),
                (item['width'] as num).toDouble(),
                (item['height'] as num).toDouble(),
              ),
              original: (item['original'] as String?) ?? '',
              translated: (item['translated'] as String?) ?? '',
            ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// 译文 PNG 是否已存在。
  static Future<bool> hasTranslated(String imagePath) async {
    return await File(translatedPathFor(imagePath)).exists();
  }
}
