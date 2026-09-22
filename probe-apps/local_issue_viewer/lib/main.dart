import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

/// 判断当前平台是否是移动端（Android / iOS），用于切换 AppBar / FAB 布局。
/// web 上 defaultTargetPlatform 也可能是 android/iOS，但我们要按桌面方式处理。
bool get _isMobilePlatform {
  if (kIsWeb) return false;
  final p = defaultTargetPlatform;
  return p == TargetPlatform.android || p == TargetPlatform.iOS;
}

/// 判断给定路径是否是常见图片格式。
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

/// 根据扩展名返回对应的 Material 图标。
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

/// 判断当前是否处于 macOS。因为 macOS 上习惯用 Cmd 而不是 Ctrl。
bool get _useMetaKey {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS;
}

/// 桌面端快捷键的包装器。用 CallbackShortcuts 让快捷键在整棵页面树里生效。
/// 需要 Focus(autofocus: true) 让页面在打开后立刻能响应键盘事件。
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

/// 单个 FAB 动作，用于速度拨号菜单。
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

/// 移动端可折叠的 FAB 组。
/// 折叠时只有一个主 FAB（menu 图标）；展开后从下往上依次显示子 FAB，
/// 每个子 FAB 右侧带一个小标签（inverseSurface 色），方便单手识读。
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
        // 子 FAB 列表：用 AnimatedSize + 条件渲染来做展开/折叠动画。
        // 子 FAB 从下往上排（reversed），离主 FAB 最近的放最下面。
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
                          // 标签气泡
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
          heroTag: 'main-fab',
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Self Bug Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      home: const IssueTrackerScreen(
        config: IssueTrackerConfig(scope: 'issue'),
      ),
    );
  }
}

/// 决定 issue 数据的落盘位置。
class IssueTrackerConfig {
  final String scope;
  final String? rootOverride;

  const IssueTrackerConfig({this.scope = 'issue', this.rootOverride});

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

/// 一条 issue 的内存模型。
class Issue {
  final Directory dir;
  String title;
  String body;
  bool done;
  int priority;
  List<String> tags;
  DateTime createdAt;
  List<File> attachments;

