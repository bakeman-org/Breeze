import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zephyr/page/changelog/local_issue/github_issue_client.dart';
import 'package:zephyr/page/changelog/local_issue/github_settings.dart';
import 'package:zephyr/page/changelog/local_issue/github_settings_dialog.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue_config.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue_detail_screen.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue_grouping.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue_store.dart';
import 'package:zephyr/page/changelog/local_issue/remote_issue.dart';
import 'package:zephyr/page/changelog/widgets/remote_issues_list.dart';
import 'package:zephyr/page/changelog/widgets/search_input.dart';

// ─────────────────────────────── 通用小组件 ───────────────────────────────

/// 桌面端快捷键包装：整棵子树用 Focus(autofocus) + CallbackShortcuts 挂键盘事件。
class DesktopShortcuts extends StatelessWidget {
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;
  const DesktopShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(bindings: bindings, child: child),
    );
  }
}

/// 单个 FAB 动作。
class FabAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const FabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// 移动端速度拨号 FAB 组。
class FabGroup extends StatefulWidget {
  final List<FabAction> actions;
  const FabGroup({super.key, required this.actions});

  @override
  State<FabGroup> createState() => _FabGroupState();
}

class _FabGroupState extends State<FabGroup> {
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

// ─────────────────────────────── 主 Tab ───────────────────────────────

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

  // 本地
  List<LocalIssue> _all = [];
  bool _loading = true;

  // 远端
  List<RemoteIssue> _remote = [];
  bool _remoteLoading = false;
  String? _remoteError;
  bool _remoteExpanded = true;

  // 来源开关
  bool _showLocal = true;
  bool _showRemote = true;

  // 过滤 / 分组
  String _query = '';
  LocalGroupMode _mode = LocalGroupMode.status;
  String? _statusFilter;
  final Set<String> _tagFilter = {};
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await GitHubSettings.I.load();
    await _reload();
    if (GitHubSettings.I.isConfigured) {
      await _loadRemote();
    }
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

  Future<void> _loadRemote() async {
    if (!GitHubSettings.I.isConfigured) {
      if (!mounted) return;
      setState(() {
        _remote = [];
        _remoteError = null;
        _remoteLoading = false;
      });
      return;
    }
    setState(() {
      _remoteLoading = true;
      _remoteError = null;
    });
    try {
      final list = await GitHubIssueClient().listIssues(state: 'all');
      if (!mounted) return;
      setState(() {
        _remote = list;
        _remoteLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _remoteLoading = false;
        _remoteError = '$e';
      });
    }
  }

  Future<void> _openRemoteIssue(RemoteIssue issue) async {
    if (issue.htmlUrl.isEmpty) return;
    try {
      if (await canLaunchUrl(Uri.parse(issue.htmlUrl))) {
        await launchUrl(
          Uri.parse(issue.htmlUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {}
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

  /// 远端列表也应用搜索词（不应用 status / tag 过滤，因为语义不同）。
  List<RemoteIssue> get _filteredRemote {
    if (_query.isEmpty) return _remote;
    final q = _query.toLowerCase();
    return _remote
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              r.body.toLowerCase().contains(q) ||
              r.labels.any((l) => l.toLowerCase().contains(q)),
        )
        .toList();
  }

  Set<String> get _allTags => _all.expand((i) => i.tags).toSet();

  // ───────────────────────── 交互 ─────────────────────────

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
        pageBuilder: (_, __, ___) => LocalIssueDetailScreen(
          issue: issue,
          store: _store,
          allTags: _allTags.toList(),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    await _reload();
    // 详情页里可能 push 了远端 issue，顺带刷新远端列表。
    if (GitHubSettings.I.isConfigured) {
      _loadRemote();
    }
  }

  Future<void> _openSettings() async {
    await showGitHubSettingsDialog(context);
    if (!mounted) return;
    await _loadRemote();
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
    final ctrl = useMetaKey;
    return {
      SingleActivator(LogicalKeyboardKey.keyN, control: !ctrl, meta: ctrl):
          _createIssue,
      SingleActivator(LogicalKeyboardKey.keyF, control: !ctrl, meta: ctrl): () {
        _searchFocus.requestFocus();
      },
      SingleActivator(
        LogicalKeyboardKey.keyR,
        control: !ctrl,
        meta: ctrl,
      ): () async {
        await _reload();
        await _loadRemote();
      },
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

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final filteredRemote = _filteredRemote;
    final sections = groupLocalIssues(filtered, _mode);
    final isMobile = isMobilePlatform;
    final ghConfigured = GitHubSettings.I.isConfigured;

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
          SearchInput(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            hintText: isMobile
                ? 'grep title / body / tags...'
                : 'grep title / body / tags...  (Ctrl+F)',
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            onChanged: (v) => setState(() => _query = v),
            trailing: isMobile
                ? const []
                : [
                    IconButton(
                      tooltip: 'GitHub 设置',
                      icon: Badge(
                        isLabelVisible: ghConfigured,
                        smallSize: 8,
                        child: const Icon(Icons.cloud_outlined),
                      ),
                      onPressed: _openSettings,
                    ),
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
                      onPressed: () async {
                        await _reload();
                        await _loadRemote();
                      },
                    ),
                  ],
          ),

          // 来源开关（只有配置了 GitHub 才显示）
          if (ghConfigured)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: Text('Local (${filtered.length})'),
                      selected: _showLocal,
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      onSelected: (v) => setState(() => _showLocal = v),
                    ),
                    FilterChip(
                      label: Text('GitHub (${filteredRemote.length})'),
                      selected: _showRemote,
                      avatar: const Icon(Icons.cloud_outlined, size: 16),
                      onSelected: (v) => setState(() => _showRemote = v),
                    ),
                  ],
                ),
              ),
            ),

