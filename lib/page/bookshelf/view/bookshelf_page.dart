import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/bookshelf.dart' hide SearchEnter;
import 'package:zephyr/page/bookshelf/service/download_folder_service.dart';
import 'package:zephyr/page/bookshelf/service/favorite_folder_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

@RoutePage()
class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bookshelfSetting = context
        .read<GlobalSettingCubit>()
        .state
        .bookshelfSetting;
    return MultiBlocProvider(
      providers: [
        BlocProvider<BookshelfSearchCubit>(
          create: (context) => BookshelfSearchCubit(
            favorite: SearchStatusState(
              sort: bookshelfSetting.rememberFavoriteSort
                  ? bookshelfSetting.favoriteSort
                  : 'dd',
            ),
            history: SearchStatusState(
              sort: bookshelfSetting.rememberHistorySort
                  ? bookshelfSetting.historySort
                  : 'dd',
            ),
            download: SearchStatusState(
              sort: bookshelfSetting.rememberDownloadSort
                  ? bookshelfSetting.downloadSort
                  : 'dd',
            ),
          ),
        ),
      ],
      child: _BookshelfPageContent(
        initialIndex: bookshelfSetting.homePageIndex,
      ),
    );
  }
}

class _BookshelfPageContent extends StatefulWidget {
  const _BookshelfPageContent({required this.initialIndex});

  final int initialIndex;

  @override
  State<_BookshelfPageContent> createState() => _BookshelfPageContentState();
}