  Issue({
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

  /// 序列化回 markdown 格式。
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

/// 把 issue.md 的原始文本解析成 Issue 对象。
Issue parseIssue(Directory dir, String raw) {
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

  return Issue(
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

/// 负责 issue 的读取 / 创建 / 保存。
class IssueStore {
  final IssueTrackerConfig config;
  IssueStore(this.config);

  Future<Directory> root() async {
    final dir = await config.resolveRoot();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Issue>> loadAll() async {
    final dir = await root();
    final result = <Issue>[];
    await for (final e in dir.list()) {
      if (e is! Directory) continue;
      final md = File(p.join(e.path, 'issue.md'));
      if (!await md.exists()) continue;
      result.add(parseIssue(e, await md.readAsString()));
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<Issue> create({
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

    final issue = Issue(
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

  Future<void> save(Issue issue) async {
    await issue.mdFile.writeAsString(issue.toMarkdown());
  }
}

/// 列表页的分组模式。
enum GroupMode { status, priority, tags, date }

extension GroupModeX on GroupMode {
  String get label => switch (this) {
    GroupMode.status => 'By Status',
    GroupMode.priority => 'By Priority',
    GroupMode.tags => 'By Tags',
    GroupMode.date => 'By Date',
  };

  IconData get icon => switch (this) {
    GroupMode.status => Icons.rule,
    GroupMode.priority => Icons.sort,
    GroupMode.tags => Icons.label_outline,
    GroupMode.date => Icons.calendar_today,
  };
}

class IssueSection {
  final String title;
  final List<Issue> issues;
  bool expanded;
  IssueSection({
    required this.title,
    required this.issues,
    this.expanded = true,
  });
}

/// 按指定维度把 issue 列表分成若干 section。
List<IssueSection> groupIssues(List<Issue> all, GroupMode mode) {
  switch (mode) {
    case GroupMode.status:
      final open = all.where((i) => !i.done).toList();
      final done = all.where((i) => i.done).toList();
      return [
        if (open.isNotEmpty)
          IssueSection(title: 'Open (${open.length})', issues: open),
        if (done.isNotEmpty)
          IssueSection(
            title: 'Done (${done.length})',
            issues: done,
            expanded: false,
          ),
      ];

    case GroupMode.priority:
      final buckets = <String, List<Issue>>{
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
        return IssueSection(
          title: '${e.key} — ${e.value.length}',
          issues: e.value,
        );
      }).toList();

    case GroupMode.tags:
      final map = <String, List<Issue>>{};
      for (final i in all) {
        final tag = i.tags.isNotEmpty ? i.tags.first : 'Untagged';
        map.putIfAbsent(tag, () => []).add(i);
      }
      final sections = map.entries
          .map(
            (e) => IssueSection(
              title: '#${e.key} (${e.value.length})',
              issues: e.value,
            ),
          )
          .toList();
      sections.sort((a, b) => b.issues.length.compareTo(a.issues.length));
      return sections;

    case GroupMode.date:
      final now = DateTime.now();
      final today = <Issue>[],
          week = <Issue>[],
          month = <Issue>[],
          older = <Issue>[];
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
          IssueSection(title: 'Today (${today.length})', issues: today),
        if (week.isNotEmpty)
          IssueSection(title: 'This Week (${week.length})', issues: week),
        if (month.isNotEmpty)
          IssueSection(title: 'This Month (${month.length})', issues: month),
        if (older.isNotEmpty)
          IssueSection(title: 'Older (${older.length})', issues: older),
      ];
  }
}

/// 列表页：搜索、过滤、分组、折叠、新建。
class IssueTrackerScreen extends StatefulWidget {
  final IssueTrackerConfig config;
  const IssueTrackerScreen({super.key, required this.config});

  @override
  State<IssueTrackerScreen> createState() => _IssueTrackerScreenState();
}

class _IssueTrackerScreenState extends State<IssueTrackerScreen> {
  late final IssueStore _store = IssueStore(widget.config);
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<Issue> _all = [];
  bool _loading = true;
  String _query = '';
  GroupMode _mode = GroupMode.status;
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

  List<Issue> get _filtered {
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

  Future<void> _openIssue(Issue issue) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => IssueDetailScreen(
          issue: issue,
          store: _store,
          allTags: _allTags.toList(),
        ),
        transitionsBuilder: (_, anim, __, child) =>
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
          children: GroupMode.values
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

  /// 桌面端快捷键绑定。
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
    final sections = groupIssues(filtered, _mode);
    final isMobile = _isMobilePlatform;

    for (final sec in sections) {
      if (!_expandedSections.containsKey(sec.title)) {
        _expandedSections[sec.title] = sec.expanded;
      }
      sec.expanded = _expandedSections[sec.title]!;
    }

    final body = Scaffold(
      appBar: AppBar(
        title: const Text('Issues'),
        // 移动端：AppBar 只留标题，所有操作都移到右下角的 FAB 组。
        // 桌面端：保留右上角图标按钮，并配合键盘快捷键使用。
        actions: isMobile
            ? null
            : [
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: isMobile
                    ? 'grep title / body / tags...'
                    : 'grep title / body / tags...  (Ctrl+F)',
                border: const OutlineInputBorder(),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${filtered.length} issue(s)',
                  style: theme.textTheme.bodyMedium?.copyWith(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sections.length,
                    itemBuilder: (_, si) {
                      final s = sections[si];
                      return _SectionView(
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

    // 桌面端包一层快捷键。
    return isMobile
        ? body
        : _DesktopShortcuts(bindings: _buildShortcuts(), child: body);
  }
}

class _SectionView extends StatelessWidget {
  final IssueSection section;
  final VoidCallback onToggle;
  final void Function(Issue) onIssueTap;
  const _SectionView({
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
            (i) => _IssueTile(issue: i, onTap: () => onIssueTap(i)),
          ),
      ],
    );
  }
}

class _IssueTile extends StatelessWidget {
  final Issue issue;
  final VoidCallback onTap;
  const _IssueTile({required this.issue, required this.onTap});

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

enum ViewMode { split, edit, preview }

/// 详情页：编辑标题、优先级、标签、附件和正文，并实时预览 markdown。
class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  final IssueStore store;
  final List<String> allTags;
  const IssueDetailScreen({
    super.key,
    required this.issue,
    required this.store,
    required this.allTags,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _tagCtrl;

  late bool _done;
  late double _priority;
  late List<String> _tags;
  late List<File> _attachments;

  ViewMode _viewMode = ViewMode.split;
  bool _dirty = false;

  Timer? _debounce;
  late String _previewData;
  final Map<String, File?> _resolveCache = {};
  bool _showAutocomplete = false;

  MarkdownStyleSheet? _cachedStyle;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved'),
        duration: Duration(milliseconds: 700),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;

    final dir = widget.issue.attachmentsDir;
    if (!await dir.exists()) await dir.create(recursive: true);

    final added = <File>[];
    for (final f in files) {
      final srcPath = f.path;
      if (srcPath == null) continue;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('File not found: $absPath')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved at: $absPath')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open: $e')));
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
      if (_viewMode == ViewMode.split) {
        _viewMode = ViewMode.edit;
      } else if (_viewMode == ViewMode.edit) {
        _viewMode = ViewMode.preview;
      } else {
        _viewMode = ViewMode.split;
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

  /// 桌面端快捷键绑定。
  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    final ctrl = _useMetaKey;
    return {
      // 保存
      SingleActivator(LogicalKeyboardKey.keyS, control: !ctrl, meta: ctrl):
          _save,
      // 切换视图模式
      SingleActivator(LogicalKeyboardKey.keyE, control: !ctrl, meta: ctrl):
          _cycleViewMode,
      // 切换 done 状态
      SingleActivator(LogicalKeyboardKey.keyD, control: !ctrl, meta: ctrl):
          _toggleDone,
      // 添加附件
      SingleActivator(
        LogicalKeyboardKey.keyA,
        control: !ctrl,
        meta: ctrl,
        shift: true,
      ): _pickAttachment,
      // Esc 返回
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
          // 移动端：隐藏所有按钮，全部交给底部的 FAB 组。
          // 桌面端：保留图标按钮并加上快捷键提示。
          actions: isMobile
              ? null
              : [
                  IconButton(
                    tooltip: 'View mode  (Ctrl+E)',
                    icon: Icon(
                      _viewMode == ViewMode.split
                          ? Icons.splitscreen
                          : _viewMode == ViewMode.edit
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
        // 移动端 FAB 组：把原本在 AppBar 的操作都放到右手拇指自然落点上。
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
                    icon: _viewMode == ViewMode.split
                        ? Icons.splitscreen
                        : _viewMode == ViewMode.edit
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
            final showSplit = isWide && _viewMode == ViewMode.split;
            final showPreviewOnly = _viewMode == ViewMode.preview;
            final showEditOnly =
                _viewMode == ViewMode.edit || (!isWide && !showPreviewOnly);

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
                            separatorBuilder: (_, __) =>
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

  Widget _buildMarkdown(ThemeData theme, String data) {
    return MarkdownBody(
      data: data.isEmpty ? '_No body yet._' : data,
      styleSheet: _buildMarkdownStyle(theme),
      imageBuilder: (uri, title, alt) {
        final s = uri.toString();
        if (s.startsWith('http://') || s.startsWith('https://')) {
          return Image.network(s);
        }
        final file = _resolveAttachment(uri.path);
        if (file == null) {
          return Text(
            '[missing: ${uri.path}]',
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
      },
      onTapLink: (text, href, title) {
        if (href == null) return;
        if (href.startsWith('http://') || href.startsWith('https://')) {
          return;
        }
        final file = _resolveAttachment(href);
        if (file != null) {
          _openAttachmentExternally(file.path);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attachment not found: $href')),
          );
        }
      },
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    if (_cachedStyle != null && identical(_cachedTheme, theme)) {
      return _cachedStyle!;
    }
    _cachedTheme = theme;
    _cachedStyle = MarkdownStyleSheet(
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      h1: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        color: theme.colorScheme.onSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(50),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      listBullet: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      a: TextStyle(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
    return _cachedStyle!;
  }
}