          _LocalIssueCountRow(
            count: filtered.length,
            statusFilter: _statusFilter,
            tagFilter: _tagFilter,
            onClearStatus: () => setState(() => _statusFilter = null),
            onRemoveTag: (t) => setState(() => _tagFilter.remove(t)),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _reload();
                      await _loadRemote();
                    },
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_showLocal)
                          if (sections.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: Text('No local issues')),
                            )
                          else
                            for (final s in sections)
                              _LocalSectionView(
                                section: s,
                                onToggle: () {
                                  setState(() {
                                    _expandedSections[s.title] = !s.expanded;
                                    s.expanded = _expandedSections[s.title]!;
                                  });
                                },
                                onIssueTap: _openIssue,
                              ),
                        if (ghConfigured && _showRemote)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RemoteIssuesSection(
                              issues: filteredRemote,
                              expanded: _remoteExpanded,
                              loading: _remoteLoading,
                              error: _remoteError,
                              onToggle: () => setState(
                                () => _remoteExpanded = !_remoteExpanded,
                              ),
                              onOpen: _openRemoteIssue,
                              onRefresh: _loadRemote,
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FabGroup(
              actions: [
                FabAction(
                  icon: Icons.add,
                  label: 'New issue',
                  onPressed: _createIssue,
                ),
                FabAction(
                  icon: Icons.cloud_outlined,
                  label: 'GitHub 设置',
                  onPressed: _openSettings,
                ),
                FabAction(
                  icon: _mode.icon,
                  label: _mode.label,
                  onPressed: _showGroupPicker,
                ),
                FabAction(
                  icon: Icons.filter_alt_outlined,
                  label: 'Filters',
                  onPressed: _showFilters,
                ),
                FabAction(
                  icon: Icons.folder_outlined,
                  label: 'Storage',
                  onPressed: _showStorageInfo,
                ),
                FabAction(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  onPressed: () async {
                    await _reload();
                    await _loadRemote();
                  },
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
        : DesktopShortcuts(bindings: _buildShortcuts(), child: body);
  }
}

// ─────────────────────────────── 数量 + 过滤 chip ───────────────────────────────

class _LocalIssueCountRow extends StatelessWidget {
  final int count;
  final String? statusFilter;
  final Set<String> tagFilter;
  final VoidCallback onClearStatus;
  final ValueChanged<String> onRemoveTag;

  const _LocalIssueCountRow({
    required this.count,
    required this.statusFilter,
    required this.tagFilter,
    required this.onClearStatus,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '$count local issue(s)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (statusFilter != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(
                label: Text('status: $statusFilter'),
                onDeleted: onClearStatus,
              ),
            ),
          for (final t in tagFilter)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Chip(label: Text('#$t'), onDeleted: () => onRemoveTag(t)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── 本地列表项 ───────────────────────────────

class _LocalSectionView extends StatelessWidget {
  final LocalIssueSection section;
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
              // 本地 issue 的「已同步到 GitHub」标识
              if (issue.githubNumber != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 14,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '#${issue.githubNumber}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
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
