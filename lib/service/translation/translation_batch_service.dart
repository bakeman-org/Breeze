// lib/service/translation/translation_batch_service.dart
// 后台批量翻译整章：串行 OCR + 翻译 + 渲染 PNG + 写 JSON。

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/translation/translation_image_renderer.dart';
import 'package:zephyr/service/translation/translation_service.dart';
import 'package:zephyr/widgets/toast.dart';

class TranslationBatchProgress {
  const TranslationBatchProgress({
    required this.completed,
    required this.total,
    required this.failed,
    this.currentImagePath,
  });

  final int completed;
  final int total;
  final int failed;
  final String? currentImagePath;

  double? get ratio => total > 0 ? completed / total : null;
}

class TranslationBatchService {
  TranslationBatchService._();
  static final instance = TranslationBatchService._();

  final progress = ValueNotifier<TranslationBatchProgress?>(null);
  bool _running = false;
  bool _cancelled = false;

  bool get isRunning => _running;

  /// 串行批量翻译 [imagePaths] 并渲染译文 PNG。
  /// 已存在译文 PNG 的页跳过。可在运行中调用 [cancel] 中断。
  Future<void> runChapter(List<String> imagePaths) async {
    if (_running) {
      showInfoToast(t.translation.batchAlreadyRunningToast);
      return;
    }
    final paths = imagePaths.where((p) => p.isNotEmpty).toSet().toList();
    if (paths.isEmpty) {
      showInfoToast(t.translation.batchNoPagesToast);
      return;
    }
    _running = true;
    _cancelled = false;
    progress.value = TranslationBatchProgress(
      completed: 0,
      total: paths.length,
      failed: 0,
    );
    showInfoToast(t.translation.batchStartedToast(total: paths.length));

    var completed = 0;
    var failed = 0;
    for (final path in paths) {
      if (_cancelled) break;
      progress.value = TranslationBatchProgress(
        completed: completed,
        total: paths.length,
        failed: failed,
        currentImagePath: path,
      );
      try {
        if (await TranslationImageRenderer.hasTranslated(path)) {
          completed++;
          continue;
        }
        final blocks = await TranslationService.translateImage(path);
        await TranslationImageRenderer.render(imagePath: path, blocks: blocks);
        await TranslationImageRenderer.saveBlocksJson(path, blocks);
        completed++;
      } catch (e) {
        failed++;
      }
      progress.value = TranslationBatchProgress(
        completed: completed,
        total: paths.length,
        failed: failed,
        currentImagePath: path,
      );
    }

    _running = false;
    progress.value = null;
    if (_cancelled) {
      showInfoToast(t.translation.batchCancelledToast);
    } else {
      showInfoToast(
        t.translation.batchFinishedToast(success: completed, failed: failed),
      );
    }
  }

  void cancel() {
    _cancelled = true;
  }
}
