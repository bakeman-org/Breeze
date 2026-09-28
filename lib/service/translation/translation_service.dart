// lib/service/translation/translation_service.dart
// 实验: 漫画翻译。OCR（ML Kit 中文识别）+ 在线翻译 API。
// 结果 rect 为归一化坐标（0-1），与显示尺寸解耦。

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/service/translation/translation_api.dart';
import 'package:zephyr/service/translation/translation_image_renderer.dart';
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
    final baiduAppId = setting.baiduAppId;
    final baiduSecretKey = setting.baiduSecretKey;

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
            baiduAppId: baiduAppId,
            baiduSecretKey: baiduSecretKey,
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

/// 阅读器翻译显示模式。
enum TranslationViewMode { off, overlay, image }

/// 阅读器翻译状态（全局单例，无 context 依赖）。
///
/// - overlay 在 build 同步时把「槽位 → 图片路径」注册进 [_registeredPages]，
///   活动页同时写入 [currentImagePath]；
/// - 顶栏按钮点击循环切换 [viewMode]：off→overlay→image→off。
///   overlay 模式下当前页 + 后方预取页进入串行翻译队列，滑动时新当前页
///   插队；image 模式停止派发新翻译，仅显示已生成的译文 PNG；
/// - 长按顶栏按钮 = 重翻当前页（清缓存强制重新 OCR + 翻译）；
/// - 结果按 imagePath 缓存在内存；失败页记入 [_failedKeys]，不自动重试。
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

  /// 翻译显示模式：off / overlay / image。
  final viewMode = ValueNotifier<TranslationViewMode>(TranslationViewMode.off);

  /// 已构建页注册表：pageSlotIndex → imagePath。
  final _registeredPages = <int, String>{};
  int _currentSlot = -1;

  final _cache = <String, List<TranslatedBlock>>{};
  final _failedKeys = <String>{};
  final _inFlight = <String>{};
  final _queue = <String>[];
  bool _pumping = false;

  static const _cacheLimit = 30;

  /// 开启自动翻译后向前预取的页数。
  static const _prefetchAhead = 2;

  List<TranslatedBlock>? blocksFor(String key) => _cache[key];

  /// 当前已构建页的图片路径（按槽位排序），供批量翻译整章使用。
  List<String> registeredImagePaths() {
    final slots = _registeredPages.keys.toList()..sort();
    return [for (final s in slots) _registeredPages[s]!];
  }

  // ── overlay 注册 ──────────────────────────────────────────────────

  /// overlay 在帧末同步自身状态：更新槽位注册表；活动页同时刷新
  /// [currentImagePath] 并触发队列重排。
  void syncOverlay({
    required int slotIndex,
    required String path,
    required bool isActive,
  }) {
    _registeredPages[slotIndex] = path;
    if (!isActive) return;
    _currentSlot = slotIndex;
    if (currentImagePath.value == path) return;
    currentImagePath.value = path;
    _scheduleAutoTranslations();
  }

  /// overlay 销毁时移除注册，避免预取到已回收的槽位。
  void removeOverlay(int slotIndex, String path) {
    if (_registeredPages[slotIndex] == path) {
      _registeredPages.remove(slotIndex);
    }
    if (currentImagePath.value == path) {
      currentImagePath.value = null;
    }
  }

  // ── 顶栏按钮 ──────────────────────────────────────────────────────

  /// 点击：循环切换显示模式 off → overlay → image → off。
  void cycleViewMode() {
    final next = switch (viewMode.value) {
      TranslationViewMode.off => TranslationViewMode.overlay,
      TranslationViewMode.overlay => TranslationViewMode.image,
      TranslationViewMode.image => TranslationViewMode.off,
    };
    viewMode.value = next;
    switch (next) {
      case TranslationViewMode.off:
        _queue.clear();
        showInfoToast(t.translation.viewModeOffToast);
      case TranslationViewMode.overlay:
        showInfoToast(t.translation.viewModeOverlayToast);
        _scheduleAutoTranslations();
      case TranslationViewMode.image:
        _queue.clear();
        showInfoToast(t.translation.viewModeImageToast);
    }
  }

  /// 长按：重翻当前页（清除缓存与失败标记后强制重跑，也用于失败重试）。
  void retranslateCurrentPage() {
    final key = currentImagePath.value;
    if (key == null) return;
    if (_inFlight.contains(key)) {
      showInfoToast(t.translation.retranslateInProgressToast);
      return;
    }
    _cache.remove(key);
    _failedKeys.remove(key);
    activeKeys.value = {...activeKeys.value}..remove(key);
    _queue
      ..remove(key)
      ..insert(0, key);
    showInfoToast(t.translation.retranslateStartedToast);
    unawaited(_pump());
  }

  // ── 队列 ──────────────────────────────────────────────────────────

  /// 按当前页 + 预取页重排队列（新当前页插队，旧计划作废）。
  void _scheduleAutoTranslations() {
    if (viewMode.value != TranslationViewMode.overlay) return;
    final wanted = <String>[];
    final current = currentImagePath.value;
    if (current != null) wanted.add(current);
    for (var i = 1; i <= _prefetchAhead; i++) {
      final path = _registeredPages[_currentSlot + i];
      if (path != null) wanted.add(path);
    }
    _queue
      ..clear()
      ..addAll([
        for (final key in wanted)
          if (!_isScheduledOrDone(key)) key,
      ]);
    unawaited(_pump());
  }

  bool _isScheduledOrDone(String key) =>
      _inFlight.contains(key) ||
      _queue.contains(key) ||
      _cache.containsKey(key) ||
      _failedKeys.contains(key);

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final key = _queue.removeAt(0);
        if (_inFlight.contains(key) ||
            _cache.containsKey(key) ||
            _failedKeys.contains(key)) {
          continue;
        }
        _inFlight.add(key);
        loadingKey.value = key;
        try {
          final blocks = await TranslationService.translateImage(key);
          if (_cache.length >= _cacheLimit) {
            _cache.remove(_cache.keys.first);
          }
          _cache[key] = blocks;
          activeKeys.value = {...activeKeys.value, key};
          // 渲染译文 PNG + 写 blocks JSON，供 image 模式显示与编辑器加载。
          unawaited(
            TranslationImageRenderer.render(
              imagePath: key,
              blocks: blocks,
            ).then((_) => TranslationImageRenderer.saveBlocksJson(key, blocks)),
          );
        } catch (e, s) {
          logger.e('translate page failed: $e\n$s');
          _failedKeys.add(key);
          if (key == currentImagePath.value) {
            showErrorToast(
              t.translation.translationFailed(error: e.toString()),
            );
          }
        } finally {
          _inFlight.remove(key);
          if (loadingKey.value == key) loadingKey.value = null;
        }
      }
    } finally {
      _pumping = false;
    }
  }
}
