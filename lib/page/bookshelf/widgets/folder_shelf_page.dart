import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/bookshelf/bloc/folder_shelf_bloc.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/method/method.dart';
import 'package:zephyr/page/bookshelf/models/shelf_group_mode.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/service/comic_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_empty_view.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_grid_shimmer.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_loading_view.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_item.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_grouping.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_grid.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';
import 'package:zephyr/widgets/toast.dart';

class FolderShelfPage extends StatelessWidget {
  const FolderShelfPage({
    super.key,
    required this.mode,
    this.refreshSignal = 0,
    this.isActive = true,
  });

  final ShelfPageMode mode;
  final int refreshSignal;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // 用 watch 订阅 BookshelfSearchCubit：search 变化时自动 rebuild，
    // 触发 didUpdateWidget → 重新派发 FolderShelfLoadRequested。
    final search = context.watch<BookshelfSearchCubit>().state.stateOf(mode);
    return BlocProvider(
      create: (_) =>
          FolderShelfBloc(mode: mode)
            ..add(FolderShelfLoadRequested(search: search)),
      child: _FolderShelfPageContent(
        refreshSignal: refreshSignal,
        search: search,
        isActive: isActive,
      ),
    );
  }
}

class _FolderShelfPageContent extends StatefulWidget {
  const _FolderShelfPageContent({
    required this.refreshSignal,
    required this.search,
    required this.isActive,
  });

  final int refreshSignal;
  final SearchStatusState search;
  final bool isActive;

  @override
  State<_FolderShelfPageContent> createState() =>
      _FolderShelfPageContentState();
}

