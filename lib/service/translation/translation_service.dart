// lib/service/translation/translation_service.dart
// 实验: 漫画翻译。OCR（ML Kit 中文识别）+ 在线翻译 API。
// 结果 rect 为归一化坐标（0-1），与显示尺寸解耦。

import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/service/translation/translation_api.dart';
import 'package:zephyr/widgets/toast.dart';

class TranslatedBlock {
  const TranslatedBlock({
    required this.rect,
    required this.original,
    required this.translated,
  });

  /// 归一化（0-1）文本框，乘以显示尺寸即得屏幕坐标。
  final Rect rect;
  final String original;
  final String translated;
}

class TranslationService {
  TranslationService._();

  /// ML Kit 仅支持 Android/iOS。
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// OCR + 逐块翻译。OCR 失败 / 无文字抛异常，调用方 toast。
  static Future<List<TranslatedBlock>> translateImage(String imagePath) async {
    final setting = globalSetting;
    final targetLang = setting.translationTargetLang;
    final provider = setting.translationProvider;
    final apiKey = setting.translationApiKey;

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception(t.translation.ocrFailed(error: 'file not found'));
    }

    final size = await _imageSize(file);
    final inputImage = InputImage.fromFilePath(imagePath);

    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    final RecognizedText recognized;
    try {
      recognized = await recognizer.processImage(inputImage);
    } finally {
      recognizer.close();
    }

    final entries = <(Rect, String)>[];
    for (final block in recognized.blocks) {
      final text = block.text.trim();
      if (text.isEmpty) continue;
      final box = block.boundingBox;
      final rect = Rect.fromLTWH(
        box.left / size.width,
        box.top / size.height,
        box.width / size.width,
        box.height / size.height,
      );
      entries.add((rect, text));
    }
    if (entries.isEmpty) {
      throw Exception(t.translation.noTextFound);
    }

    // 并发 4 逐块翻译。
    final translated = List<String>.filled(entries.length, '');
    for (var i = 0; i < entries.length; i += 4) {
      final end = (i + 4).clamp(0, entries.length);
      final chunk = <Future<String>>[
        for (var j = i; j < end; j++)
          TranslationApi.translate(
            text: entries[j].$2,
            provider: provider,
            apiKey: apiKey,
            targetLang: targetLang,
          ),
      ];
      final results = await Future.wait(chunk);
      for (var j = 0; j < results.length; j++) {
        translated[i + j] = results[j];
      }
    }

    return [
      for (var i = 0; i < entries.length; i++)
        TranslatedBlock(
          rect: entries[i].$1,
          original: entries[i].$2,
          translated: translated[i],
        ),
    ];
  }

  static Future<Size> _imageSize(File file) async {
    final bytes = await file.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  }
}

/// 阅读器翻译状态（全局单例，无 context 依赖）。
///
/// - 活动页 overlay 把当前 imagePath 注册到 [currentImagePath]；
/// - 顶栏按钮调 [toggleCurrentPage] 完成显示/隐藏/翻译；
/// - 结果按 imagePath 缓存在内存，翻回该页立即复用。
class TranslationController {
  TranslationController._();

  static final instance = TranslationController._();

  static bool get isSupported => TranslationService.isSupported;

  /// 当前活动页的图片路径（由 overlay 注册，退出阅读器后清空）。
  final currentImagePath = ValueNotifier<String?>(null);

  /// 正在展示译文浮层的页 key（imagePath）。
  final activeKeys = ValueNotifier<Set<String>>(<String>{});

  /// 正在翻译中的页 key。
  final loadingKey = ValueNotifier<String?>(null);

  final _cache = <String, List<TranslatedBlock>>{};
  static const _cacheLimit = 30;

  List<TranslatedBlock>? blocksFor(String key) => _cache[key];

  Future<void> toggleCurrentPage() async {
    final key = currentImagePath.value;
    if (key == null || loadingKey.value != null) return;

    if (activeKeys.value.contains(key)) {
      activeKeys.value = {...activeKeys.value}..remove(key);
      return;
    }

    if (_cache.containsKey(key)) {
      activeKeys.value = {...activeKeys.value, key};
      return;
    }

    loadingKey.value = key;
    try {
      final blocks = await TranslationService.translateImage(key);
      if (_cache.length >= _cacheLimit) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = blocks;
      activeKeys.value = {...activeKeys.value, key};
    } catch (e, s) {
      logger.e('translate page failed: $e\n$s');
      showErrorToast(t.translation.translationFailed(error: e.toString()));
    } finally {
      if (loadingKey.value == key) loadingKey.value = null;
    }
  }
}
