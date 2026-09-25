import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr/widgets/toast.dart';

/// 是否处于移动端。web 也按桌面处理，避免 Platform.isAndroid 抛异常。
bool get _isMobilePlatform {
  if (kIsWeb) return false;
  final p = defaultTargetPlatform;
  return p == TargetPlatform.android || p == TargetPlatform.iOS;
}

/// macOS 习惯用 Cmd 而不是 Ctrl。
bool get _useMetaKey {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS;
}

/// 是否是常见图片格式。
bool _isImagePath(String path) {
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
IconData _iconForPath(String path) {
  final ext = p.extension(path).toLowerCase();
  if (_isImagePath(path)) return Icons.image_outlined;
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

/// 桌面端快捷键包装：整棵子树用 Focus(autofocus) + CallbackShortcuts 挂键盘事件。
class _DesktopShortcuts extends StatelessWidget {
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;
  const _DesktopShortcuts({required this.bindings, required this.child});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(bindings: bindings, child: child),
    );
  }
}

/// 单个 FAB 动作。
class _FabAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _FabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// 移动端速度拨号 FAB 组：点击主 FAB 展开一组子 FAB，每个带标签气泡。
class _FabGroup extends StatefulWidget {
  final List<_FabAction> actions;
  const _FabGroup({required this.actions});

  @override
  State<_FabGroup> createState() => _FabGroupState();
}

class _FabGroupState extends State<_FabGroup> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.bottomRight,
          child: _expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.actions.reversed.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            elevation: 2,
                            borderRadius: BorderRadius.circular(6),
                            color: theme.colorScheme.inverseSurface,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                a.label,
                                style: TextStyle(
                                  color: theme.colorScheme.onInverseSurface,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            heroTag: null,
                            onPressed: () {
                              _toggle();
                              a.onPressed();
                            },
                            child: Icon(a.icon),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'local-issue-main-fab',
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(_expanded ? Icons.close : Icons.menu),
          ),
        ),
      ],
    );
  }
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

  LocalIssue({
    required this.dir,
    required this.title,
    required this.body,
    required this.done,
    required this.priority,
    required this.tags,
    required this.createdAt,
    required this.attachments,
  });

  String get id => p.basename(dir.path);
  File get mdFile => File(p.join(dir.path, 'issue.md'));
  Directory get attachmentsDir => Directory(p.join(dir.path, 'attachments'));

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln('- STATUS: ${done ? 'CLOSED' : 'OPEN'}')
      ..writeln('- PRIORITY: $priority')
      ..writeln('- TAGS: ${tags.join(', ')}')
      ..writeln();
    b.write(body);
    return b.toString();
  }
}

/// 把 issue.md 解析成 LocalIssue。
LocalIssue _parseLocalIssue(Directory dir, String raw) {
  final lines = raw.split('\n');
  var title = p.basename(dir.path);
  var priority = 50;
  var done = false;
  final tags = <String>[];
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
  );
}

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
      result.add(_parseLocalIssue(e, await md.readAsString()));
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

/// 分组模式。
enum LocalGroupMode { status, priority, tags, date }