class _FolderShelfPageContentState extends State<_FolderShelfPageContent>
    with AutomaticKeepAliveClientMixin {
  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  // 分组视图的滚动控制 + 每个分组 header 的 GlobalKey + 当前激活组。
  final _groupScrollController = ScrollController();
  final Map<String, GlobalKey> _groupHeaderKeys = {};
  String? _activeGroup;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _groupScrollController.addListener(_onGroupScrollChanged);
    if (_isDesktop) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void dispose() {
    _groupScrollController.removeListener(_onGroupScrollChanged);
    _groupScrollController.dispose();
    if (_isDesktop) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!mounted || !widget.isActive) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;

    final bloc = context.read<FolderShelfBloc>();
    if (bloc.state.isRoot) return false;

    bloc.add(const FolderShelfGoBack());
    return true;
  }

  @override
  void didUpdateWidget(covariant _FolderShelfPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal ||
        oldWidget.search != widget.search) {
      context.read<FolderShelfBloc>().add(
        FolderShelfLoadRequested(search: widget.search),
      );
    }
  }

  // ===================== 分组 sidebar 相关 =====================

  void _onGroupScrollChanged() {
    if (!_groupScrollController.hasClients) return;
    final scrollOffset = _groupScrollController.offset;
    String? nextActive;
    for (final entry in _groupHeaderKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      final offsetToReveal = viewport.getOffsetToReveal(box, 0).offset;
      // 用 64 像素做容差：header 快滚入视口顶部时就算作当前组。
      if (offsetToReveal <= scrollOffset + 64) {
        nextActive = entry.key;
      } else {
        break;
      }
    }
    if (nextActive != _activeGroup) {
      setState(() => _activeGroup = nextActive);
    }
  }

  void _jumpToGroup(String group) {
    final key = _groupHeaderKeys[group];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// sidebar 上每个组名显示的短标签，按分组模式自适应。
  String _sidebarLabel(String groupName, ShelfGroupMode mode) {
    switch (mode) {
      case ShelfGroupMode.byTitle:
        // 单字符，直接用。
        return groupName;
      case ShelfGroupMode.bySource:
        // 取来源名前两个字符，避免 sidebar 过宽。
        if (groupName.length <= 2) return groupName;
        return groupName.substring(0, 2);
      case ShelfGroupMode.byDate:
        // "2024-09-22" → "09-22"
        if (groupName.length >= 10) return groupName.substring(5);
        return groupName;
      case ShelfGroupMode.none:
        return groupName;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<FolderShelfBloc, FolderShelfState>(
      listenWhen: (previous, current) =>
          current.error != null && current.error != previous.error,
      listener: (context, state) {
        final error = state.error;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: state.isRoot,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !state.isRoot) {
              context.read<FolderShelfBloc>().add(const FolderShelfGoBack());
            }
          },
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(child: _buildBody(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<FolderShelfBloc, FolderShelfState>(
      builder: (context, state) {
        return Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SafeArea(
            bottom: false,
            child: state.selectionMode
                ? _buildSelectionHeader(context, state)
                : _buildNormalHeader(context, state),
          ),
        );
      },
    );
  }

  Widget _buildNormalHeader(BuildContext context, FolderShelfState state) {
    final showGroupButton =
        state.mode == ShelfPageMode.download && state.isRoot;

    return Row(
      children: [
        IconButton(
          icon: Icon(state.isRoot ? Icons.help_outline : Icons.arrow_back),
          tooltip: state.isRoot ? t.bookshelf.folderHint : t.common.back,
          onPressed: state.isRoot
              ? () => _showShelfHelpDialog(context)
              : () => context.read<FolderShelfBloc>().add(
                  const FolderShelfGoBack(),
                ),
        ),
        Expanded(
          child: Text(
            state.breadcrumbTitle,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.home),
          onPressed: state.isRoot
              ? null
              : () => context.read<FolderShelfBloc>().add(
                  const FolderShelfGoHome(),
                ),
        ),
        if (showGroupButton) _buildGroupModeButton(context),
        FluentPopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'new_folder':
                _showCreateFolderDialog(context);
              case 'manage':
                context.read<FolderShelfBloc>().add(
                  const FolderShelfEnterSelectionMode(),
                );
              case 'import':
                _importComic(context);
            }
          },
          itemBuilder: (context) => [
            FluentPopupMenuItem(
              value: 'new_folder',
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(t.bookshelf.newFolder),
            ),
            FluentPopupMenuItem(
              value: 'manage',
              leading: const Icon(Icons.checklist),
              title: Text(t.bookshelf.manage),
            ),
            if (state.mode == ShelfPageMode.download)
              FluentPopupMenuItem(
                value: 'import',
                leading: const Icon(Icons.file_download_outlined),
                title: Text(t.bookshelf.importComic),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupModeButton(BuildContext context) {
    return BlocBuilder<BookshelfSearchCubit, BookshelfSearchState>(
      builder: (context, searchState) {
        final current = searchState.stateOf(ShelfPageMode.download).groupMode;
        return FluentPopupMenuButton<ShelfGroupMode>(
          icon: Icon(_groupModeIcon(current)),
          tooltip: t.bookshelf.groupBy,
          onSelected: (mode) {
            context.read<BookshelfSearchCubit>().setGroupMode(
              ShelfPageMode.download,
              mode,
            );
          },
          itemBuilder: (context) => [
            FluentPopupMenuItem(
              value: ShelfGroupMode.none,
              leading: const Icon(Icons.grid_view),
              title: Text(t.bookshelf.groupNone),
            ),
            FluentPopupMenuItem(
              value: ShelfGroupMode.bySource,
              leading: const Icon(Icons.source_outlined),
              title: Text(t.bookshelf.groupBySource),
            ),
            FluentPopupMenuItem(
              value: ShelfGroupMode.byTitle,
              leading: const Icon(Icons.sort_by_alpha),
              title: Text(t.bookshelf.groupByTitle),
            ),
            FluentPopupMenuItem(
              value: ShelfGroupMode.byDate,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(t.bookshelf.groupByDate),
            ),
          ],
        );
      },
    );
  }

  static IconData _groupModeIcon(ShelfGroupMode mode) {
    return switch (mode) {
      ShelfGroupMode.none => Icons.grid_view,
      ShelfGroupMode.bySource => Icons.source_outlined,
      ShelfGroupMode.byTitle => Icons.sort_by_alpha,
      ShelfGroupMode.byDate => Icons.calendar_month_outlined,
    };
  }

  Future<void> _showShelfHelpDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.bookshelf.folderHint),
        content: Text(t.bookshelf.helpContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.gotIt),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(BuildContext context, FolderShelfState state) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.read<FolderShelfBloc>().add(
            const FolderShelfExitSelectionMode(),
          ),
        ),
        Expanded(
          child: Text(
            t.bookshelf.selectedCount(count: state.selectedCount),
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          child: _SelectionActionStrip(
            children: [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: t.common.selectAll,
                onPressed: () => context.read<FolderShelfBloc>().add(
                  const FolderShelfSelectAll(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.drive_file_move_outline),
                tooltip: t.bookshelf.moveTo,
                onPressed: state.hasSelection
                    ? () => _showTargetFolderDialog(
                        context,
                        onConfirmed: (targets) {
                          context.read<FolderShelfBloc>().add(
                            FolderShelfMoveSelected(targets),
                          );
                        },
                      )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.folder_copy_outlined),
                tooltip: t.bookshelf.copyTo,
                onPressed: state.hasSelection
                    ? () => _showTargetFolderDialog(
                        context,
                        onConfirmed: (targets) {
                          context.read<FolderShelfBloc>().add(
                            FolderShelfCopySelected(targets),
                          );
                        },
                      )
                    : null,
              ),
              if (state.mode == ShelfPageMode.download)
                IconButton(
                  icon: const Icon(Icons.file_upload_outlined),
                  tooltip: t.bookshelf.batchExport,
                  onPressed: state.hasSelection
                      ? () => _batchExportSelected(context, state)
                      : null,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: t.common.delete,
                onPressed: state.hasSelection
                    ? () => _confirmDeleteSelected(context)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<BookshelfSearchCubit, BookshelfSearchState>(
      builder: (context, searchState) {
        return BlocBuilder<FolderShelfBloc, FolderShelfState>(
          builder: (context, state) {
            final modeState = searchState.stateOf(state.mode);
            final keyword = _normalizeSearchText(modeState.keyword);
            final groupMode = modeState.groupMode;

            // 搜索时只展示漫画，不展示文件夹。
            final filteredFolders = keyword.isEmpty
                ? state.folders
                : <ComicFolder>[];
            final filteredComics = keyword.isEmpty
                ? state.comics
                : state.comics.where((c) {
                    final key = '${c.from.trim()}:${c.id}';
                    final searchText = state.comicSearchTexts[key] ?? '';
                    return searchText.contains(keyword);
                  }).toList();

            final totalCount = filteredFolders.length + filteredComics.length;
            final isInitialLoading = state.isLoading && totalCount == 0;

            if (isInitialLoading) {
              return const Stack(
                children: [
                  BookshelfGridShimmer(),
                  Center(child: BookshelfLoadingView()),
                ],
              );
            }

            if (totalCount == 0) {
              return BookshelfEmptyView(
                onRefresh: () => context.read<FolderShelfBloc>().add(
                  const FolderShelfLoadRequested(),
                ),
              );
            }

            // 只在下载 tab 根目录、未搜索、选定了分组模式时启用分组视图。
            final useGrouping =
                groupMode != ShelfGroupMode.none &&
                state.mode == ShelfPageMode.download &&
                state.isRoot &&
                keyword.isEmpty;

            if (useGrouping) {
              return _buildGroupedView(
                context,
                state: state,
                groupMode: groupMode,
                comics: filteredComics,
              );
            }

            return _buildGridView(
              context,
              state: state,
              filteredFolders: filteredFolders,
              filteredComics: filteredComics,
            );
          },
        );
      },
    );
  }

  // ============ 普通网格视图 ============

  Widget _buildGridView(
    BuildContext context, {
    required FolderShelfState state,
    required List<ComicFolder> filteredFolders,
    required List<ComicSimplifyEntryInfo> filteredComics,
  }) {
    final comicType = _comicEntryTypeOf(state.mode);
    final folderSyncIdMap = _buildSyncIdMap(state.mode);
    String folderPathOf(ComicFolder f) =>
        ComicFolderService.folderPath(f, syncIdMap: folderSyncIdMap);
    final totalCount = filteredFolders.length + filteredComics.length;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
      },
      child: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: buildComicSimplifyEntryGridDelegate(),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index < filteredFolders.length) {
                final folder = filteredFolders[index];
                final folderPath = folderPathOf(folder);
                final isSelected = state.selectedFolderPaths.contains(
                  folderPath,
                );
                return FolderShelfItem(
                  key: ValueKey('folder-${folder.uniqueKey}'),
                  folder: folder,
                  selectionMode: state.selectionMode,
                  isSelected: isSelected,
                  onTap: state.selectionMode
                      ? () => context.read<FolderShelfBloc>().add(
                          FolderShelfToggleFolderSelection(folderPath),
                        )
                      : () => context.read<FolderShelfBloc>().add(
                          FolderShelfEnterFolder(folderPath),
                        ),
                  onLongPress: state.selectionMode
                      ? (details) => context.read<FolderShelfBloc>().add(
                          FolderShelfToggleFolderSelection(folderPath),
                        )
                      : (details) => _showFolderActions(
                          context,
                          folder,
                          folderPath,
                          details.globalPosition,
                        ),
                  onSecondaryTapDown: state.selectionMode
                      ? null
                      : (details) => _showFolderActions(
                          context,
                          folder,
                          folderPath,
                          details.globalPosition,
                        ),
                );
              }
              final comicIndex = index - filteredFolders.length;
              final comic = filteredComics[comicIndex];
              return _buildComicEntry(
                context,
                state: state,
                comic: comic,
                comicType: comicType,
              );
            },
          ),
          if (state.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  // ============ 分组视图 ============

  Widget _buildGroupedView(
    BuildContext context, {
    required FolderShelfState state,
    required ShelfGroupMode groupMode,
    required List<ComicSimplifyEntryInfo> comics,
  }) {
    final grouping = groupDownloadComics(
      comics: comics,
      mode: groupMode,
      comicDownloadDates: state.comicDownloadDates,
    );
    final comicType = _comicEntryTypeOf(state.mode);

    // 同步 header keys 到当前顺序（Dart Map 保持插入顺序）。
    final nextKeys = <String, GlobalKey>{};
    for (final name in grouping.order) {
      nextKeys[name] = _groupHeaderKeys[name] ?? GlobalKey();
    }
    _groupHeaderKeys
      ..clear()
      ..addAll(nextKeys);
    if (_activeGroup != null && !grouping.order.contains(_activeGroup)) {
      _activeGroup = null;
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
      },
      child: Stack(
        children: [
          CustomScrollView(
            controller: _groupScrollController,
            slivers: [
              for (final groupName in grouping.order) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    // ✅ header 挂 GlobalKey，供 sidebar 跳转与滚动高亮使用。
                    key: _groupHeaderKeys[groupName],
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            groupName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${grouping.items[groupName]!.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  sliver: SliverGrid.builder(
                    gridDelegate: buildComicSimplifyEntryGridDelegate(),
                    itemCount: grouping.items[groupName]!.length,
                    itemBuilder: (context, index) {
                      final comic = grouping.items[groupName]![index];
                      return _buildComicEntry(
                        context,
                        state: state,
                        comic: comic,
                        comicType: comicType,
                      );
                    },
                  ),
                ),
              ],
              // 底部留一点空间，避免最后一行被 sidebar 遮挡。
              const SliverToBoxAdapter(child: SizedBox(height: 72)),
            ],
          ),

          // ✅ 右侧分组 sidebar
          if (grouping.order.length > 1)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ShelfGroupSidebar(
                  groups: grouping.order,
                  active: _activeGroup,
                  labelBuilder: (g) => _sidebarLabel(g, groupMode),
                  onTap: _jumpToGroup,
                ),
              ),
            ),

          if (state.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  /// 抽取的 comic 条目构建，供网格/分组视图共用。
  Widget _buildComicEntry(
    BuildContext context, {
    required FolderShelfState state,
    required ComicSimplifyEntryInfo comic,
    required ComicEntryType comicType,
  }) {
    final comicUniqueKey = '${comic.from.trim()}:${comic.id}';
    final isComicSelected = state.selectedComicKeys.contains(comicUniqueKey);
    return ComicSimplifyEntry(
      key: ValueKey('comic-${comic.from}:${comic.id}'),
      info: comic,
      type: comicType,
      selectionMode: state.selectionMode,
      isSelected: isComicSelected,
      refresh: () =>
          context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested()),
      onTapOverride: state.selectionMode
          ? (info) => context.read<FolderShelfBloc>().add(
              FolderShelfToggleComicSelection('${info.from.trim()}:${info.id}'),
            )
          : null,
      onLongPressOverride: state.selectionMode
          ? (info, details) => context.read<FolderShelfBloc>().add(
              FolderShelfToggleComicSelection('${info.from.trim()}:${info.id}'),
            )
          : (info, details) =>
                _showComicActions(context, info, details.globalPosition),
      onSecondaryTapDown: state.selectionMode
          ? null
          : (info, details) =>
                _showComicActions(context, info, details.globalPosition),
    );
  }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.bookshelf.createFolder),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: t.bookshelf.folderName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(dialogContext).pop(text);
                }
              },
              child: Text(t.common.ok),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<FolderShelfBloc>().add(FolderShelfCreateFolder(name));
    }
  }

  void _showFolderActions(
    BuildContext context,
    ComicFolder folder,
    String folderPath,
    Offset position,
  ) {
    final anchor = Rect.fromCenter(center: position, width: 1, height: 1);

    FluentPopupMenu.show<String>(
      context: context,
      anchor: anchor,
      items: [
        FluentPopupMenuItem(
          value: 'multi_select',
          leading: const Icon(Icons.checklist),
          title: Text(t.bookshelf.multiSelect),
        ),
        FluentPopupMenuItem(
          value: 'rename',
          leading: const Icon(Icons.drive_file_rename_outline),
          title: Text(t.common.rename),
        ),
        FluentPopupMenuItem(
          value: 'move',
          leading: const Icon(Icons.drive_file_move_outline),
          title: Text(t.bookshelf.moveTo),
        ),
        FluentPopupMenuItem(
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: Text(t.common.delete),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'multi_select':
            context.read<FolderShelfBloc>().add(
              FolderShelfToggleFolderSelection(folderPath),
            );
          case 'rename':
            _showRenameFolderDialog(context, folder, folderPath);
          case 'move':
            unawaited(
              _showTargetFolderDialog(
                context,
                selectedFolderPaths: {folderPath},
                onConfirmed: (targets) {
                  context.read<FolderShelfBloc>().add(
                    FolderShelfMoveSelected(
                      targets,
                      sourceFolderPaths: {folderPath},
                    ),
                  );
                },
              ),
            );
          case 'delete':
            _confirmDeleteSingleFolder(context, folderPath);
        }
      },
    );
  }

  Future<void> _confirmDeleteSingleFolder(
    BuildContext context,
    String path,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.bookshelf.confirmDeleteFolderTitle),
          content: Text(t.bookshelf.confirmDeleteFolderContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.common.delete),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      context.read<FolderShelfBloc>().add(FolderShelfDeleteFolder(path));
    }
  }

  Future<void> _showRenameFolderDialog(
    BuildContext context,
    ComicFolder folder,
    String folderPath,
  ) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.bookshelf.renameFolder),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: t.common.rename),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(dialogContext).pop(text);
                }
              },
              child: Text(t.common.ok),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<FolderShelfBloc>().add(
        FolderShelfRenameFolder(folderPath, name),
      );
    }
  }

  static ComicEntryType _comicEntryTypeOf(ShelfPageMode mode) {
    return switch (mode) {
      ShelfPageMode.favorite => ComicEntryType.favorite,
      ShelfPageMode.history => ComicEntryType.history,
      ShelfPageMode.download => ComicEntryType.download,
    };
  }

  static String _normalizeSearchText(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return '';
    try {
      return t2s(lower);
    } catch (_) {
      return lower;
    }
  }

  void _showComicActions(
    BuildContext context,
    ComicSimplifyEntryInfo info,
    Offset position,
  ) {
    final anchor = Rect.fromCenter(center: position, width: 1, height: 1);

    FluentPopupMenu.show<String>(
      context: context,
      anchor: anchor,
      items: [
        FluentPopupMenuItem(
          value: 'multi_select',
          leading: const Icon(Icons.checklist),
          title: Text(t.bookshelf.multiSelect),
        ),
        FluentPopupMenuItem(
          value: 'delete',
          leading: const Icon(Icons.delete_outline),
          title: Text(t.common.delete),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'multi_select':
            context.read<FolderShelfBloc>().add(
              FolderShelfToggleComicSelection('${info.from.trim()}:${info.id}'),
            );
          case 'delete':
            _confirmRemoveComic(context, info);
        }
      },
    );
  }

  Future<void> _confirmRemoveComic(
    BuildContext context,
    ComicSimplifyEntryInfo info,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.bookshelf.confirmRemoveComicTitle),
          content: Text(
            t.bookshelf.confirmRemoveComicContent(title: info.title),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.common.remove),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      final uniqueKey = '${info.from.trim()}:${info.id}';
      final state = context.read<FolderShelfBloc>().state;
      final folderType = switch (state.mode) {
        ShelfPageMode.favorite => ComicFolderType.favorite,
        ShelfPageMode.download => ComicFolderType.download,
        ShelfPageMode.history => ComicFolderType.history,
      };
      ComicLinkService.removeComic(
        uniqueKey,
        state.currentPath.isEmpty ? null : state.currentPath,
        folderType,
      );
      context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
    }
  }
}

