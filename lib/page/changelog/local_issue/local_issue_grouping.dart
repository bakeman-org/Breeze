import 'package:material_ui/material_ui.dart';

import 'local_issue.dart';

/// 分组模式。
enum LocalGroupMode { status, priority, tags, date }

extension LocalGroupModeX on LocalGroupMode {
  String get label => switch (this) {
    LocalGroupMode.status => 'By Status',
    LocalGroupMode.priority => 'By Priority',
    LocalGroupMode.tags => 'By Tags',
    LocalGroupMode.date => 'By Date',
  };

  IconData get icon => switch (this) {
    LocalGroupMode.status => Icons.rule,
    LocalGroupMode.priority => Icons.sort,
    LocalGroupMode.tags => Icons.label_outline,
    LocalGroupMode.date => Icons.calendar_today,
  };
}

/// 一个可折叠的分组。
class LocalIssueSection {
  final String title;
  final List<LocalIssue> issues;
  bool expanded;
  LocalIssueSection({
    required this.title,
    required this.issues,
    this.expanded = true,
  });
}

/// 按指定维度分组。
List<LocalIssueSection> groupLocalIssues(
  List<LocalIssue> all,
  LocalGroupMode mode,
) {
  switch (mode) {
    case LocalGroupMode.status:
      final open = all.where((i) => !i.done).toList();
      final done = all.where((i) => i.done).toList();
      return [
        if (open.isNotEmpty)
          LocalIssueSection(title: 'Open (${open.length})', issues: open),
        if (done.isNotEmpty)
          LocalIssueSection(
            title: 'Done (${done.length})',
            issues: done,
            expanded: false,
          ),
      ];

    case LocalGroupMode.priority:
      final buckets = <String, List<LocalIssue>>{
        'Critical (0-9)': [],
        'High (10-29)': [],
        'Medium (30-69)': [],
        'Low (70+)': [],
      };
      for (final i in all) {
        if (i.priority < 10) {
          buckets['Critical (0-9)']!.add(i);
        } else if (i.priority < 30) {
          buckets['High (10-29)']!.add(i);
        } else if (i.priority < 70) {
          buckets['Medium (30-69)']!.add(i);
        } else {
          buckets['Low (70+)']!.add(i);
        }
      }
      return buckets.entries.where((e) => e.value.isNotEmpty).map((e) {
        e.value.sort((a, b) => a.priority.compareTo(b.priority));
        return LocalIssueSection(
          title: '${e.key} — ${e.value.length}',
          issues: e.value,
        );
      }).toList();

    case LocalGroupMode.tags:
      final map = <String, List<LocalIssue>>{};
      for (final i in all) {
        final tag = i.tags.isNotEmpty ? i.tags.first : 'Untagged';
        map.putIfAbsent(tag, () => []).add(i);
      }
      final sections = map.entries
          .map(
            (e) => LocalIssueSection(
              title: '#${e.key} (${e.value.length})',
              issues: e.value,
            ),
          )
          .toList();
      sections.sort((a, b) => b.issues.length.compareTo(a.issues.length));
      return sections;

    case LocalGroupMode.date:
      final now = DateTime.now();
      final today = <LocalIssue>[];
      final week = <LocalIssue>[];
      final month = <LocalIssue>[];
      final older = <LocalIssue>[];
      for (final i in all) {
        final diff = now.difference(i.createdAt);
        if (diff.inDays < 1) {
          today.add(i);
        } else if (diff.inDays < 7) {
          week.add(i);
        } else if (diff.inDays < 30) {
          month.add(i);
        } else {
          older.add(i);
        }
      }
      return [
        if (today.isNotEmpty)
          LocalIssueSection(title: 'Today (${today.length})', issues: today),
        if (week.isNotEmpty)
          LocalIssueSection(title: 'This Week (${week.length})', issues: week),
        if (month.isNotEmpty)
          LocalIssueSection(
            title: 'This Month (${month.length})',
            issues: month,
          ),
        if (older.isNotEmpty)
          LocalIssueSection(title: 'Older (${older.length})', issues: older),
      ];
  }
}
