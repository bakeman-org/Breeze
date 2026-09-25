import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/adapters/download_chapter_matcher.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/page/download/widgets/eps.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class DownloadPage extends StatefulWidget {
  final UnifiedComicDownloadInfo downloadInfo;

  const DownloadPage({super.key, required this.downloadInfo});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  UnifiedComicDownloadInfo get downloadInfo => widget.downloadInfo;
  String get source =>
      (downloadInfo.source.trim().isEmpty ? '' : downloadInfo.source).trim();

  late List<DownloadChapter> _chapters;
  late Map<String, bool> _downloadInfo;
  final Set<String> _downloadedChapterIds = <String>{};
  late UnifiedComicDownload? comicDownloadInfo;

  void onUpdateDownloadInfo(String selectionKey) {
    setState(() {
      _downloadInfo[selectionKey] = !(_downloadInfo[selectionKey] ?? false);
    });
  }

  @override
  void initState() {
    super.initState();
    if (source.isEmpty) {
      throw StateError('download source pluginId is required');
    }

    const adapter = DownloadChapterAdapter();
    _chapters = downloadInfo.chapters
        .map((chapter) => adapter.fromOnlineChapter(chapter))
        .toList();

    _downloadInfo = {};
    for (final chapter in _chapters) {
      _downloadInfo[chapter.id] = false;
    }

    final query = objectbox.unifiedDownloadBox.query(
      UnifiedComicDownload_.uniqueKey.equals('$source:${downloadInfo.comicId}'),
    );
    comicDownloadInfo = query.build().findFirst();
    if (comicDownloadInfo != null) {
      final storedChapters = resolveDownloadChapters(comicDownloadInfo!);
      const matcher = DownloadChapterMatcher();
      for (final chapter in _chapters) {
        final isDownloaded = storedChapters.any(
          (stored) =>
              matcher.matches(stored, chapter.id) ||
              stored.order == chapter.order,
        );
        _downloadInfo[chapter.id] = isDownloaded;
        if (isDownloaded) {
          _downloadedChapterIds.add(chapter.id);
        }
      }
    }
    // ✅ Default select 第1话 (only if it hasn't already been downloaded)
    if (_chapters.isNotEmpty) {
      final firstChapterId = _chapters.first.id;
      if (_downloadInfo[firstChapterId] != true) {
        _downloadInfo[firstChapterId] = true;
      }
    }
  }

  // 判断是否所有章节都被选中
  bool get isAllSelected {
    return _chapters.every((chapter) => _downloadInfo[chapter.id] == true);
  }

  int get selectedCount {
    return _chapters.where((chapter) => _downloadInfo[chapter.id] == true).length;
  }

  // 切换全选或取消全选
  void toggleSelectAll() {
    setState(() {
      bool newState = !isAllSelected;
      for (final chapter in _chapters) {
        _downloadInfo[chapter.id] = newState;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leftHandMode = context
        .watch<GlobalSettingCubit>()
        .state
        .leftHandModeEnabled;
    return MiuixScaffold(
      topBar: MiuixSmallTopAppBar(
        title: downloadInfo.title,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
        actions: [
          MiuixIconButton(
            onPressed: toggleSelectAll,
            child: Icon(isAllSelected ? Icons.deselect : Icons.select_all),
          ),
        ],
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: padding.copyWith(bottom: 24),
              children: [
                MiuixSmallTitle(
                  t.download.selectedChapters(
                    selected: selectedCount,
                    total: _chapters.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MiuixCard(
                    child: Column(
                      children: [
                        for (var index = 0; index < _chapters.length; index++) ...[
                          if (index > 0) const MiuixHorizontalDivider(),
                          EpsWidget(
                            chapter: _chapters[index],
                            selected:
                                _downloadInfo[_chapters[index].id] ?? false,
                            downloaded: _downloadedChapterIds.contains(
                              _chapters[index].id,
                            ),
                            onUpdateDownloadInfo: onUpdateDownloadInfo,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomBar: _buildBottomBar(context, leftHandMode),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool leftHandMode) {
    final theme = Theme.of(context);
    final miuixColors = MiuixTheme.of(context).colors;
    final button = MiuixButton(
      onPressed: download,
      colors: MiuixButtonDefaults.buttonColorsPrimary(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download, size: 18, color: miuixColors.onPrimary),
          const SizedBox(width: 8),
          Text(t.download.startDownload),
        ],
      ),
    );
    final summary = Text(
      t.download.selectedChapters(
        selected: selectedCount,
        total: _chapters.length,
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: leftHandMode
                    ? [
                        button,
                        const SizedBox(width: 12),
                        Expanded(child: summary),
                      ]
                    : [
                        Expanded(child: summary),
                        const SizedBox(width: 12),
                        button,
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> download() async {
    final selectedChapters = _chapters
        .where((chapter) => _downloadInfo[chapter.id] == true)
        .toList();
    if (selectedChapters.isEmpty) {
      showErrorToast(t.download.selectChaptersPrompt);
      return;
    }
    final task = DownloadTaskJson(
      from: source,
      comicId: downloadInfo.comicId,
      comicName: downloadInfo.title,
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
    logger.d('download task payload=${task.toJson()}');
    try {
      final started = await startDownloadTask(task);
      if (started) {
        showInfoToast(t.download.taskStarted);
      }
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      showErrorToast(
        t.download.taskStartFailed(error: normalizeSearchErrorMessage(e)),
      );
    }
  }
}
