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

import 'package:zephyr/page/comments/widgets/title.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    // Miuix 迁移：Scaffold + AppBar → MiuixScaffold + 自绘顶栏
    // （保留 ScrollableTitle 跑马灯）；全选切换、下载逻辑不变。
    return MiuixScaffold(
      topBar: Material(
        color: colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      MiuixIconButton(
                        onPressed: () => context.maybePop(),
                        child: const Icon(Icons.arrow_back),
                      ),
                      Expanded(child: ScrollableTitle(text: downloadInfo.title)),
                      MiuixIconButton(
                        onPressed: toggleSelectAll,
                        child: Icon(
                          isAllSelected ? Icons.deselect : Icons.select_all,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  88,
                ), // reserved bottom padding for FAB
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: EpsWidget(
                      chapter: chapter,
                      downloaded: _downloadInfo[chapter.id] ?? false,
                      onUpdateDownloadInfo: onUpdateDownloadInfo,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonPosition: leftHandMode
          ? MiuixFabPosition.start
          : MiuixFabPosition.end,
      floatingActionButton: MiuixFloatingActionButton(
        onPressed: () {
          logger.d("开始下载");
          download();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download),
            const SizedBox(width: 8),
            Text(t.download.startDownload),
          ],
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
      await startDownloadTask(task);
      showInfoToast(t.download.taskStarted);
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      showErrorToast(
        t.download.taskStartFailed(error: normalizeSearchErrorMessage(e)),
      );
    }
  }
}
