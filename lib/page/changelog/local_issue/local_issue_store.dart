import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_issue.dart';
import 'local_issue_config.dart';

/// 本地 issue 存储层。
class LocalIssueStore {
  final LocalIssueTrackerConfig config;
  LocalIssueStore(this.config);

  Future<Directory> root() async {
    final dir = await config.resolveRoot();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<LocalIssue>> loadAll() async {
    final dir = await root();
    final result = <LocalIssue>[];
    await for (final e in dir.list()) {
      if (e is! Directory) continue;
      final md = File(p.join(e.path, 'issue.md'));
      if (!await md.exists()) continue;
      result.add(parseLocalIssue(e, await md.readAsString()));
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<LocalIssue> create({
    required String title,
    int priority = 50,
    List<String> tags = const [],
  }) async {
    final dir = await root();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final id =
        '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}';

    final issueDir = Directory(p.join(dir.path, id));
    await issueDir.create(recursive: true);

    final issue = LocalIssue(
      dir: issueDir,
      title: title,
      body: '',
      done: false,
      priority: priority,
      tags: tags,
      createdAt: now,
      attachments: const [],
    );
    await save(issue);
    return issue;
  }

  Future<void> save(LocalIssue issue) async {
    await issue.mdFile.writeAsString(issue.toMarkdown());
  }
}
