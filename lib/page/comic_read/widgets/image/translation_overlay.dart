// lib/page/comic_read/widgets/image/translation_overlay.dart
// 译文浮层：叠在 ImageDisplay 的图片上，按归一化 rect 绘制译文。

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/service/translation/translation_service.dart';

class TranslationOverlay extends StatefulWidget {
  final String imagePath;
  final int pageSlotIndex;

  const TranslationOverlay({
    super.key,
    required this.imagePath,
    required this.pageSlotIndex,
  });

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay> {
  bool _syncedActive = false;
  String? _syncedPath;

  /// 活动状态或图片路径变化时，帧末把自身注册进控制器：
  /// 非活动页仅进入槽位注册表供预取寻址；活动页刷新 currentImagePath。
  void _scheduleSync(bool isActive) {
    if (_syncedActive == isActive && _syncedPath == widget.imagePath) return;
    _syncedActive = isActive;
    _syncedPath = widget.imagePath;
    final slotIndex = widget.pageSlotIndex;
    final path = widget.imagePath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TranslationController.instance.syncOverlay(
        slotIndex: slotIndex,
        path: path,
        isActive: isActive,
      );
    });
  }

  @override
  void dispose() {
    final controller = TranslationController.instance;
    final path = _syncedPath;
    if (path != null) {
      controller.removeOverlay(widget.pageSlotIndex, path);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = context.select(
      (ReaderCubit c) => c.state.currentSlot == widget.pageSlotIndex,
    );
    _scheduleSync(isActive);
    if (!isActive) return const SizedBox.shrink();

    final controller = TranslationController.instance;
    return IgnorePointer(
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: controller.activeKeys,
        builder: (context, activeKeys, _) {
          final blocks = activeKeys.contains(widget.imagePath)
              ? controller.blocksFor(widget.imagePath)
              : null;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (blocks != null && blocks.isNotEmpty)
                CustomPaint(painter: _TranslationPainter(blocks)),
              ValueListenableBuilder<String?>(
                valueListenable: controller.loadingKey,
                builder: (context, loadingKey, _) {
                  if (loadingKey != widget.imagePath) {
                    return const SizedBox.shrink();
                  }
                  return const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TranslationPainter extends CustomPainter {
  _TranslationPainter(this.blocks);

  final List<TranslatedBlock> blocks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final block in blocks) {
      final rect = Rect.fromLTWH(
        block.rect.left * size.width,
        block.rect.top * size.height,
        block.rect.width * size.width,
        block.rect.height * size.height,
      );
      if (rect.isEmpty) continue;

      final bgRect = RRect.fromRectAndRadius(
        rect.inflate(2),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );

      _drawFittedText(canvas, rect, block.translated);
    }
  }

  void _drawFittedText(Canvas canvas, Rect rect, String text) {
    const maxFontSize = 32.0;
    const minFontSize = 6.0;

    double fontSize = (rect.height * 0.72).clamp(minFontSize, maxFontSize);
    TextPainter painter = _layout(text, fontSize, rect.width);

    // 放不下则逐步缩小字号。
    var shrunk = false;
    while (painter.height > rect.height && fontSize > minFontSize) {
      fontSize = (fontSize * 0.85).clamp(minFontSize, maxFontSize);
      painter = _layout(text, fontSize, rect.width);
      shrunk = true;
    }
    // 缩到底还放不下就裁掉溢出部分（clip 在 bgRect 内）。
    if (shrunk && painter.height > rect.height) {
      canvas.save();
      canvas.clipRect(rect.inflate(2));
      painter.paint(canvas, rect.topLeft);
      canvas.restore();
      return;
    }

    painter.paint(
      canvas,
      Offset(rect.left, rect.top + (rect.height - painter.height) / 2),
    );
  }

  TextPainter _layout(String text, double fontSize, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, height: 1.15, color: Colors.white),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);
    return painter;
  }

  @override
  bool shouldRepaint(covariant _TranslationPainter oldDelegate) =>
      oldDelegate.blocks != blocks;
}