// ==================== 分组 sidebar ====================

class _ShelfGroupSidebar extends StatelessWidget {
  const _ShelfGroupSidebar({
    required this.groups,
    required this.active,
    required this.onTap,
    required this.labelBuilder,
  });

  final List<String> groups;
  final String? active;
  final ValueChanged<String> onTap;
  final String Function(String) labelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 44,
      // 最多占屏高 60%，超出则 sidebar 内部滚动。
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in groups)
              InkWell(
                onTap: () => onTap(g),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 36,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    labelBuilder(g),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: g == active
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: g == active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== 选择操作条 ====================

class _SelectionActionStrip extends StatefulWidget {
  const _SelectionActionStrip({required this.children});

  final List<Widget> children;

  @override
  State<_SelectionActionStrip> createState() => _SelectionActionStripState();
}

class _SelectionActionStripState extends State<_SelectionActionStrip> {
  static const _scrollHintWidth = 32.0;

  final _scrollController = ScrollController();
  bool _hasOverflow = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleOverflowCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final hasOverflow = _scrollController.position.maxScrollExtent > 0.5;
      if (hasOverflow != _hasOverflow) {
        setState(() => _hasOverflow = hasOverflow);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleOverflowCheck();
    final surface = Theme.of(context).colorScheme.surface;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(left: _hasOverflow ? _scrollHintWidth : 0),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.children,
            ),
          ),
        ),
        if (_hasOverflow)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SizedBox(
                width: _scrollHintWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [surface, surface.withValues(alpha: 0)],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.swipe_left, size: 20)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== 目标文件夹选择 ====================

