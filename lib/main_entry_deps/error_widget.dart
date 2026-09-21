// lib/main_entry_deps/error_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// 安装资源错误兜底 ErrorWidget。
///
/// GPU 纹理分配失败（Adreno kgsl_sharedmem_alloc、iOS 上类似错误）会以
/// [FlutterErrorDetails] 形式冒泡到 [ErrorWidget.builder]。默认红屏不好看，
/// 且不会主动释放缓存，容易连锁触发更多分配失败。
///
/// 这里改成「清缓存 + 显示占位提示」，至少让用户能按返回键退出，
/// 不会被白屏/红屏卡死。
void installResourceErrorWidgetBuilder() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final msg = details.exception.toString().toLowerCase();
    final isResourceError =
        msg.contains('memory') ||
        msg.contains('gpu') ||
        msg.contains('texture') ||
        msg.contains('alloc') ||
        msg.contains('adreno') ||
        msg.contains('kgsl') ||
        msg.contains('out of') ||
        msg.contains('surface');

    if (isResourceError) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        isResourceError ? '资源紧张，已尝试释放缓存。\n如仍异常请返回上一页。' : '渲染出错',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  };
}
