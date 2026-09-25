import 'package:material_ui/material_ui.dart';

const Color accentBlue = Colors.blue;

TextStyle accentTextStyle(
  TextStyle? base, {
  double? fontSize,
  FontWeight? fontWeight,
}) {
  return (base ?? const TextStyle()).copyWith(
    color: accentBlue,
    fontSize: fontSize,
    fontWeight: fontWeight,
  );
}
