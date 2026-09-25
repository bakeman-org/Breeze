import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

MiuixTextFieldColors dimmedHintFieldColors(BuildContext context) {
  final base = MiuixTextFieldDefaults.textFieldColors(context);
  return MiuixTextFieldColors(
    backgroundColor: base.backgroundColor,
    labelColor: base.labelColor.withValues(alpha: 0.55),
    borderColor: base.borderColor,
  );
}