Future<void> _showTargetFolderDialog(
  BuildContext context, {
  Set<String>? selectedFolderPaths,
  required ValueChanged<Set<String>> onConfirmed,
}) async {
  final state = context.read<FolderShelfBloc>().state;
  final sourceFolderPaths = selectedFolderPaths ?? state.selectedFolderPaths;
  final allFolders = ComicFolderService.listAllFolders(
    _folderTypeOf(state.mode),
  );
  final syncIdMap = _buildSyncIdMap(state.mode);
  final pathMap = {
    for (final folder in allFolders)
      folder.syncId: ComicFolderService.folderPath(
        folder,
        syncIdMap: syncIdMap,
      ),
  };
  final forest = _buildFolderForest(allFolders, pathMap);

  final forbiddenSyncIds = <String>{};
  for (final path in sourceFolderPaths) {
    final folder = allFolders.firstWhereOrNull(
      (f) => pathMap[f.syncId] == path,
    );
    if (folder != null) {
      _collectForbiddenSyncIds(folder.syncId, allFolders, forbiddenSyncIds);
    }
  }
  final currentPath = state.currentPath;
  final isRoot = currentPath.isEmpty;
  final currentFolder = isRoot
      ? null
      : allFolders.firstWhereOrNull((f) => pathMap[f.syncId] == currentPath);
  final currentSyncId = currentFolder?.syncId;

  final selectedPaths = <String>{};

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final expandedPaths = <String>{};
      return StatefulBuilder(
        builder: (ctx, setState) {
          void togglePath(String path) {
            setState(() {
              if (selectedPaths.contains(path)) {
                selectedPaths.remove(path);
              } else {
                selectedPaths.add(path);
              }
            });
          }

          return AlertDialog(
            title: Text(t.bookshelf.selectTargetFolder),
            content: SizedBox(
              width: 380,
              height: 400,
              child: ListView(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const SizedBox(width: 48),
                    title: Text(t.common.root),
                    trailing: Checkbox(
                      value: selectedPaths.contains(kComicFolderRootPath),
                      onChanged: isRoot
                          ? null
                          : (_) => togglePath(kComicFolderRootPath),
                    ),
                    onTap: isRoot
                        ? null
                        : () => togglePath(kComicFolderRootPath),
                  ),
                  const Divider(),
                  ...forest.map(
                    (node) => _buildFolderTreeTile(
                      context: ctx,
                      node: node,
                      pathMap: pathMap,
                      expandedPaths: expandedPaths,
                      forbiddenSyncIds: forbiddenSyncIds,
                      currentSyncId: currentSyncId,
                      selectedPaths: selectedPaths,
                      onToggleExpand: (path) => setState(() {
                        if (expandedPaths.contains(path)) {
                          expandedPaths.remove(path);
                        } else {
                          expandedPaths.add(path);
                        }
                      }),
                      onSelect: togglePath,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(t.common.cancel),
              ),
              FilledButton(
                onPressed: selectedPaths.isEmpty
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        onConfirmed(selectedPaths);
                      },
                child: Text(t.common.ok),
              ),
            ],
          );
        },
      );
    },
  );
}