class _BookshelfPageContentState extends State<_BookshelfPageContent>
    with SingleTickerProviderStateMixin {
  late final List<String> _labels = [
    t.bookshelf.favorite,
    t.bookshelf.history,
    t.bookshelf.download,
  ];

  late int _currentIndex;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final List<int> _refreshSignals = [0, 0, 0];
  List<String> _lastAvailableSources = const <String>[];
  bool _isSearchExpanded = false;

  // 搜索输入防抖
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _labels.length - 1);
    _tabController = TabController(
      initialIndex: _currentIndex,
      length: _labels.length,
      vsync: this,
    )..addListener(_handleTabControllerChanged);
    _syncSourcesFromRegistry(context.read<PluginRegistryCubit>().state);
    _syncSearchFieldWithCurrentMode();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController
      ..removeListener(_handleTabControllerChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    // 桌面端搜索框常驻（原桌面 AppBar 布局语义）；移动端点搜索图标展开。
    final showSearchField = isDesktop || _isSearchExpanded;

    return BlocListener<PluginRegistryCubit, Map<String, PluginRuntimeState>>(
      listenWhen: (previous, current) =>
          _pluginAvailabilityRevision(previous) !=
          _pluginAvailabilityRevision(current),
      listener: (context, pluginStates) {
        _syncSourcesFromRegistry(pluginStates);
        _triggerRefreshAll();
      },
      // Miuix 迁移：Scaffold + AppBar(自绘 tabs/搜索头) → MiuixScaffold +
      // MiuixSmallTopAppBar + MiuixTabRowWithContour。三页签、搜索防抖、
      // 筛选弹窗、刷新信号等行为全部保持不变。
      child: MiuixScaffold(
        topBar: MiuixSmallTopAppBar(
          title: t.navigation.bookshelf,
          actions: [
            if (!isDesktop)
              Tooltip(
                message: t.bookshelf.searchList,
                child: MiuixIconButton(
                  onPressed: () =>
                      setState(() => _isSearchExpanded = !_isSearchExpanded),
                  child: Icon(_isSearchExpanded ? Icons.close : Icons.search),
                ),
              ),
            Tooltip(
              message: t.bookshelf.filter,
              child: MiuixIconButton(
                onPressed: _openFilter,
                child: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
        content: (padding) => Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: MiuixTabRowWithContour(
                    tabs: _labels,
                    selectedTabIndex: _currentIndex,
                    onTabSelected: _onTabChanged,
                  ),
                ),
                if (showSearchField)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _buildSearchField(),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      FolderShelfPage(
                        mode: ShelfPageMode.favorite,
                        refreshSignal: _refreshSignals[0],
                        isActive: _currentIndex == 0,
                      ),
                      LocalShelfPage(
                        mode: ShelfPageMode.history,
                        refreshSignal: _refreshSignals[1],
                      ),
                      FolderShelfPage(
                        mode: ShelfPageMode.download,
                        refreshSignal: _refreshSignals[2],
                        isActive: _currentIndex == 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 列表内搜索框（Miuix 迁移版）。
  ///
  /// 行为与旧版一致：
  ///   - 输入 250ms 防抖后写入 [BookshelfSearchCubit] 并刷新列表；
  ///   - 提交（键盘搜索键）立即生效；
  ///   - 非空时显示清空按钮，点击后立即重置并刷新。
  Widget _buildSearchField() {
    return m.Material(
      type: m.MaterialType.transparency,
      child: MiuixTextField(
        controller: _searchController,
        singleLine: true,
        textInputAction: TextInputAction.search,
        label: t.bookshelf.searchList,
        useLabelAsPlaceholder: true,
        leadingIcon: const Icon(Icons.search, size: 18),
        trailingIcon: _searchController.text.isEmpty
            ? null
            : MiuixIconButton(
                minWidth: 28,
                minHeight: 28,
                onPressed: () {
                  _searchDebounce?.cancel();
                  _searchController.clear();
                  _setKeyword('');
                  _triggerRefresh(goTop: true);
                  setState(() {});
                },
                child: const Icon(Icons.close, size: 16),
              ),
        onChanged: (value) {
          setState(() {});
          // 250ms 防抖：避免每次按键都触发 worker 往返。
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _setKeyword(value.trim());
            _triggerRefresh(goTop: true);
          });
        },
        onSubmitted: (value) {
          _searchDebounce?.cancel();
          _setKeyword(value.trim());
          _triggerRefresh(goTop: true);
        },
      ),
    );
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    _tabController.animateTo(index);
  }

  void _handleTabControllerChanged() {
    if (!mounted || _currentIndex == _tabController.index) {
      return;
    }
    setState(() {
      _currentIndex = _tabController.index;
      _syncSearchFieldWithCurrentMode();
    });
  }

  void _syncSearchFieldWithCurrentMode() {
    final keyword = _currentSearchState().keyword;
    _searchController.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
  }

  ShelfPageMode _currentMode() {
    return switch (_currentIndex) {
      0 => ShelfPageMode.favorite,
      1 => ShelfPageMode.history,
      2 => ShelfPageMode.download,
      _ => ShelfPageMode.favorite,
    };
  }

  void _maybePersistSort(ShelfPageMode mode, String sort) {
    final cubit = context.read<GlobalSettingCubit>();
    final setting = cubit.state.bookshelfSetting;
    final shouldPersist = switch (mode) {
      ShelfPageMode.favorite => setting.rememberFavoriteSort,
      ShelfPageMode.history => setting.rememberHistorySort,
      ShelfPageMode.download => setting.rememberDownloadSort,
    };
    if (!shouldPersist) return;
    cubit.updateBookshelfSetting(
      (current) => switch (mode) {
        ShelfPageMode.favorite => current.copyWith(favoriteSort: sort),
        ShelfPageMode.history => current.copyWith(historySort: sort),
        ShelfPageMode.download => current.copyWith(downloadSort: sort),
      },
    );
  }

  SearchStatusState _currentSearchState() {
    final cubit = context.read<BookshelfSearchCubit>();
    return cubit.state.stateOf(_currentMode());
  }

  void _setKeyword(String keyword) {
    context.read<BookshelfSearchCubit>().setKeyword(_currentMode(), keyword);
  }

  void _triggerRefresh({bool goTop = false}) {
    setState(() {
      _refreshSignals[_currentIndex] = _refreshSignals[_currentIndex] + 1;
    });
  }

  void _triggerRefreshAll() {
    if (!mounted) {
      return;
    }
    setState(() {
      for (var i = 0; i < _refreshSignals.length; i++) {
        _refreshSignals[i] = _refreshSignals[i] + 1;
      }
    });
  }

  Future<void> _openFilter() async {
    final searchCubit = context.read<BookshelfSearchCubit>();
    final currentMode = _currentMode();
    final current = searchCubit.state.stateOf(currentMode);
    final sourceOptions = _buildFilterSourceOptions();
    final availableSources = sourceOptions
        .map((source) => source.pluginId)
        .toList();

    if (availableSources.isEmpty && currentMode != ShelfPageMode.favorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.bookshelf.noFilterSource)));
      return;
    }

    final currentFolderKey = switch (currentMode) {
      ShelfPageMode.favorite =>
        FavoriteFolderService.parseFolderKeyFromSources(current.sources) ??
            kFavoriteFolderAllKey,
      ShelfPageMode.download =>
        DownloadFolderService.parseFolderKeyFromSources(current.sources) ??
            kDownloadFolderAllKey,
      _ => kFavoriteFolderAllKey,
    };
    final stripFolderTokens = switch (currentMode) {
      ShelfPageMode.favorite => FavoriteFolderService.stripFolderSourceTokens,
      ShelfPageMode.download => DownloadFolderService.stripFolderSourceTokens,
      _ => FavoriteFolderService.stripFolderSourceTokens,
    };
    var selectedSources = stripFolderTokens(
      current.sources,
    ).where(availableSources.contains).toSet();
    if (selectedSources.isEmpty) {
      selectedSources = availableSources.toSet();
    }

    final result = await showDialog<_BookshelfFilterResult>(
      context: context,
      builder: (dialogContext) => _BookshelfFilterDialog(
        mode: currentMode,
        initialSort: switch (currentMode) {
          (ShelfPageMode.favorite || ShelfPageMode.download)
              when current.sort == 'vd' || current.sort == 'va' =>
            current.sort,
          _ when current.sort == 'da' => 'da',
          _ => 'dd',
        },
        initialFolderKey: currentFolderKey,
        initialSources: selectedSources,
        availableSources: availableSources,
        sourceOptions: sourceOptions,
        onCreateFolder: () => _showCreateFolderDialog(dialogContext),
        onRequestFolderAction: (folder) =>
            _handleFolderAction(dialogContext, folder),
      ),
    );

    if (result == null) return;

    searchCubit.setSort(currentMode, result.sort);
    _maybePersistSort(currentMode, result.sort);

    var nextSources = result.sources.toList();
    if (currentMode == ShelfPageMode.favorite &&
        result.folderKey != kFavoriteFolderAllKey) {
      nextSources.add(FavoriteFolderService.sourceToken(result.folderKey));
    } else if (currentMode == ShelfPageMode.download &&
        result.folderKey != kDownloadFolderAllKey) {
      nextSources.add(DownloadFolderService.sourceToken(result.folderKey));
    }
    searchCubit.setSources(currentMode, nextSources);
    _triggerRefresh(goTop: true);
  }

  List<_FilterSourceOption> _buildFilterSourceOptions() {
    final pluginStates = context.read<PluginRegistryCubit>().state;
    final sourceOptions = PluginRegistryService.I.sortPlugins(
      pluginStates.values.where(
        (plugin) => plugin.isEnabled && !plugin.isDeleted,
      ),
    );
    return sourceOptions
        .map(
          (plugin) => _FilterSourceOption(
            pluginId: plugin.uuid,
            title: _sourceTitle(plugin.uuid),
          ),
        )
        .toList();
  }

  String _sourceTitle(String pluginId) {
    final info = PluginRegistryService.I.getCachedPluginInfo(pluginId);
    final name = info?['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : pluginId;
  }

  Future<_FolderDialogOutcome?> _handleFolderAction(
    BuildContext dialogContext,
    dynamic folder,
  ) async {
    final String folderKey = folder.key as String;
    final String folderName = folder.name as String;

    if (!mounted) {
      return null;
    }

    final action = await _showFolderActionDialog(context, folderName);
    if (!mounted) {
      return null;
    }
    if (action == null) {
      return null;
    }

    final isFavoriteMode = _currentIndex == 0;
    final allKey = isFavoriteMode
        ? kFavoriteFolderAllKey
        : kDownloadFolderAllKey;

    if (action == _FolderAction.delete) {
      final ok = await _confirmDeleteFolder(context, folderName);
      if (!mounted) {
        return null;
      }
      if (ok != true) {
        return null;
      }
      if (isFavoriteMode) {
        FavoriteFolderService.deleteFolder(folderKey);
      } else {
        DownloadFolderService.deleteFolder(folderKey);
      }
      return _FolderDialogOutcome(
        shouldRefreshFolders: true,
        selectedFolderKey: allKey,
      );
    }

    final renamed = await _showRenameFolderDialog(
      context,
      initialName: folderName,
    );
    if (!mounted) {
      return null;
    }
    if (renamed == null || renamed.trim().isEmpty) {
      return null;
    }
    try {
      if (isFavoriteMode) {
        FavoriteFolderService.renameFolder(folderKey, renamed.trim());
      } else {
        DownloadFolderService.renameFolder(folderKey, renamed.trim());
      }
      return _FolderDialogOutcome(
        shouldRefreshFolders: true,
        selectedFolderKey: folderKey,
      );
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(
          dialogContext,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return null;
    }
  }

  Future<bool?> _confirmDeleteFolder(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.bookshelf.deleteFolder),
        content: Text(t.bookshelf.confirmDeleteFolder(name: name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
  }

  Future<_FolderAction?> _showFolderActionDialog(
    BuildContext context,
    String name,
  ) {
    return showDialog<_FolderAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Text(t.bookshelf.folderAction),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_FolderAction.rename),
            child: Text(t.common.rename),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_FolderAction.delete),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRenameFolderDialog(
    BuildContext context, {
    required String initialName,
  }) async {
    final controller = TextEditingController(text: initialName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.bookshelf.renameFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.bookshelf.folderNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _showCreateFolderDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.bookshelf.createFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.bookshelf.createFolderHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.common.create),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _syncSourcesFromRegistry(Map<String, PluginRuntimeState> pluginStates) {
    final available =
        pluginStates.values
            .where((plugin) => plugin.isEnabled && !plugin.isDeleted)
            .map((plugin) => plugin.uuid)
            .toList()
          ..sort();

    if (listEquals(_lastAvailableSources, available)) {
      return;
    }
    final addedSources = available
        .where((item) => !_lastAvailableSources.contains(item))
        .toList();
    _lastAvailableSources = List<String>.from(available);

    context.read<BookshelfSearchCubit>().syncSources(
      available,
      autoSelect: addedSources,
    );
  }

  String _pluginAvailabilityRevision(
    Map<String, PluginRuntimeState> pluginStates,
  ) {
    final entries =
        pluginStates.entries
            .map(
              (entry) =>
                  '${entry.key}:${entry.value.isEnabled ? 1 : 0}:${entry.value.isDeleted ? 1 : 0}',
            )
            .toList()
          ..sort();
    return entries.join('|');
  }
}

class _BookshelfFilterDialog extends StatefulWidget {
  const _BookshelfFilterDialog({
    required this.mode,
    required this.initialSort,
    required this.initialFolderKey,
    required this.initialSources,
    required this.availableSources,
    required this.sourceOptions,
    required this.onCreateFolder,
    required this.onRequestFolderAction,
  });

  final ShelfPageMode mode;
  final String initialSort;
  final String initialFolderKey;
  final Set<String> initialSources;
  final List<String> availableSources;
  final List<_FilterSourceOption> sourceOptions;
  final Future<String?> Function() onCreateFolder;
  final Future<_FolderDialogOutcome?> Function(dynamic folder)
  onRequestFolderAction;

  @override
  State<_BookshelfFilterDialog> createState() => _BookshelfFilterDialogState();
}

class _BookshelfFilterDialogState extends State<_BookshelfFilterDialog> {
  late String _selectedSort;
  late String _selectedFolderKey;
  late Set<String> _selectedSources;

  bool get _isFavoriteMode => widget.mode == ShelfPageMode.favorite;
  bool get _isDownloadMode => widget.mode == ShelfPageMode.download;
  bool get _showFolderSection => false;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
    _selectedFolderKey = widget.initialFolderKey;
    _selectedSources = Set<String>.from(widget.initialSources);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.bookshelf.filter),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSortSection(context),
              const SizedBox(height: 16),
              if (_showFolderSection) ...[
                _buildFolderSection(context),
                const SizedBox(height: 16),
              ],
              _buildSourceSection(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _BookshelfFilterResult(
              sort: _selectedSort,
              folderKey: _selectedFolderKey,
              sources: _selectedSources,
            ),
          ),
          child: Text(t.common.apply),
        ),
      ],
    );
  }

  Widget _buildSortSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.bookshelf.sort, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              showCheckmark: false,
              label: Text(t.bookshelf.sortDesc),
              selected: _selectedSort == 'dd',
              onSelected: (_) => setState(() => _selectedSort = 'dd'),
            ),
            ChoiceChip(
              showCheckmark: false,
              label: Text(t.bookshelf.sortAsc),
              selected: _selectedSort == 'da',
              onSelected: (_) => setState(() => _selectedSort = 'da'),
            ),
            if (_isFavoriteMode || _isDownloadMode) ...[
              ChoiceChip(
                showCheckmark: false,
                label: Text(t.bookshelf.viewSortDesc),
                selected: _selectedSort == 'vd',
                onSelected: (_) => setState(() => _selectedSort = 'vd'),
              ),
              ChoiceChip(
                showCheckmark: false,
                label: Text(t.bookshelf.viewSortAsc),
                selected: _selectedSort == 'va',
                onSelected: (_) => setState(() => _selectedSort = 'va'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFolderSection(BuildContext context) {
    final List<dynamic> folderViews;
    if (_isFavoriteMode) {
      folderViews = FavoriteFolderService.listFolders();
    } else {
      folderViews = DownloadFolderService.listFolders();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.bookshelf.folderDeprecated,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final folder in folderViews)
              GestureDetector(
                onLongPress: folder.isAll
                    ? null
                    : () => _handleFolderLongPress(folder),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(folder.name),
                  selected: _selectedFolderKey == folder.key,
                  onSelected: (_) =>
                      setState(() => _selectedFolderKey = folder.key),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleFolderLongPress(dynamic folder) async {
    final outcome = await widget.onRequestFolderAction(folder);
    if (!mounted || outcome == null) {
      return;
    }
    setState(() {
      if (outcome.selectedFolderKey != null) {
        _selectedFolderKey = outcome.selectedFolderKey!;
      }
    });
  }

  Widget _buildSourceSection(BuildContext context) {
    final isAllSelected =
        _selectedSources.length == widget.availableSources.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.bookshelf.source,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() {
                if (isAllSelected) {
                  _selectedSources.clear();
                } else {
                  _selectedSources = widget.availableSources.toSet();
                }
              }),
              child: Text(
                isAllSelected ? t.bookshelf.deselectAll : t.common.selectAll,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final source in widget.sourceOptions)
              FilterChip(
                showCheckmark: false,
                label: Text(source.title),
                selected: _selectedSources.contains(source.pluginId),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedSources.add(source.pluginId);
                  } else {
                    _selectedSources.remove(source.pluginId);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _BookshelfFilterResult {
  _BookshelfFilterResult({
    required this.sort,
    required this.folderKey,
    required Set<String> sources,
  }) : sources = Set<String>.from(sources);

  final String sort;
  final String folderKey;
  final Set<String> sources;
}

class _FilterSourceOption {
  const _FilterSourceOption({required this.pluginId, required this.title});

  final String pluginId;
  final String title;
}

class _FolderDialogOutcome {
  const _FolderDialogOutcome({
    required this.shouldRefreshFolders,
    this.selectedFolderKey,
  });

  final bool shouldRefreshFolders;
  final String? selectedFolderKey;
}

enum _FolderAction { rename, delete }
