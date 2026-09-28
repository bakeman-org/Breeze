import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 是否处于移动端。web 也按桌面处理，避免 Platform.isAndroid 抛异常。
bool get isMobilePlatform {
  if (kIsWeb) return false;
  final platform = defaultTargetPlatform;
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

/// macOS 习惯用 Cmd 而不是 Ctrl。
bool get useMetaKey {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS;
}

/// 是否是常见图片格式。
bool isImagePath(String path) {
  final ext = p.extension(path).toLowerCase();
  return const {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.svg',
  }.contains(ext);
}

/// 根据扩展名返回对应图标。
IconData iconForPath(String path) {
  final ext = p.extension(path).toLowerCase();
  if (isImagePath(path)) return Icons.image_outlined;
  if (ext == '.pdf') return Icons.picture_as_pdf_outlined;
  if (ext == '.txt' || ext == '.md' || ext == '.log') {
    return Icons.description_outlined;
  }
  if (ext == '.zip' || ext == '.tar' || ext == '.gz') {
    return Icons.folder_zip_outlined;
  }
  if (ext == '.json' || ext == '.yaml' || ext == '.yml') {
    return Icons.data_object;
  }
  if (ext == '.mp4' || ext == '.mov' || ext == '.webm') {
    return Icons.movie_outlined;
  }
  if (ext == '.mp3' || ext == '.wav' || ext == '.ogg') {
    return Icons.audiotrack_outlined;
  }
  return Icons.attach_file;
}

/// 本地 issue 的存储位置配置。
class LocalIssueTrackerConfig {
  final String scope;
  final String? rootOverride;

  const LocalIssueTrackerConfig({this.scope = 'zephyr', this.rootOverride});

  Future<Directory> resolveRoot() async {
    if (rootOverride != null) return Directory(rootOverride!);

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final base = await getApplicationDocumentsDirectory();
      return Directory(p.join(base.path, scope, 'issues'));
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, 'Documents', scope, 'issues'));
    }
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, scope, 'issues'));
  }
}
