import 'package:flutter/material.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/adapters/download_chapter_matcher.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

Future<void> showDownloadDialog(
  BuildContext context,
  UnifiedComicDownloadInfo downloadInfo,
) {
  return showDialog(
    context: context,
    builder: (ctx) => _DownloadDialog(downloadInfo: downloadInfo),
  );
}

class _DownloadDialog extends StatefulWidget {
  final UnifiedComicDownloadInfo downloadInfo;
  const _DownloadDialog({required this.downloadInfo});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  late List<DownloadChapter> _chapters;
  late Map<String, bool> _selected;
  final Set<String> _downloadedIds = {};

  @override
  void initState() {
    super.initState();
    final source = (widget.downloadInfo.source.trim().isEmpty
            ? ''
            : widget.downloadInfo.source)
        .trim();
    const adapter = DownloadChapterAdapter();
    _chapters = widget.downloadInfo.chapters
        .map((chapter) => adapter.fromOnlineChapter(chapter))
        .toList();
    _selected = {for (final c in _chapters) c.id: false};

    final query = objectbox.unifiedDownloadBox.query(
      UnifiedComicDownload_.uniqueKey
          .equals('$source:${widget.downloadInfo.comicId}'),
    );
    final stored = query.build().findFirst();
    if (stored != null) {
      const matcher = DownloadChapterMatcher();
      final storedChapters = resolveDownloadChapters(stored);
      for (final chapter in _chapters) {
        final isDownloaded = storedChapters.any(
          (s) =>
              matcher.matches(s, chapter.id) || s.order == chapter.order,
        );
        if (isDownloaded) {
          _downloadedIds.add(chapter.id);
        }
      }
    }
    if (_chapters.isNotEmpty && !_downloadedIds.contains(_chapters.first.id)) {
      _selected[_chapters.first.id] = true;
    }
  }

  bool get isAllSelected =>
      _chapters.isNotEmpty && _chapters.every((c) => _selected[c.id] == true);

  int get selectedCount =>
      _chapters.where((c) => _selected[c.id] == true).length;

  void _toggleSelectAll() {
    setState(() {
      final v = !isAllSelected;
      for (final c in _chapters) {
        _selected[c.id] = v;
      }
    });
  }

  void _toggleOne(String id) {
    setState(() => _selected[id] = !(_selected[id] ?? false));
  }

  Future<void> _startDownload() async {
    final selectedChapters =
        _chapters.where((c) => _selected[c.id] == true).toList();
    if (selectedChapters.isEmpty) {
      showErrorToast(t.download.selectChaptersPrompt);
      return;
    }
    final source = (widget.downloadInfo.source.trim().isEmpty
            ? ''
            : widget.downloadInfo.source)
        .trim();
    final task = DownloadTaskJson(
      from: source,
      comicId: widget.downloadInfo.comicId,
      comicName: widget.downloadInfo.title,
      chapterRefs: selectedChapters
          .map(
            (chapter) => DownloadChapterTaskRef(
              chapterId: chapter.id,
              requestId: chapter.effectiveRequestId,
              storageChapterId: chapter.effectiveStorageId,
              logicalKey: chapter.id,
              title: chapter.displayName,
              order: chapter.order,
              extern: Map<String, dynamic>.from(chapter.extern),
            ),
          )
          .toList(),
    );
    try {
      final started = await startDownloadTask(task);
      if (!mounted) return;
      if (started) {
        showInfoToast(t.download.taskStarted);
        Navigator.of(context).pop();
      }
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      if (mounted) {
        showErrorToast(
          t.download.taskStartFailed(error: normalizeSearchErrorMessage(e)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.downloadInfo.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _toggleSelectAll,
                    icon: Icon(
                      isAllSelected ? Icons.deselect : Icons.select_all,
                      size: 18,
                    ),
                    label: Text(
                      isAllSelected
                          ? t.bookshelf.deselectAll
                          : t.common.selectAll,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                t.download.selectedChapters(
                  selected: selectedCount,
                  total: _chapters.length,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: _chapters.length,
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  final selected = _selected[chapter.id] ?? false;
                  final downloaded = _downloadedIds.contains(chapter.id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (_) => _toggleOne(chapter.id),
                    title: Text(
                      chapter.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: downloaded
                        ? Text(
                            '已下载',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.download.selectedChapters(
                        selected: selectedCount,
                        total: _chapters.length,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.common.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(t.download.startDownload),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