extension _LocalGroupModeX on LocalGroupMode {
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
class _LocalIssueSection {
  final String title;
  final List<LocalIssue> issues;
  bool expanded;
  _LocalIssueSection({
    required this.title,
    required this.issues,
    this.expanded = true,
  });
}

/// 按指定维度分组。
List<_LocalIssueSection> _groupLocalIssues(
  List<LocalIssue> all,
  LocalGroupMode mode,
) {
  switch (mode) {
    case LocalGroupMode.status:
      final open = all.where((i) => !i.done).toList();
      final done = all.where((i) => i.done).toList();
      return [
        if (open.isNotEmpty)
          _LocalIssueSection(title: 'Open (${open.length})', issues: open),
        if (done.isNotEmpty)
          _LocalIssueSection(
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
        return _LocalIssueSection(
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
            (e) => _LocalIssueSection(
              title: '#${e.key} (${e.value.length})',
              issues: e.value,
            ),
          )
          .toList();
      sections.sort((a, b) => b.issues.length.compareTo(a.issues.length));
      return sections;

    case LocalGroupMode.date:
      final now = DateTime.now();
      final today = <LocalIssue>[],
          week = <LocalIssue>[],
          month = <LocalIssue>[],
          older = <LocalIssue>[];
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
          _LocalIssueSection(title: 'Today (${today.length})', issues: today),
        if (week.isNotEmpty)
          _LocalIssueSection(title: 'This Week (${week.length})', issues: week),
        if (month.isNotEmpty)
          _LocalIssueSection(
            title: 'This Month (${month.length})',
            issues: month,
          ),
        if (older.isNotEmpty)
          _LocalIssueSection(title: 'Older (${older.length})', issues: older),
      ];
  }
}

/// 主 widget：作为 ChangelogPage 的第三个 Tab 嵌入。
///
/// 自带 Scaffold（透明背景）以便 FAB 和 SnackBar 有 host。
/// 不提供 AppBar —— 外层 TabBar 已经承担标题和切换。
class LocalIssueTrackerTab extends StatefulWidget {
  final LocalIssueTrackerConfig config;
  const LocalIssueTrackerTab({
    super.key,
    this.config = const LocalIssueTrackerConfig(),
  });

  @override
  State<LocalIssueTrackerTab> createState() => _LocalIssueTrackerTabState();
}

class _LocalIssueTrackerTabState extends State<LocalIssueTrackerTab> {
  late final LocalIssueStore _store = LocalIssueStore(widget.config);
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<LocalIssue> _all = [];
  bool _loading = true;
  String _query = '';
  LocalGroupMode _mode = LocalGroupMode.status;
  String? _statusFilter;
  final Set<String> _tagFilter = {};
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  List<LocalIssue> get _filtered {
    return _all.where((i) {
      if (_statusFilter == 'open' && i.done) return false;
      if (_statusFilter == 'done' && !i.done) return false;
      if (_tagFilter.isNotEmpty && !i.tags.any(_tagFilter.contains)) {
        return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!i.title.toLowerCase().contains(q) &&
            !i.body.toLowerCase().contains(q) &&
            !i.tags.any((t) => t.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Set<String> get _allTags => _all.expand((i) => i.tags).toSet();

  Future<void> _createIssue() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New issue'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Short title'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final issue = await _store.create(title: title);
    await _reload();
    if (!mounted) return;
    await _openIssue(issue);
  }

  Future<void> _openIssue(LocalIssue issue) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => _LocalIssueDetailScreen(
          issue: issue,
          store: _store,
          allTags: _allTags.toList(),
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    await _reload();
  }

  Future<void> _showStorageInfo() async {
    final dir = await _store.root();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Storage location'),
        content: SelectableText(dir.path),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGroupPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: LocalGroupMode.values
              .map(
                (m) => ListTile(
                  leading: Icon(m.icon),
                  title: Text(m.label),
                  selected: m == _mode,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _mode = m);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final tags = _allTags.toList()..sort();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('All')),
                      ButtonSegment(value: 'open', label: Text('Open')),
                      ButtonSegment(value: 'done', label: Text('Done')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (s) {
                      setState(() => _statusFilter = s.first);
                      setS(() {});
                    },
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Tags',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map(
                            (t) => FilterChip(
                              label: Text(t),
                              selected: _tagFilter.contains(t),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _tagFilter.add(t);
                                  } else {
                                    _tagFilter.remove(t);
                                  }
                                });
                                setS(() {});
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _statusFilter = null;
                            _tagFilter.clear();
                          });
                          setS(() {});
                        },
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    final ctrl = _useMetaKey;
    return {
      SingleActivator(LogicalKeyboardKey.keyN, control: !ctrl, meta: ctrl):
          _createIssue,
      SingleActivator(LogicalKeyboardKey.keyF, control: !ctrl, meta: ctrl): () {
        _searchFocus.requestFocus();
      },
      SingleActivator(LogicalKeyboardKey.keyR, control: !ctrl, meta: ctrl):
          _reload,
      SingleActivator(LogicalKeyboardKey.keyG, control: !ctrl, meta: ctrl):
          _showGroupPicker,
      SingleActivator(
        LogicalKeyboardKey.keyF,
        control: !ctrl,
        meta: ctrl,
        shift: true,
      ): _showFilters,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final sections = _groupLocalIssues(filtered, _mode);
    final isMobile = _isMobilePlatform;

    for (final sec in sections) {
      if (!_expandedSections.containsKey(sec.title)) {
        _expandedSections[sec.title] = sec.expanded;
      }
      sec.expanded = _expandedSections[sec.title]!;
    }

    final body = Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: isMobile
                          ? 'grep title / body / tags...'
                          : 'grep title / body / tags...  (Ctrl+F)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Group: ${_mode.label}  (Ctrl+G)',
                    icon: Icon(_mode.icon),
                    onPressed: _showGroupPicker,
                  ),
                  IconButton(
                    tooltip: 'Filters  (Ctrl+Shift+F)',
                    icon: Badge(
                      isLabelVisible:
                          _statusFilter != null || _tagFilter.isNotEmpty,
                      child: const Icon(Icons.filter_alt_outlined),
                    ),
                    onPressed: _showFilters,
                  ),
                  IconButton(
                    tooltip: 'Storage path',
                    icon: const Icon(Icons.folder_outlined),
                    onPressed: _showStorageInfo,
                  ),
                  IconButton(
                    tooltip: 'Refresh  (Ctrl+R)',
                    icon: const Icon(Icons.refresh),
                    onPressed: _reload,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} issue(s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_statusFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Chip(
                      label: Text('status: $_statusFilter'),
                      onDeleted: () => setState(() => _statusFilter = null),
                    ),
                  ),
                for (final t in _tagFilter)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Chip(
                      label: Text('#$t'),
                      onDeleted: () => setState(() => _tagFilter.remove(t)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : sections.isEmpty
                ? const Center(child: Text('No issues match'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: sections.length,
                    itemBuilder: (_, si) {
                      final s = sections[si];
                      return _LocalSectionView(
                        section: s,
                        onToggle: () {
                          setState(() {
                            _expandedSections[s.title] = !s.expanded;
                            s.expanded = _expandedSections[s.title]!;
                          });
                        },
                        onIssueTap: _openIssue,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? _FabGroup(
              actions: [
                _FabAction(
                  icon: Icons.add,
                  label: 'New issue',
                  onPressed: _createIssue,
                ),
                _FabAction(
                  icon: _mode.icon,
                  label: _mode.label,
                  onPressed: _showGroupPicker,
                ),
                _FabAction(
                  icon: Icons.filter_alt_outlined,
                  label: 'Filters',
                  onPressed: _showFilters,
                ),
                _FabAction(
                  icon: Icons.folder_outlined,
                  label: 'Storage',
                  onPressed: _showStorageInfo,
                ),
                _FabAction(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  onPressed: _reload,
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: _createIssue,
              icon: const Icon(Icons.add),
              label: const Text('New issue  (Ctrl+N)'),
            ),
    );

    return isMobile
        ? body
        : _DesktopShortcuts(bindings: _buildShortcuts(), child: body);
  }
}

class _LocalSectionView extends StatelessWidget {
  final _LocalIssueSection section;
  final VoidCallback onToggle;
  final void Function(LocalIssue) onIssueTap;
  const _LocalSectionView({
    required this.section,
    required this.onToggle,
    required this.onIssueTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  section.expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.chevron_right,
                ),
                const SizedBox(width: 12),
                Text(
                  section.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (section.expanded)
          ...section.issues.map(
            (i) => _LocalIssueTile(issue: i, onTap: () => onIssueTap(i)),
          ),
      ],
    );
  }
}

class _LocalIssueTile extends StatelessWidget {
  final LocalIssue issue;
  final VoidCallback onTap;
  const _LocalIssueTile({required this.issue, required this.onTap});

  Color _priorityColor(BuildContext ctx) {
    final c = Theme.of(ctx).colorScheme;
    if (issue.priority < 10) return c.error;
    if (issue.priority < 30) return Colors.orange;
    if (issue.priority < 70) return c.primary;
    return c.outline;
  }

  String _shortDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = _priorityColor(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          issue.done ? Icons.check_circle : Icons.bug_report_outlined,
          color: issue.done ? Colors.green : null,
          size: 28,
        ),
        title: Text(
          issue.title,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: issue.done ? TextDecoration.lineThrough : null,
            color: issue.done ? theme.disabledColor : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pc.withAlpha(38),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'P${issue.priority}',
                  style: TextStyle(
                    fontSize: 12,
                    color: pc,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final t in issue.tags)
                Text(
                  '#$t',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Text(
                _shortDate(issue.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: issue.attachments.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, size: 20, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${issue.attachments.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

enum _LocalViewMode { split, edit, preview }

/// 详情页：独立路由 push 出来，所以这里保留完整 Scaffold + AppBar。
class _LocalIssueDetailScreen extends StatefulWidget {
  final LocalIssue issue;
  final LocalIssueStore store;
  final List<String> allTags;
  const _LocalIssueDetailScreen({
    required this.issue,
    required this.store,
    required this.allTags,
  });

  @override
  State<_LocalIssueDetailScreen> createState() =>
      _LocalIssueDetailScreenState();
}

class _LocalIssueDetailScreenState extends State<_LocalIssueDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _tagCtrl;

  late bool _done;
  late double _priority;
  late List<String> _tags;
  late List<File> _attachments;

  _LocalViewMode _viewMode = _LocalViewMode.split;
  bool _dirty = false;

  Timer? _debounce;
  late String _previewData;
  final Map<String, File?> _resolveCache = {};
  bool _showAutocomplete = false;

  MarkdownConfig? _cachedConfig;
  ThemeData? _cachedTheme;

  @override
  void initState() {
    super.initState();
    final i = widget.issue;
    _titleCtrl = TextEditingController(text: i.title);
    _bodyCtrl = TextEditingController(text: i.body);
    _tagCtrl = TextEditingController();
    _done = i.done;
    _priority = i.priority.toDouble();
    _tags = List.from(i.tags);
    _attachments = List.from(i.attachments);
    _previewData = i.body;

    _titleCtrl.addListener(_markDirty);
    _bodyCtrl.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _previewData = _bodyCtrl.text);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showAutocomplete = true);
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.issue
      ..title = _titleCtrl.text.trim()
      ..body = _bodyCtrl.text
      ..done = _done
      ..priority = _priority.round()
      ..tags = List.from(_tags)
      ..attachments = List.from(_attachments);
    await widget.store.save(widget.issue);
    if (!mounted) return;
    setState(() => _dirty = false);
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(
    //     content: Text('Saved'),
    //     duration: Duration(milliseconds: 700),
    //   ),
    // );
    showInfoToast('Issue saved');
  }

  /// 用 file_selector 的 openFiles 一次挑多个文件（无类型限制）。
  /// openFiles 返回 XFile 列表，XFile.path 就是本地绝对路径。
  Future<void> _pickAttachment() async {
    final files = await openFiles();
    if (files.isEmpty) return;

    final dir = widget.issue.attachmentsDir;
    if (!await dir.exists()) await dir.create(recursive: true);

    final added = <File>[];
    for (final f in files) {
      final srcPath = f.path;
      if (srcPath.isEmpty) continue;
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(srcPath)}';
      final dest = File(p.join(dir.path, name));
      await File(srcPath).copy(dest.path);
      added.add(dest);
    }

    if (added.isEmpty) return;
    setState(() {
      _attachments.addAll(added);
      _dirty = true;
      _resolveCache.clear();
    });
    await _save();
  }

  Future<void> _deleteAttachment(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: Text(p.basename(f.path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await f.exists()) await f.delete();
    setState(() {
      _attachments.remove(f);
      _dirty = true;
      _resolveCache.clear();
    });
    await _save();
  }

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) {
      setState(() => _tags.add(t));
      _dirty = true;
    }
    _tagCtrl.clear();
  }

  File? _resolveAttachment(String relPath) {
    if (_resolveCache.containsKey(relPath)) return _resolveCache[relPath];
    if (relPath.startsWith('http://') || relPath.startsWith('https://')) {
      _resolveCache[relPath] = null;
      return null;
    }
    final candidates = [
      File(p.join(widget.issue.dir.path, relPath)),
      File(p.join(widget.issue.dir.path, 'attachments', p.basename(relPath))),
      File(p.join(widget.issue.dir.path, 'images', p.basename(relPath))),
    ];
    File? found;
    for (final f in candidates) {
      if (f.existsSync()) {
        found = f;
        break;
      }
    }
    _resolveCache[relPath] = found;
    return found;
  }

  void _insertAttachmentMarkdown(File f) {
    final rel = 'attachments/${p.basename(f.path)}';
    final name = p.basenameWithoutExtension(f.path);
    final insertion = _isImagePath(f.path)
        ? '\n![$name]($rel)\n'
        : '\n[$name]($rel)\n';

    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    final newText = sel.isValid
        ? text.replaceRange(sel.start, sel.end, insertion)
        : '$text$insertion';
    _bodyCtrl.text = newText;
    _bodyCtrl.selection = TextSelection.collapsed(
      offset: (sel.isValid ? sel.start : text.length) + insertion.length,
    );
  }

  Future<void> _openAttachmentExternally(String absPath) async {
    final file = File(absPath);
    if (!await file.exists()) {
      if (!mounted) return;
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('File not found: $absPath')));
      showInfoToast('File not found: $absPath');
      return;
    }
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [absPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [absPath]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', absPath]);
      } else {
        if (!mounted) return;

        // ScaffoldMessenger.of(
        //   context,
        // ).showSnackBar(SnackBar(content: Text('Saved at: $absPath')));
        showInfoToast('Saved at: $absPath');
      }
    } catch (e) {
      if (!mounted) return;
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('Could not open: $e')));
      showInfoToast('Could not open: $e');
    }
  }

  Future<void> _confirmLeave() async {
    if (!_dirty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) await _save();
    if (mounted) Navigator.pop(context);
  }

  void _cycleViewMode() {
    setState(() {
      if (_viewMode == _LocalViewMode.split) {
        _viewMode = _LocalViewMode.edit;
      } else if (_viewMode == _LocalViewMode.edit) {
        _viewMode = _LocalViewMode.preview;
      } else {
        _viewMode = _LocalViewMode.split;
      }
    });
  }

  void _toggleDone() {
    setState(() {
      _done = !_done;
      _dirty = true;
    });
    _save();
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    final ctrl = _useMetaKey;
    return {
      SingleActivator(LogicalKeyboardKey.keyS, control: !ctrl, meta: ctrl):
          _save,
      SingleActivator(LogicalKeyboardKey.keyE, control: !ctrl, meta: ctrl):
          _cycleViewMode,
      SingleActivator(LogicalKeyboardKey.keyD, control: !ctrl, meta: ctrl):
          _toggleDone,
      SingleActivator(
        LogicalKeyboardKey.keyA,
        control: !ctrl,
        meta: ctrl,
        shift: true,
      ): _pickAttachment,
      const SingleActivator(LogicalKeyboardKey.escape): _confirmLeave,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = _isMobilePlatform;

    final scaffold = PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmLeave,
          ),
          title: Text(
            _titleCtrl.text.isEmpty ? 'Untitled' : _titleCtrl.text,
            overflow: TextOverflow.ellipsis,
          ),
          actions: isMobile
              ? null
              : [
                  IconButton(
                    tooltip: 'View mode  (Ctrl+E)',
                    icon: Icon(
                      _viewMode == _LocalViewMode.split
                          ? Icons.splitscreen
                          : _viewMode == _LocalViewMode.edit
                          ? Icons.edit
                          : Icons.visibility,
                    ),
                    onPressed: _cycleViewMode,
                  ),
                  IconButton(
                    tooltip: _done
                        ? 'Reopen  (Ctrl+D)'
                        : 'Close as done  (Ctrl+D)',
                    icon: Icon(
                      _done ? Icons.check_circle : Icons.check_circle_outline,
                    ),
                    color: _done ? Colors.green : null,
                    onPressed: _toggleDone,
                  ),
                  IconButton(
                    tooltip: 'Save  (Ctrl+S)',
                    icon: Badge(
                      isLabelVisible: _dirty,
                      smallSize: 8,
                      child: const Icon(Icons.save),
                    ),
                    onPressed: _save,
                  ),
                ],
        ),
        floatingActionButton: isMobile
            ? _FabGroup(
                actions: [
                  _FabAction(
                    icon: Icons.save,
                    label: _dirty ? 'Save *' : 'Save',
                    onPressed: _save,
                  ),
                  _FabAction(
                    icon: _done
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    label: _done ? 'Reopen' : 'Close as done',
                    onPressed: _toggleDone,
                  ),
                  _FabAction(
                    icon: _viewMode == _LocalViewMode.split
                        ? Icons.splitscreen
                        : _viewMode == _LocalViewMode.edit
                        ? Icons.edit
                        : Icons.visibility,
                    label: 'View: ${_viewMode.name}',
                    onPressed: _cycleViewMode,
                  ),
                  _FabAction(
                    icon: Icons.attach_file,
                    label: 'Add file',
                    onPressed: _pickAttachment,
                  ),
                ],
              )
            : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1000;
            final showSplit = isWide && _viewMode == _LocalViewMode.split;
            final showPreviewOnly = _viewMode == _LocalViewMode.preview;
            final showEditOnly =
                _viewMode == _LocalViewMode.edit ||
                (!isWide && !showPreviewOnly);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      RepaintBoundary(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Priority: ${_priority.round()}',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _done
                                            ? Colors.green.withAlpha(38)
                                            : theme.colorScheme.primary
                                                  .withAlpha(38),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _done ? 'CLOSED' : 'OPEN',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _done
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _priority,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  label: _priority.round().toString(),
                                  onChanged: (v) {
                                    setState(() {
                                      _priority = v;
                                      _dirty = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _showAutocomplete
                                          ? Autocomplete<String>(
                                              optionsBuilder:
                                                  (
                                                    TextEditingValue
                                                    textEditingValue,
                                                  ) {
                                                    if (textEditingValue
                                                        .text
                                                        .isEmpty) {
                                                      return widget.allTags;
                                                    }
                                                    return widget.allTags.where(
                                                      (tag) => tag
                                                          .toLowerCase()
                                                          .contains(
                                                            textEditingValue
                                                                .text
                                                                .toLowerCase(),
                                                          ),
                                                    );
                                                  },
                                              onSelected: (String selection) {
                                                _tagCtrl.text = selection;
                                                _addTag();
                                              },
                                              fieldViewBuilder:
                                                  (
                                                    context,
                                                    controller,
                                                    focusNode,
                                                    onFieldSubmitted,
                                                  ) {
                                                    controller.addListener(() {
                                                      if (_tagCtrl.text !=
                                                          controller.text) {
                                                        _tagCtrl.text =
                                                            controller.text;
                                                      }
                                                    });
                                                    return TextField(
                                                      controller: controller,
                                                      focusNode: focusNode,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Add tag',
                                                            border:
                                                                OutlineInputBorder(),
                                                            isDense: true,
                                                          ),
                                                      onSubmitted: (_) =>
                                                          _addTag(),
                                                    );
                                                  },
                                            )
                                          : TextField(
                                              controller: _tagCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Add tag',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              onSubmitted: (_) => _addTag(),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      onPressed: _addTag,
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                                if (_tags.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _tags
                                        .map(
                                          (t) => InputChip(
                                            label: Text(t),
                                            onDeleted: () => setState(() {
                                              _tags.remove(t);
                                              _dirty = true;
                                            }),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'Attachments (${_attachments.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pickAttachment,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              isMobile
                                  ? 'Add file'
                                  : 'Add file  (Ctrl+Shift+A)',
                            ),
                          ),
                        ],
                      ),
                      if (_attachments.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _attachments.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final f = _attachments[i];
                              final isImage = _isImagePath(f.path);
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (isImage) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Scaffold(
                                              appBar: AppBar(
                                                title: Text(p.basename(f.path)),
                                              ),
                                              body: InteractiveViewer(
                                                child: Center(
                                                  child: Image.file(f),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        _openAttachmentExternally(f.path);
                                      }
                                    },
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: theme.dividerColor,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: isImage
                                          ? Image.file(f, fit: BoxFit.cover)
                                          : Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    _iconForPath(f.path),
                                                    size: 36,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    p.basename(f.path),
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () => _deleteAttachment(f),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Body (Markdown)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (showSplit)
                        SizedBox(
                          height: 600,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: TextField(
                                      controller: _bodyCtrl,
                                      maxLines: null,
                                      minLines: null,
                                      expands: true,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 15,
                                        height: 1.5,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Describe the bug...',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  color: theme.dividerColor,
                                ),
                                Expanded(
                                  child: RepaintBoundary(
                                    child: Container(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerLowest,
                                      padding: const EdgeInsets.all(24),
                                      child: SingleChildScrollView(
                                        child: _buildMarkdown(
                                          theme,
                                          _previewData,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (showPreviewOnly)
                        Container(
                          constraints: const BoxConstraints(minHeight: 400),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildMarkdown(theme, _previewData),
                        )
                      else if (showEditOnly)
                        TextField(
                          controller: _bodyCtrl,
                          maxLines: null,
                          minLines: 15,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            height: 1.5,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Describe the bug...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      if (!showSplit &&
                          showEditOnly &&
                          _attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Tap an attachment to insert a markdown reference:',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments
                              .map(
                                (f) => ActionChip(
                                  avatar: Icon(_iconForPath(f.path), size: 16),
                                  label: Text(
                                    p.basename(f.path),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () => _insertAttachmentMarkdown(f),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    return isMobile
        ? scaffold
        : _DesktopShortcuts(bindings: _buildShortcuts(), child: scaffold);
  }

  /// 用 markdown_widget 渲染 issue 正文。
  /// shrinkWrap + NeverScrollableScrollPhysics 是为了跟外层 SingleChildScrollView 共存。
  Widget _buildMarkdown(ThemeData theme, String data) {
    return MarkdownWidget(
      data: data.isEmpty ? '_No body yet._' : data,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      config: _buildMarkdownConfig(theme),
    );
  }

  /// 把 markdown_widget 的各种 Config 映射到跟之前 MarkdownStyleSheet 相近的样式。
  /// 结果按 ThemeData 缓存，避免每次重建重新构造一堆 TextStyle / BoxDecoration。
  MarkdownConfig _buildMarkdownConfig(ThemeData theme) {
    if (_cachedConfig != null && identical(_cachedTheme, theme)) {
      return _cachedConfig!;
    }
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    // 兜底：markdown_widget 的 Config 不接受 nullable TextStyle，
    // 部分主题（尤其自定义 TextTheme）可能未设置 heading 样式，用 const TextStyle() 兜底。
    final bodyLarge = textTheme.bodyLarge ?? const TextStyle();
    final h1Style = textTheme.headlineMedium ?? const TextStyle();
    final h2Style = textTheme.headlineSmall ?? const TextStyle();
    final h3Style = textTheme.titleLarge ?? const TextStyle();

    _cachedTheme = theme;
    _cachedConfig = MarkdownConfig(
      configs: [
        PConfig(textStyle: bodyLarge.copyWith(height: 1.6)),
        H1Config(
          style: h1Style.copyWith(fontWeight: FontWeight.bold, height: 1.4),
        ),
        H2Config(
          style: h2Style.copyWith(fontWeight: FontWeight.bold, height: 1.4),
        ),
        H3Config(
          style: h3Style.copyWith(fontWeight: FontWeight.bold, height: 1.4),
        ),
        CodeConfig(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.onSurface,
          ),
        ),
        PreConfig(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
        ),
        BlockquoteConfig(
          textColor: colorScheme.onSurfaceVariant,
          sideColor: colorScheme.primary,
        ),
        LinkConfig(
          style: TextStyle(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          onTap: _handleTapLink,
        ),
        ImgConfig(
          // markdown_widget 的 ImgConfig.builder 只接受两个参数：
          //   (String url, Map<String, String> attributes)
          // 不再有 title/alt 参数，属性都塞在 attributes 里。
          builder: (url, attributes) => _buildMarkdownImage(url, theme),
        ),
      ],
    );
    return _cachedConfig!;
  }

  /// 处理 markdown 里的图片引用。
  /// 网络图直接加载；本地路径先尝试解析出真实文件，
  /// 图片就内联预览，其它类型则渲染成一个可点击的 chip。
  Widget _buildMarkdownImage(String url, ThemeData theme) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url);
    }
    final file = _resolveAttachment(url);
    if (file == null) {
      return Text(
        '[missing: $url]',
        style: TextStyle(color: theme.colorScheme.error),
      );
    }
    if (_isImagePath(file.path)) {
      return Image.file(file);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: Icon(_iconForPath(file.path), size: 18),
        label: Text(p.basename(file.path)),
        onPressed: () => _openAttachmentExternally(file.path),
      ),
    );
  }

  /// 处理 markdown 里的普通链接。
  /// 外链不处理（让系统接管），本地相对路径则解析成附件并打开。
  void _handleTapLink(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return;
    }
    final file = _resolveAttachment(href);
    if (file != null) {
      _openAttachmentExternally(file.path);
    } else {
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('Attachment not found: $href')));
      showInfoToast('Attachment not found: $href');
    }
  }
}
