// lib/service/translation/text_fit_painter.dart
// 按区域自适应字号绘制文本：浮层与译文图片渲染共用。

import 'package:material_ui/material_ui.dart';

/// 在 [rect] 内绘制 [text]，字号从 `rect.height*0.72` 起步，放不下则
/// 逐级缩小至 [minFontSize]；仍放不下则裁剪溢出部分。
///
/// 浮层用白字（覆盖原图），生成图片用黑字（白底气泡）。
void drawFittedText(
  Canvas canvas,
  Rect rect,
  String text, {
  Color color = Colors.white,
  double maxFontSize = 32.0,
  double minFontSize = 6.0,
}) {
  double fontSize = (rect.height * 0.72).clamp(minFontSize, maxFontSize);
  TextPainter painter = _layoutText(text, fontSize, rect.width, color);

  var shrunk = false;
  while (painter.height > rect.height && fontSize > minFontSize) {
    fontSize = (fontSize * 0.85).clamp(minFontSize, maxFontSize);
    painter = _layoutText(text, fontSize, rect.width, color);
    shrunk = true;
  }
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

TextPainter _layoutText(
  String text,
  double fontSize,
  double maxWidth,
  Color color,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, height: 1.15, color: color),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );
  painter.layout(maxWidth: maxWidth);
  return painter;
}