class _FolderNode {
  final ComicFolder folder;
  final List<_FolderNode> children;

  _FolderNode(this.folder) : children = [];
}

List<_FolderNode> _buildFolderForest(
  List<ComicFolder> folders,
  Map<String, String> pathMap,
) {
  final sorted = folders.toList()
    ..sort(
      (a, b) => (pathMap[a.syncId] ?? '').compareTo(pathMap[b.syncId] ?? ''),
    );
  final map = <String, _FolderNode>{};
  final roots = <_FolderNode>[];
  for (final folder in sorted) {
    final node = _FolderNode(folder);
    map[folder.syncId] = node;
    final parentSyncId = folder.parentSyncId;
    if (parentSyncId == null || parentSyncId.isEmpty) {
      roots.add(node);
    } else {
      map[parentSyncId]?.children.add(node);
    }
  }
  return roots;
}

Map<String, ComicFolder> _buildSyncIdMap(ShelfPageMode mode) {
  final allFolders = ComicFolderService.listAllFolders(_folderTypeOf(mode));
  return {for (final folder in allFolders) folder.syncId: folder};
}

void _collectForbiddenSyncIds(
  String syncId,
  List<ComicFolder> allFolders,
  Set<String> result,
) {
  if (!result.add(syncId)) return;
  for (final child in allFolders) {
    if (child.parentSyncId == syncId) {
      _collectForbiddenSyncIds(child.syncId, allFolders, result);
    }
  }
}

