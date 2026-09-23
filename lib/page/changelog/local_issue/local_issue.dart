import 'dart:io';

import 'package:path/path.dart' as p;

/// 一条本地 issue，对应磁盘上一个文件夹：
///   issue.md         —— 标题 + 属性块 + 正文
///   attachments/     —— 附件（图片、PDF、日志等）
///   images/          —— 旧版目录，读取时兼容
class LocalIssue {
  final Directory dir;
  String title;
  String body;
  bool done;
  int priority;
  List<String> tags;
  DateTime createdAt;
  List<File> attachments;

  /// 推送到 GitHub 后的编号 / URL；未推送则为 null。
  int? githubNumber;
  String? githubUrl;

  LocalIssue({
    required this.dir,
    required this.title,
    required this.body,
    required this.done,
    required this.priority,
    required this.tags,
    required this.createdAt,
    required this.attachments,
    this.githubNumber,
    this.githubUrl,
  });

  String get id => p.basename(dir.path);
  File get mdFile => File(p.join(dir.path, 'issue.md'));
  Directory get attachmentsDir => Directory(p.join(dir.path, 'attachments'));

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln('- STATUS: ${done ? 'CLOSED' : 'OPEN'}')
      ..writeln('- PRIORITY: $priority')
      ..writeln('- TAGS: ${tags.join(', ')}');
    if (githubNumber != null) {
      final url = githubUrl == null ? '' : ' ($githubUrl)';
      b.writeln('- GITHUB: #$githubNumber$url');
    }
    b
      ..writeln()
      ..write(body);
    return b.toString();
  }
}

/// 把 issue.md 解析成 LocalIssue。
LocalIssue parseLocalIssue(Directory dir, String raw) {
  final lines = raw.split('\n');
  var title = p.basename(dir.path);
  var priority = 50;
  var done = false;
  final tags = <String>[];
  int? githubNumber;
  String? githubUrl;
  var bodyStart = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i == 0 && line.startsWith('#')) {
      title = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      bodyStart = i + 1;
      continue;
    }
    if (line.startsWith('- STATUS:')) {
      done =
          line.replaceFirst('- STATUS:', '').trim().toUpperCase() == 'CLOSED';
      bodyStart = i + 1;
      continue;
    }
    if (line.startsWith('- PRIORITY:')) {
      priority =
          int.tryParse(line.replaceFirst('- PRIORITY:', '').trim()) ?? 50;
      bodyStart = i + 1;
      continue;
    }
    if (line.startsWith('- TAGS:')) {
      final rawTags = line.replaceFirst('- TAGS:', '').trim();
      tags.addAll(rawTags.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty));
      bodyStart = i + 1;
      continue;
    }
    if (line.startsWith('- GITHUB:')) {
      final v = line.replaceFirst('- GITHUB:', '').trim();
      final numMatch = RegExp(r'#(\d+)').firstMatch(v);
      if (numMatch != null) githubNumber = int.tryParse(numMatch.group(1)!);
      final urlMatch = RegExp(r'\((https?://[^)]+)\)').firstMatch(v);
      if (urlMatch != null) githubUrl = urlMatch.group(1);
      bodyStart = i + 1;
      continue;
    }
    if (line.trim().isEmpty) {
      bodyStart = i + 1;
      continue;
    }
    break;
  }

  final body = lines.sublist(bodyStart).join('\n').trim();

  DateTime createdAt;
  try {
    final parts = p.basename(dir.path).split('-');
    createdAt = DateTime(
      int.parse(parts[0].substring(0, 4)),
      int.parse(parts[0].substring(4, 6)),
      int.parse(parts[0].substring(6, 8)),
      int.parse(parts[1].substring(0, 2)),
      int.parse(parts[1].substring(2, 4)),
      int.parse(parts[1].substring(4, 6)),
    );
  } catch (_) {
    createdAt = DateTime.now();
  }

  final attachments = <File>[];
  for (final folderName in ['attachments', 'images']) {
    final d = Directory(p.join(dir.path, folderName));
    if (d.existsSync()) {
      for (final e in d.listSync()) {
        if (e is File) attachments.add(e);
      }
    }
  }
  attachments.sort((a, b) => a.path.compareTo(b.path));

  return LocalIssue(
    dir: dir,
    title: title,
    body: body,
    done: done,
    priority: priority,
    tags: tags,
    createdAt: createdAt,
    attachments: attachments,
    githubNumber: githubNumber,
    githubUrl: githubUrl,
  );
}
