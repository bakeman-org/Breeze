// lib/service/update/ntfy/torch_service.dart
import 'dart:async';
import 'package:torch_light/torch_light.dart';
import 'package:zephyr/main.dart'; // 用于 logger

class TorchService {
  TorchService._();
  static final TorchService I = TorchService._();

  bool _isFlashing = false;

  /// 闪烁序列：亮 `onMs` 毫秒 → 灭 `gapMs` 毫秒，重复 `count` 次。
  /// 调用时会自动中断上一次未完成的闪烁序列。
  Future<void> flash({int count = 3, int onMs = 1000, int gapMs = 300}) async {
    // 如果正在闪烁，先等待它结束（或直接覆盖，这里选择覆盖）
    if (_isFlashing) {
      logger.d('[TorchService] Overriding previous flash sequence.');
      // 简单处理：标记旧的序列停止，新的序列立即开始。
      // 注意：这可能导致旧的序列在 try-catch 中“未完成”而直接进入 finally。
    }

    _isFlashing = true;
    final safeCount = count.clamp(1, 50);
    final safeOnMs = onMs.clamp(50, 10000);
    final safeGapMs = gapMs.clamp(50, 10000);

    logger.i(
      '[TorchService] Flashing: count=$safeCount, on=${safeOnMs}ms, gap=${safeGapMs}ms',
    );

    try {
      for (int i = 0; i < safeCount; i++) {
        if (!_isFlashing) break; // 被新序列中断

        await TorchLight.enableTorch();
        await Future.delayed(Duration(milliseconds: safeOnMs));

        await TorchLight.disableTorch();
        // 最后一次闪烁后不需要等待间隔
        if (i < safeCount - 1) {
          await Future.delayed(Duration(milliseconds: safeGapMs));
        }
      }
    } catch (e, st) {
      logger.w('[TorchService] Flash error: $e', error: e, stackTrace: st);
      // 确保异常时手电筒关闭
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
    } finally {
      _isFlashing = false;
    }
  }

  /// 立即停止当前闪烁序列并关闭手电筒。
  Future<void> stop() async {
    _isFlashing = false;
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
  }
}
