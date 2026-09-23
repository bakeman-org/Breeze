import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/page/changelog/local_issue/github_issue_client.dart';
import 'package:zephyr/page/changelog/local_issue/github_settings_dialog.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue_config.dart';
import 'package:zephyr/page/changelog/local_issue/local_issue_store.dart';
import 'package:zephyr/page/changelog/widgets/local_issue_tracker_tab.dart'
    show DesktopShortcuts, FabAction, FabGroup;
import 'package:zephyr/widgets/toast.dart';

enum _LocalViewMode { split, edit, preview }

/// 详情页：独立路由 push 出来，所以这里保留完整 Scaffold + AppBar。
class LocalIssueDetailScreen extends StatefulWidget {
  final LocalIssue issue;
  final LocalIssueStore store;
  final List<String> allTags;

  /// 可选：外部注入 GitHub client。不传时会现场 `GitHubIssueClient()`，
  /// 从 [GitHubSettings.I] 读取 owner / repo / token。
  final GitHubIssueClient? github;

  const LocalIssueDetailScreen({
    super.key,
    required this.issue,
    required this.store,
    required this.allTags,
    this.github,
  });

  @override
  State<LocalIssueDetailScreen> createState() => _LocalIssueDetailScreenState();
}

class _LocalIssueDetailScreenState extends State<LocalIssueDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _tagCtrl;

  late bool _done;
  late double _priority;
  late List<String> _tags;
  late List<File> _attachments;

  _LocalViewMode _viewMode = _LocalViewMode.split;
  bool _dirty = false;

  /// 任意远端操作（post / close / reopen）正在进行。
  bool _remoteBusy = false;

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
    showInfoToast('Issue saved');
  }

  // ─────────────────────── 附件 ───────────────────────

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

  // ─────────────────────── 标签 ───────────────────────

  void _addTag() {
    final t = _tagCtrl.text.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) {
      setState(() => _tags.add(t));
      _dirty = true;
    }
    _tagCtrl.clear();
  }

  // ─────────────────────── 附件路径解析 ───────────────────────

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
    final insertion = isImagePath(f.path)
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

  // ─────────────────────── 打开外部 ───────────────────────

  Future<void> _openAttachmentExternally(String absPath) async {
    final file = File(absPath);
    if (!await file.exists()) {
      if (!mounted) return;
      showInfoToast('File not found: $absPath');
      return;
    }
    await _openPathExternally(absPath);
  }

  Future<void> _openUrlExternally(String url) => _openPathExternally(url);

  Future<void> _openPathExternally(String target) async {
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [target]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [target]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', target]);
      } else {
        if (!mounted) return;
        showInfoToast('Open: $target');
      }
    } catch (e) {
      if (!mounted) return;
      showInfoToast('Could not open: $e');
    }
  }

  // ─────────────────────── 离开 / 视图 / 状态 ───────────────────────

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

  // ─────────────────────── GitHub 远端 ───────────────────────

  /// 确保拿到一个配置好的 client；没配置就弹设置对话框让用户填。
  /// 返回 null 表示用户没配置成功（取消或仍为空）。
  Future<GitHubIssueClient?> _ensureGitHubClient() async {
    var gh = widget.github ?? GitHubIssueClient();
    if (gh.isConfigured) return gh;

    await showGitHubSettingsDialog(context);
    if (!mounted) return null;

    gh = widget.github ?? GitHubIssueClient();
    if (!gh.isConfigured) {
      showInfoToast('GitHub 仍未配置');
      return null;
    }
    return gh;
  }

  Future<void> _postToGitHub() async {
    final posted = widget.issue.githubNumber != null;

    // 已推送 —— 直接打开链接（这也呼应 toolbar 上的「cloud_done」按钮）。
    if (posted) {
      final url = widget.issue.githubUrl;
      if (url != null) {
        await _openUrlExternally(url);
      } else {
        showInfoToast('Already posted as #${widget.issue.githubNumber}');
      }
      return;
    }

    final gh = await _ensureGitHubClient();
    if (gh == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post to GitHub?'),
        content: Text('This will create an issue in ${gh.owner}/${gh.repo}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _remoteBusy = true);
    try {
      await _save();
      final updated = await gh.postIssue(widget.issue);
      await widget.store.save(updated);
      if (!mounted) return;
      setState(() {
        _remoteBusy = false;
        _dirty = false;
      });
      showInfoToast(
        'Posted: ${updated.githubUrl ?? '#${updated.githubNumber}'}',
      );
    } on GitHubIssueException catch (e) {
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast('Post failed: $e');
    }
  }

  Future<void> _closeRemote() async {
    final n = widget.issue.githubNumber;
    if (n == null) return;
    final gh = await _ensureGitHubClient();
    if (gh == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close remote issue?'),
        content: Text('Will close #$n on ${gh.owner}/${gh.repo}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _remoteBusy = true);
    try {
      await gh.closeIssue(n);
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast('Closed #$n on GitHub');
    } on GitHubIssueException catch (e) {
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast('Close failed: $e');
    }
  }

  Future<void> _reopenRemote() async {
    final n = widget.issue.githubNumber;
    if (n == null) return;
    final gh = await _ensureGitHubClient();
    if (gh == null || !mounted) return;

    setState(() => _remoteBusy = true);
    try {
      await gh.reopenIssue(n);
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast('Reopened #$n on GitHub');
    } on GitHubIssueException catch (e) {
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _remoteBusy = false);
      showInfoToast('Reopen failed: $e');
    }
  }

  // ─────────────────────── 快捷键 ───────────────────────

  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    final ctrl = useMetaKey;
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
      SingleActivator(
        LogicalKeyboardKey.keyP,
        control: !ctrl,
        meta: ctrl,
        shift: true,
      ): _postToGitHub,
      const SingleActivator(LogicalKeyboardKey.escape): _confirmLeave,
    };
  }

  // ─────────────────────── build ───────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = isMobilePlatform;

    final posted = widget.issue.githubNumber != null;

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
                  if (posted) ...[
                    IconButton(
                      tooltip: 'Open #${widget.issue.githubNumber} on GitHub',
                      icon: const Icon(Icons.cloud_done_outlined),
                      onPressed: _remoteBusy ? null : _postToGitHub,
                    ),
                    IconButton(
                      tooltip: 'Close #${widget.issue.githubNumber} on GitHub',
                      icon: const Icon(Icons.cloud_off_outlined),
                      onPressed: _remoteBusy ? null : _closeRemote,
                    ),
                    IconButton(
                      tooltip: 'Reopen #${widget.issue.githubNumber} on GitHub',
                      icon: const Icon(Icons.cloud_sync_outlined),
                      onPressed: _remoteBusy ? null : _reopenRemote,
                    ),
                  ] else
                    IconButton(
                      tooltip: 'Post to GitHub  (Ctrl+Shift+P)',
                      icon: _remoteBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      onPressed: _remoteBusy ? null : _postToGitHub,
                    ),
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
            ? FabGroup(
                actions: [
                  if (posted) ...[
                    FabAction(
                      icon: Icons.cloud_done_outlined,
                      label: 'Open on GitHub',
                      onPressed: _postToGitHub,
                    ),
                    FabAction(
                      icon: Icons.cloud_off_outlined,
                      label: 'Close on GitHub',
                      onPressed: _closeRemote,
                    ),
                    FabAction(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Reopen on GitHub',
                      onPressed: _reopenRemote,
                    ),
                  ] else
                    FabAction(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Post to GitHub',
                      onPressed: _postToGitHub,
                    ),
                  FabAction(
                    icon: Icons.save,
                    label: _dirty ? 'Save *' : 'Save',
                    onPressed: _save,
                  ),
                  FabAction(
                    icon: _done
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    label: _done ? 'Reopen' : 'Close as done',
                    onPressed: _toggleDone,
                  ),
                  FabAction(
                    icon: _viewMode == _LocalViewMode.split
                        ? Icons.splitscreen
                        : _viewMode == _LocalViewMode.edit
                        ? Icons.edit
                        : Icons.visibility,
                    label: 'View: ${_viewMode.name}',
                    onPressed: _cycleViewMode,
                  ),
                  FabAction(
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
                                                  (textEditingValue) {
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
                                              onSelected: (selection) {
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
                                if (posted) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.cloud_done_outlined,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Mirrored as '
                                          '#${widget.issue.githubNumber}',
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (widget.issue.githubUrl != null)
                                        TextButton(
                                          onPressed: () => _openUrlExternally(
                                            widget.issue.githubUrl!,
                                          ),
                                          child: const Text('Open'),
                                        ),
                                    ],
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
                              final isImage = isImagePath(f.path);
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
                                                    iconForPath(f.path),
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
                                  avatar: Icon(iconForPath(f.path), size: 16),
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
        : DesktopShortcuts(bindings: _buildShortcuts(), child: scaffold);
  }

  // ─────────────────────── Markdown ───────────────────────

  Widget _buildMarkdown(ThemeData theme, String data) {
    return MarkdownWidget(
      data: data.isEmpty ? '_No body yet._' : data,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      config: _buildMarkdownConfig(theme),
    );
  }

  MarkdownConfig _buildMarkdownConfig(ThemeData theme) {
    if (_cachedConfig != null && identical(_cachedTheme, theme)) {
      return _cachedConfig!;
    }
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
          builder: (url, attributes) => _buildMarkdownImage(url, theme),
        ),
      ],
    );
    return _cachedConfig!;
  }

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
    if (isImagePath(file.path)) {
      return Image.file(file);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: Icon(iconForPath(file.path), size: 18),
        label: Text(p.basename(file.path)),
        onPressed: () => _openAttachmentExternally(file.path),
      ),
    );
  }

  void _handleTapLink(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      _openUrlExternally(href);
      return;
    }
    final file = _resolveAttachment(href);
    if (file != null) {
      _openAttachmentExternally(file.path);
    } else {
      showInfoToast('Attachment not found: $href');
    }
  }
}