Widget _buildFolderTreeTile({
  required BuildContext context,
  required _FolderNode node,
  required Map<String, String> pathMap,
  required Set<String> expandedPaths,
  required Set<String> forbiddenSyncIds,
  required String? currentSyncId,
  required Set<String> selectedPaths,
  required ValueChanged<String> onToggleExpand,
  required ValueChanged<String> onSelect,
}) {
  final path = pathMap[node.folder.syncId] ?? '/${node.folder.name}';
  final syncId = node.folder.syncId;
  final isExpanded = expandedPaths.contains(path);
  final isCurrentPath = currentSyncId != null && syncId == currentSyncId;
  final isForbidden = isCurrentPath || forbiddenSyncIds.contains(syncId);
  final hasChildren = node.children.isNotEmpty;
  final theme = Theme.of(context);
  final isSelected = selectedPaths.contains(path) && !isForbidden;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: hasChildren
            ? IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                ),
                onPressed: () => onToggleExpand(path),
              )
            : const SizedBox(width: 48),
        title: Text(
          node.folder.name,
          style: isForbidden ? TextStyle(color: theme.disabledColor) : null,
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: isForbidden ? null : (_) => onSelect(path),
        ),
        onTap: isForbidden ? null : () => onSelect(path),
      ),
      if (isExpanded)
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: node.children
                .map(
                  (child) => _buildFolderTreeTile(
                    context: context,
                    node: child,
                    pathMap: pathMap,
                    expandedPaths: expandedPaths,
                    forbiddenSyncIds: forbiddenSyncIds,
                    currentSyncId: currentSyncId,
                    selectedPaths: selectedPaths,
                    onToggleExpand: onToggleExpand,
                    onSelect: onSelect,
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
}

ComicFolderType _folderTypeOf(ShelfPageMode mode) {
  return switch (mode) {
    ShelfPageMode.favorite => ComicFolderType.favorite,
    ShelfPageMode.download => ComicFolderType.download,
    ShelfPageMode.history => ComicFolderType.history,
  };
}

// ==================== 导入 / 导出 / 删除 ====================

Future<void> _importComic(BuildContext context) async {
  String? importRoot;
  String? cleanupDir;
  try {
    if (Platform.isAndroid) {
      importRoot = await pickComicZipAndroid();
      if (importRoot != null) {
        cleanupDir = p.dirname(p.dirname(importRoot));
      }
    } else {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'zip',
            extensions: ['zip'],
            uniformTypeIdentifiers: ['public.zip-archive'],
          ),
        ],
      );
      importRoot = file?.path;
    }
    if (importRoot == null || importRoot.trim().isEmpty) return;

    if (!context.mounted) return;
    showSuccessToast(t.bookshelf.importStarted);

    final result = await importComicFromZip(
      importRoot,
      cleanupDir: cleanupDir,
      onConfirmOverwrite: (title) =>
          _confirmComicImportOverwrite(context, title),
    );

    if (!context.mounted) return;
    showSuccessToast(t.bookshelf.importCompleted(title: result.title));
    context.read<FolderShelfBloc>().add(const FolderShelfLoadRequested());
  } on ComicImportCancelledException catch (_) {
    if (!context.mounted) return;
    showErrorToast(t.common.cancelled);
  } catch (e) {
    if (!context.mounted) return;
    showErrorToast(t.error.importFailed(error: e.toString()));
  }
}

