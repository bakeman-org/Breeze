import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/accent.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';

class EpsWidget extends StatelessWidget {
  const EpsWidget({
    super.key,
    required this.chapter,
    required this.selected,
    required this.downloaded,
    required this.onUpdateDownloadInfo,
  });

  final DownloadChapter chapter;
  final bool selected;
  final bool downloaded;
  final ValueChanged<String> onUpdateDownloadInfo;

  @override
  Widget build(BuildContext context) {
    final miuixColors = MiuixTheme.of(context).colors;

    return MiuixCheckboxPreference(
      title: chapter.displayName,
      value: selected,
      onChanged: (_) => onUpdateDownloadInfo(chapter.id),
      titleColor: MiuixBasicComponentColors(
        color: selected ? accentBlue : miuixColors.onBackground,
        disabledColor: miuixColors.disabledOnSecondaryVariant,
      ),
      summary: downloaded ? t.download.chapterDownloaded : null,
      checkboxColors: MiuixCheckboxColors(
        checkedForegroundColor: miuixColors.onPrimary,
        uncheckedForegroundColor: miuixColors.secondary,
        disabledCheckedForegroundColor: miuixColors.disabledOnPrimary,
        disabledUncheckedForegroundColor: miuixColors.disabledOnPrimary,
        checkedBackgroundColor: accentBlue,
        uncheckedBackgroundColor: miuixColors.secondary,
        disabledCheckedBackgroundColor: miuixColors.disabledPrimary,
        disabledUncheckedBackgroundColor: miuixColors.disabledSecondary,
      ),
      insideMargin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}
