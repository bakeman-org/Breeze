import 'package:material_ui/material_ui.dart';
// 关键：单独引入 flutter/material 的 Material，带前缀避免与 material_ui
// 的同名类冲突。flutter_colorpicker 内部用的是 flutter/material 的
// TextField，它只认 flutter/material 的 Material 祖先。
import 'package:flutter/material.dart' as fm;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerPage extends StatelessWidget {
  final Color currentColor;
  final Function(Color) onColorChanged;

  const ColorPickerPage({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      // 用 flutter/material 的 Material 包一层，为 HueRingPicker 内部的
      // TextField 提供 Material 祖先，避免 "No Material widget found"。
      child: fm.Material(
        type: fm.MaterialType.transparency,
        child: Column(
          children: [
            HueRingPicker(
              pickerColor: currentColor,
              onColorChanged: onColorChanged, // 颜色变化时回调
              displayThumbColor: true, // 是否显示拇指颜色
            ),
          ],
        ),
      ),
    );
  }
}