Future<bool> _confirmComicImportOverwrite(
  BuildContext context,
  String title,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.bookshelf.comicExists),
      content: Text(t.bookshelf.confirmOverwriteImport(title: title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.common.overwrite),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _batchExportSelected(
  BuildContext context,
  FolderShelfState state,
) async {
  final selectedComics = state.comics
      .where(
        (c) => state.selectedComicKeys.contains('${c.from.trim()}:${c.id}'),
      )
      .toList();

  if (selectedComics.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.bookshelf.noExportableComics)));
    return;
  }

  try {
    final success = await batchExportComics(
      context: context,
      comics: selectedComics,
    );
    if (!context.mounted) return;
    showSuccessToast(
      t.bookshelf.batchExportCompleted(
        success: success,
        total: selectedComics.length,
      ),
    );
    context.read<FolderShelfBloc>().add(const FolderShelfExitSelectionMode());
  } catch (e) {
    if (!context.mounted) return;
    showErrorToast(t.bookshelf.batchExportFailed(error: e.toString()));
  }
}

Future<void> _confirmDeleteSelected(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(t.bookshelf.confirmDeleteSelectedTitle),
        content: Text(t.bookshelf.confirmDeleteSelectedContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.common.delete),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) {
    context.read<FolderShelfBloc>().add(const FolderShelfDeleteSelected());
  }
}
