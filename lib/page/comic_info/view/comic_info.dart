import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_info/comic_info.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/preview_prefs.dart';
import 'package:zephyr/page/comic_info/widgets/comic_info_fabs.dart';
import 'package:zephyr/page/comic_info/widgets/episode_list_section.dart';
import 'package:zephyr/page/comic_info/widgets/inline_preview_grid.dart';
import 'package:zephyr/page/comic_info/widgets/preview_controls.dart';
import 'package:zephyr/page/comic_info/widgets/section_widgets.dart';
// ★ 新增：查 objectbox 下载记录。
import 'package:zephyr/object_box/objectbox.g.dart';
// ★ 新增：构造 UnifiedComicDownloadInfo 传给下载页。
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/page/download/view/download_dialog.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/permission.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/error_view.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';
import 'package:zephyr/widgets/toast.dart';

enum MenuOption { export, cloudCollect, follow }

@RoutePage()
class ComicInfoPage extends StatelessWidget {
  final String comicId;
  final String from;
  final ComicEntryType type;
  final Map<String, dynamic>? extern;
  final String? collectionTargetId;
  final String? collectionTargetName;

  const ComicInfoPage({
    super.key,
    required this.comicId,
    required this.from,
    required this.type,
    this.extern,
    this.collectionTargetId,
    this.collectionTargetName,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedFrom = from.trim();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GetComicInfoBloc()
            ..add(
              GetComicInfoEvent(
                comicId: comicId,
                from: resolvedFrom,
                type: type,
                extern: extern,
              ),
            ),
        ),
        BlocProvider(create: (_) => StringSelectCubit()),
      ],
      child: _ComicInfo(
        comicId: comicId,
        type: type,
        from: resolvedFrom,
        extern: extern,
        collectionTargetId: collectionTargetId,
        collectionTargetName: collectionTargetName,
      ),
    );
  }
}

class _ComicInfo extends StatefulWidget {
  final String comicId;
  final ComicEntryType type;
  final String from;
  final Map<String, dynamic>? extern;
  final String? collectionTargetId;
  final String? collectionTargetName;

  const _ComicInfo({
    required this.comicId,
    required this.type,
    required this.from,
    this.extern,
    this.collectionTargetId,
    this.collectionTargetName,
  });

  @override
  _ComicInfoState createState() => _ComicInfoState();
}

class _ComicInfoState extends State<_ComicInfo>
    with AutomaticKeepAliveClientMixin {
  ComicEntryType get type => widget.type;

  @override
  bool get wantKeepAlive => true;

  /// 用于「回到顶部」FAB 的滚动控制器。
  final ScrollController _scrollController = ScrollController();

  dynamic comicInfoDyn;
  late ComicEntryType _type;
  late String _comicId;
  bool _loadingComplete = false;
  bool _isReversed = false;
  String _title = "";
  NormalComicAllInfo? _currentInfo;
  bool _isCloudCollected = false;
  bool _cloudFavoriteStateOverridden = false;
  bool _isLocalCollected = false;
  String _localCollectSyncedFor = '';

  // 预览状态（全部持久化）。
  bool _showPreview = false;
  PreviewMode _previewMode = PreviewMode.top;
  int _previewCount = 20;
  int _previewStart = 1;
  int _previewEnd = 20;
  int _previewTotalPages = 0;
  int _previewReloadKey = 0;

  // 下载完成监听：objectbox 的 reactive query，下载记录写入/更新时触发重建，
  // 让 FAB 在「下载 → 导出」之间自动同步。
  StreamSubscription<dynamic>? _downloadWatchSub;
  String _watchedDownloadKey = '';

  @override
  void initState() {
    super.initState();
    _type = type;
    _comicId = widget.comicId;
    _loadPreviewPrefs();
    _ensureDownloadWatch();
  }

  @override
  void dispose() {
    _downloadWatchSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// 订阅当前漫画的 objectbox 下载记录变化。
  ///
  /// 当 comicId 在加载后被修正时（例如 bika 的 id 与路由传入的不同），
  /// 会自动切换订阅到正确的 uniqueKey。
  void _ensureDownloadWatch() {
    final key = '${widget.from.trim()}:$_comicId';
    if (key == _watchedDownloadKey) return;
    _watchedDownloadKey = key;
    _downloadWatchSub?.cancel();
    try {
      _downloadWatchSub = objectbox.unifiedDownloadBox
          .query(UnifiedComicDownload_.uniqueKey.equals(key))
          .watch()
          .listen((_) {
        if (!mounted) return;
        setState(() {});
      });
    } catch (_) {
      // objectbox 未就绪时忽略；下次 build 仍会查询。
    }
  }

  /// 当前漫画是否已在 objectbox 里有下载记录。
  ///
  /// 每次 build 时同步查询一次：objectbox 的本地查询是内存操作，微秒级，
  /// 比引入 RouteObserver + setState 更简单可靠（下载完成后回到本页
  /// 会自动反映最新状态）。
  bool get _isDownloaded {
    try {
      final uniqueKey = '${widget.from.trim()}:$_comicId';
      return objectbox.unifiedDownloadBox
              .query(UnifiedComicDownload_.uniqueKey.equals(uniqueKey))
              .build()
              .findFirst() !=
          null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadPreviewPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final show = prefs.getBool(PreviewPrefsKeys.show) ?? false;
      final modeIdx = prefs.getInt(PreviewPrefsKeys.mode) ?? 0;
      final count = prefs.getInt(PreviewPrefsKeys.count) ?? 20;
      final start = prefs.getInt(PreviewPrefsKeys.start) ?? 1;
      final end = prefs.getInt(PreviewPrefsKeys.end) ?? 20;

      setState(() {
        _showPreview = show;
        _previewMode =
            PreviewMode.values[modeIdx.clamp(0, PreviewMode.values.length - 1)];
        _previewCount = count.clamp(1, 9999);
        _previewStart = start.clamp(1, 9999);
        _previewEnd = end.clamp(1, 9999);
      });
    } catch (_) {
      // 读失败保持默认。
    }
  }

  Future<void> _togglePreview() async {
    final next = !_showPreview;

    // ★ 打开预览前清一次 ImageCache：
    //   下载任务 + 之前的封面/章节头图会占用大量 GPU 纹理，
    //   预览网格需要新分配一批纹理，先清一次能显著降低 Adreno OOM 概率。
    if (next) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }

    setState(() => _showPreview = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreviewPrefsKeys.show, next);
    } catch (_) {}
  }

  Future<void> _persistPreviewSelection({
    required PreviewMode mode,
    required int count,
    required int start,
    required int end,
  }) async {
    setState(() {
      _previewMode = mode;
      _previewCount = count;
      _previewStart = start;
      _previewEnd = end;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PreviewPrefsKeys.mode, mode.index);
      await prefs.setInt(PreviewPrefsKeys.count, count);
      await prefs.setInt(PreviewPrefsKeys.start, start);
      await prefs.setInt(PreviewPrefsKeys.end, end);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cloudFavoritePreferred = context
        .watch<GlobalSettingCubit>()
        .state
        .cloudFavoritePreferred;
    final leftHandMode = context
        .watch<GlobalSettingCubit>()
        .state
        .leftHandModeEnabled;

    // 每次 build 时算一次下载状态。
    final isDownloaded = _isDownloaded;

    // Miuix 迁移：Scaffold + AppBar → MiuixScaffold + 自绘顶栏。
    // 顶栏用 Material 包裹，保留 FluentPopupMenuButton 内部 IconButton
    // 所需的 Material 祖先；各按钮回调与菜单逻辑全部保持不变。
    return MiuixScaffold(
      topBar: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  MiuixIconButton(
                    onPressed: () => context.pop(),
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  MiuixIconButton(
                    onPressed: () => popToRoot(context),
                    child: const Icon(Icons.home),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: _showPreview ? '关闭预览' : '预览',
                    child: MiuixIconButton(
                      onPressed: _togglePreview,
                      child: Icon(
                        _showPreview
                            ? Icons.image_rounded
                            : Icons.image_outlined,
                      ),
                    ),
                  ),
                  BlocSelector<ComicFollowCubit, ComicFollowState, bool>(
                    selector: (state) =>
                        state.isFollowing(widget.from, _comicId),
                    builder: (context, isFollowing) {
                      return Tooltip(
                        message: isFollowing
                            ? t.comicInfo.unfollow
                            : t.comicInfo.follow,
                        child: MiuixIconButton(
                          onPressed: () => _toggleFollow(isFollowing),
                          child: Icon(
                            isFollowing
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                          ),
                        ),
                      );
                    },
                  ),
                  FluentPopupMenuButton<MenuOption>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (MenuOption item) {
                      switch (item) {
                        case MenuOption.export:
                          _handleExport();
                          break;
                        case MenuOption.cloudCollect:
                          if (cloudFavoritePreferred) {
                            _toggleLocalCollectFromMenu();
                          } else {
                            _toggleCloudCollectFromMenu();
                          }
                          break;
                        case MenuOption.follow:
                          _toggleFollowFromMenu();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      final isFollowing = context
                          .read<ComicFollowCubit>()
                          .isFollowing(widget.from, _comicId);
                      final menuItems = <FluentPopupMenuItem<MenuOption>>[
                        FluentPopupMenuItem<MenuOption>(
                          value: MenuOption.follow,
                          leading: Icon(
                            isFollowing
                                ? Icons.notifications_off
                                : Icons.notifications_active,
                          ),
                          title: Text(
                            isFollowing
                                ? t.comicInfo.unfollow
                                : t.comicInfo.follow,
                          ),
                        ),
                      ];

                      // 已下载 → 菜单里保留导出入口（方便快速导出）。
                      if (isDownloaded) {
                        menuItems.add(
                          FluentPopupMenuItem<MenuOption>(
                            value: MenuOption.export,
                            leading: const Icon(Icons.save_alt),
                            title: Text(t.comicInfo.exportComic),
                          ),
                        );
                      }

                      menuItems.add(
                        FluentPopupMenuItem<MenuOption>(
                          value: MenuOption.cloudCollect,
                          leading: Icon(
                            cloudFavoritePreferred
                                ? (_isLocalCollected
                                      ? Icons.star
                                      : Icons.star_border)
                                : (_isCloudCollected
                                      ? Icons.star
                                      : Icons.star_border),
                          ),
                          title: Text(
                            cloudFavoritePreferred
                                ? (_isLocalCollected
                                      ? t.comicInfo.removeLocalCollection
                                      : t.comicInfo.collectToLocal)
                                : (_isCloudCollected
                                      ? t.comicInfo.removeCloudCollection
                                      : t.comicInfo.collectToCloud),
                          ),
                        ),
                      );

                      return menuItems;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: BlocBuilder<GetComicInfoBloc, GetComicInfoState>(
            builder: (context, state) {
              switch (state.status) {
                case GetComicInfoStatus.initial:
                  _cloudFavoriteStateOverridden = false;
                  return const Center(child: CircularProgressIndicator());
                case GetComicInfoStatus.failure:
                  if (state.result.contains("under review") &&
                      state.result.contains("1014")) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t.comicInfo.discontinued,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 10),
                          MiuixButton(
                            onPressed: () => context.pop(),
                            child: Text(t.comicInfo.back),
                          ),
                        ],
                      ),
                    );
                  }
                  return ErrorView(
                    errorMessage: t.comicInfo.loadFailedWithError(
                      error: state.result.toString(),
                    ),
                    onRetry: () {
                      context.read<GetComicInfoBloc>().add(
                        GetComicInfoEvent(
                          comicId: _comicId,
                          from: widget.from,
                          type: _type,
                          extern: widget.extern,
                        ),
                      );
                    },
                  );
                case GetComicInfoStatus.success:
                  comicInfoDyn = state.comicInfo;
                  _currentInfo = state.allInfo;
                  _comicId = state.comicId ?? _comicId;
                  _ensureDownloadWatch();
                  if (!_cloudFavoriteStateOverridden) {
                    _isCloudCollected = state.allInfo?.isFavourite ?? false;
                  }
                  _syncLocalCollectStatus(state.allInfo!);
                  initHistory(
                    context,
                    _comicId,
                    widget.from,
                    chapters: state.allInfo!.eps,
                  );
                  return _infoView(state.allInfo!);
              }
            },
          ),
        ),
      ),
      floatingActionButtonPosition: leftHandMode
          ? MiuixFabPosition.start
          : MiuixFabPosition.end,
      floatingActionButton: _loadingComplete
          ? BlocBuilder<StringSelectCubit, String>(
              builder: (context, stringSelectDate) {
                return ComicInfoFabGroup(
                  scrollController: _scrollController,
                  hasHistory: stringSelectDate.isNotEmpty,
                  isLeftHanded: leftHandMode,
                  // ★ 关键：已下载 → 导出；未下载 → 下载。
                  isDownloaded: isDownloaded,
                  onDownload: _handleDownload,
                  onExport: _handleExport,
                  onRead: () => goToComicRead(
                    context,
                    _comicId,
                    widget.type,
                    comicInfoDyn,
                    widget.from,
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _infoView(NormalComicAllInfo normalComicAllInfo) {
    final comicInfo = normalComicAllInfo.comicInfo;
    _title = comicInfo.title;
    final clickCoverToStartReading = context
        .watch<GlobalSettingCubit>()
        .state
        .clickCoverToStartReading;

    if (!_loadingComplete) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _loadingComplete = true),
      );
    }

    var displayEps = List<dynamic>.from(normalComicAllInfo.eps);
    if (_isReversed) {
      displayEps = displayEps.reversed.toList();
    }

    return BlocSelector<StringSelectCubit, String, bool>(
      selector: (state) => state.isNotEmpty,
      builder: (context, hasHistory) {
        return RefreshIndicator(
          onRefresh: () async {
            _type = ComicEntryType.normal;
            _isReversed = false;

            context.read<GetComicInfoBloc>().add(
              GetComicInfoEvent(
                comicId: _comicId,
                from: widget.from,
                type: _type,
                extern: widget.extern,
              ),
            );
            setState(() {
              _loadingComplete = false;
            });
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: _constrainedSliver(
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ComicParticularsWidget(
                          comicInfo: comicInfo,
                          from: widget.from,
                          type: _type,
                          onCoverTap: clickCoverToStartReading
                              ? () => goToComicRead(
                                  context,
                                  _comicId,
                                  _type,
                                  comicInfoDyn,
                                  widget.from,
                                )
                              : null,
                          onContinueRead: hasHistory
                              ? () => goToComicRead(
                                  context,
                                  _comicId,
                                  _type,
                                  comicInfoDyn,
                                  widget.from,
                                )
                              : null,
                        ),
                        _buildDivider(context),
                        ComicOperationWidget(
                          normalInfo: normalComicAllInfo,
                          from: widget.from,
                          collectionTargetId: widget.collectionTargetId,
                          collectionTargetName: widget.collectionTargetName,
                          comicInfo: comicInfoDyn,
                        ),
                        if (comicInfo.metadata.isNotEmpty ||
                            comicInfo.description.trim().isNotEmpty) ...[
                          _buildDivider(context),
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final meta in comicInfo.metadata) ...[
                                  AllChipWidget(
                                    comicId: comicInfo.id,
                                    metadata: meta,
                                    from: widget.from,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (comicInfo.description.trim().isNotEmpty)
                                  DescriptionCard(
                                    description: comicInfo.description.let(
                                      convertChineseForDisplay,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (comicInfo.creator.name.trim().isNotEmpty ||
                            comicInfo.creator.avatar.url.trim().isNotEmpty) ...[
                          _buildDivider(context),
                          SectionCard(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: CreatorInfoWidget(
                                  creator: comicInfo.creator,
                                  from: widget.from,
                                  imageKey: comicInfo.id,
                                ),
                              ),
                            ),
                          ),
                        ],
                        _buildDivider(context),
                        SectionCard(
                          title: t.comicInfo.chapterList,
                          trailing: EpisodeHeaderBadge(
                            label: t.comicInfo.episodeCount(
                              count: normalComicAllInfo.eps.length,
                            ),
                            icon: _isReversed ? Icons.south : Icons.north,
                            onTap: _toggleOrder,
                          ),
                          child: EpisodeListSection(
                            episodes: displayEps,
                            allInfo: comicInfoDyn,
                            epsLength: normalComicAllInfo.eps.length,
                            type: _type,
                            comicId: _comicId,
                            from: widget.from,
                            isReversed: _isReversed,
                          ),
                        ),
                        if (_showPreview) ...[
                          _buildDivider(context),
                          SectionCard(
                            title: t.comicInfo.preview,
                            trailing: PreviewControls(
                              mode: _previewMode,
                              count: _previewCount,
                              start: _previewStart,
                              end: _previewEnd,
                              totalPages: _previewTotalPages,
                              onSelectionChanged: (mode, count, start, end) =>
                                  _persistPreviewSelection(
                                    mode: mode,
                                    count: count,
                                    start: start,
                                    end: end,
                                  ),
                              onRefresh: () =>
                                  setState(() => _previewReloadKey++),
                            ),
                            child: InlinePreviewGrid(
                              key: ValueKey(
                                'preview:$_comicId:$_previewReloadKey',
                              ),
                              comicId: _comicId,
                              from: widget.from,
                              type: _type,
                              comicInfo: comicInfoDyn,
                              firstEp: normalComicAllInfo.eps.isNotEmpty
                                  ? normalComicAllInfo.eps.first
                                  : null,
                              mode: _previewMode,
                              count: _previewCount,
                              startPage: _previewStart,
                              endPage: _previewEnd,
                              onTotalResolved: (n) {
                                if (!mounted) return;
                                if (_previewTotalPages == n) return;
                                setState(() => _previewTotalPages = n);
                              },
                            ),
                          ),
                        ],
                        if (normalComicAllInfo.recommend.isNotEmpty &&
                            _resolveRecommendItems(
                              normalComicAllInfo.recommend,
                            ).isNotEmpty) ...[
                          _buildDivider(context),
                          SectionCard(
                            title: t.comicInfo.related,
                            child: RecommendWidget(
                              comicList: _resolveRecommendItems(
                                normalComicAllInfo.recommend,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 180),
                sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _constrainedSliver(Widget sliver) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = ((constraints.crossAxisExtent - 1120) / 2)
            .clamp(20.0, double.infinity)
            .toDouble();
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: sliver,
        );
      },
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: context.theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 下载
  // ─────────────────────────────────────────────────────────────────

  /// 点击「下载」FAB：弹出章节选择对话框（与漫画详情操作区的下载按钮一致）。
  ///
  /// 下载任务派发后通过 [_ensureDownloadWatch] 订阅的 objectbox reactive
  /// query 自动同步 FAB 状态（下载完成 → 切换为「导出」）。
  Future<void> _handleDownload() async {
    final info = _currentInfo;
    if (info == null) {
      showErrorToast(t.comicInfo.detailsNotLoaded);
      return;
    }
    if (!info.allowDownload) {
      showErrorToast(t.comicInfo.downloadNotAllowed);
      return;
    }
    try {
      final downloadInfo = resolveUnifiedDownloadInfo(comicInfoDyn, widget.from);
      await showDownloadDialog(context, downloadInfo);
      if (!mounted) return;
      // 对话框关闭后立即重建一次：若已是已下载章节会立刻反映为「导出」。
      setState(() {});
    } catch (e, s) {
      logger.e('打开下载对话框失败', error: e, stackTrace: s);
      if (!mounted) return;
      showErrorToast(
        t.error.operationFailed,
        duration: const Duration(seconds: 3),
      );
    }
  }
  // ─────────────────────────────────────────────────────────────────
  // 导出
  // ─────────────────────────────────────────────────────────────────

  String _buildZipFileName() {
    final rawName = _title.trim().isEmpty ? _comicId : _title.trim();
    final safeName = rawName.replaceAll(RegExp(r'[<>:"/\\|?* ]'), '_');
    return '$safeName.zip';
  }

  Future<ExportType?> _pickExportType() async {
    if (Platform.isIOS) return ExportType.zip;

    return showDialog<ExportType>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.comicInfo.exportTitle),
          content: Text(t.comicInfo.exportSubtitle),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ExportType.folder),
              child: Text(t.comicInfo.folder),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ExportType.zip),
              child: Text(t.comicInfo.zip),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _pickExportDirectory() async => getDirectoryPath();

  Future<String?> _resolveExportDirectory() async {
    if (Platform.isIOS) return getCachePath();
    final customPath = globalSetting.customExportPath.trim();
    if (customPath.isNotEmpty) return customPath;
    if (Platform.isAndroid) {
      final granted = await requestExportPermission();
      if (!granted) throw StateError(t.comicInfo.exportPermissionDenied);
      return createDownloadDir();
    }
    return _pickExportDirectory();
  }

  void _logExportPath(String path) {
    if (!(Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux)) {
      return;
    }
    final displayPath = Platform.isAndroid
        ? _simplifyAndroidPathForLog(path)
        : path;
    logger.d('Exported comic path: $displayPath');
  }

  String _simplifyAndroidPathForLog(String path) {
    final normalized = path.replaceAll('\\', '/');
    final downloadIndex = normalized.indexOf('/Download/');
    if (downloadIndex >= 0) {
      return normalized.substring(downloadIndex + 1);
    }
    return normalized;
  }

  void _showExportDirectory(String exportedPath, ExportType exportType) {
    if (!(Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux)) {
      return;
    }
    final exportDirectory = exportType == ExportType.zip
        ? p.dirname(exportedPath)
        : exportedPath;
    final displayPath = Platform.isAndroid
        ? _simplifyAndroidPathForLog(exportDirectory)
        : exportDirectory;
    showInfoToast(
      t.comicInfo.exportDirectory(displayPath: displayPath),
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _handleExport() async {
    try {
      if (!mounted) return;

      final exportType = await _pickExportType();
      if (exportType == null) return;

      final exportDir = await _resolveExportDirectory();
      if (exportDir == null) return;

      final zipFileName = _buildZipFileName();
      final targetZipPath = p.join(exportDir, zipFileName);

      if (Platform.isIOS) {
        final iosZipFile = File(targetZipPath);
        if (await iosZipFile.exists()) {
          await iosZipFile.delete();
        }

        await exportComic(
          _comicId,
          ExportType.zip,
          widget.from,
          path: targetZipPath,
        );

        await OpenFile.open(targetZipPath);
        showSuccessToast(t.comicInfo.exportSuccess);
        _logExportPath(targetZipPath);
        return;
      }

      final exportPath = exportType == ExportType.zip
          ? targetZipPath
          : exportDir;

      final exportedPath = await exportComic(
        _comicId,
        exportType,
        widget.from,
        path: exportPath,
      );
      _showExportDirectory(exportedPath, exportType);
      _logExportPath(exportedPath);
    } catch (e) {
      final errorMessage = e is StateError
          ? e.message.toString()
          : t.comicInfo.exportFailedWithError(
              error: normalizeSearchErrorMessage(e),
            );
      showErrorToast(errorMessage, duration: const Duration(seconds: 5));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 其它交互
  // ─────────────────────────────────────────────────────────────────

  void _toggleOrder() => setState(() => _isReversed = !_isReversed);

  Future<void> _toggleFollow(bool isFollowing) async {
    final info = _currentInfo;
    if (info == null) {
      showErrorToast(t.comicInfo.detailsNotLoaded);
      return;
    }
    if (isFollowing) {
      await _confirmAndRemoveFollow(info.comicInfo.title);
      return;
    }
    await context.read<ComicFollowCubit>().addOrUpdateFollow(
      source: widget.from,
      comicId: _comicId,
      info: info,
      lastChapterCount: info.eps.length,
    );
    if (mounted) showSuccessToast(t.comicInfo.followed);
  }

  Future<void> _toggleFollowFromMenu() async {
    final info = _currentInfo;
    if (info == null) {
      showErrorToast(t.comicInfo.detailsNotLoaded);
      return;
    }
    final isFollowing = context.read<ComicFollowCubit>().isFollowing(
      widget.from,
      _comicId,
    );
    await _toggleFollow(isFollowing);
  }

  Future<void> _autoFollowIfEnabled() async {
    if (!context.read<GlobalSettingCubit>().state.autoFollowOnCollect) return;
    final info = _currentInfo;
    if (info == null) return;
    final followCubit = context.read<ComicFollowCubit>();
    if (followCubit.isFollowing(widget.from, _comicId)) return;
    await followCubit.addOrUpdateFollow(
      source: widget.from,
      comicId: _comicId,
      info: info,
      lastChapterCount: info.eps.length,
    );
  }

  Future<void> _confirmAndRemoveFollow(String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.comicInfo.confirmUnfollowTitle),
        content: Text(t.comicInfo.confirmUnfollowContent(title: title)),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(t.common.ok),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<ComicFollowCubit>().removeFollow(widget.from, _comicId);
    if (mounted) showSuccessToast(t.comicInfo.unfollowed);
  }

  List<UnifiedComicListItem> _resolveRecommendItems(List<Recommend> recommend) {
    return recommend
        .map((item) {
          final unifiedJson = asJsonMap(item.extern)['unifiedItem'];
          if (unifiedJson != null) return asJsonMap(unifiedJson);
          return item.toJson();
        })
        .where((json) => json.isNotEmpty)
        .map(UnifiedComicListItem.fromJson)
        .toList();
  }

  Future<void> _syncLocalCollectStatus(NormalComicAllInfo info) async {
    final comicId = info.comicInfo.id;
    if (_localCollectSyncedFor == comicId) return;
    _localCollectSyncedFor = comicId;
    final collected = await isLocalComicCollected(
      from: widget.from,
      comicId: comicId,
    );
    if (!mounted) return;
    setState(() => _isLocalCollected = collected);
  }

  Future<void> _toggleLocalCollectFromMenu() async {
    final info = _currentInfo;
    if (info == null) {
      showErrorToast(t.comicInfo.detailsNotLoaded);
      return;
    }
    try {
      if (_isLocalCollected) {
        final confirmed = await _showLocalUncollectConfirmDialog();
        if (!confirmed) return;
      }

      final next = await toggleLocalComicFavorite(
        from: widget.from,
        normalInfo: info,
      );
      if (!mounted) return;
      setState(() => _isLocalCollected = next);
      if (next) await _autoFollowIfEnabled();
      showSuccessToast(
        next
            ? t.comicInfo.addedToCollection
            : t.comicInfo.removedFromCollection,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorToast(
        t.comicInfo.localCollectFailed(error: normalizeSearchErrorMessage(e)),
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<bool> _showLocalUncollectConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.comicInfo.confirmUncollectTitle),
        content: Text(t.comicInfo.confirmUncollectContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _toggleCloudCollectFromMenu() async {
    final info = _currentInfo;
    if (info == null) {
      showErrorToast(t.comicInfo.detailsNotLoaded);
      return;
    }
    try {
      showInfoToast(
        _isCloudCollected
            ? t.comicInfo.removingCloudCollection
            : t.comicInfo.collectingToCloud,
      );
      final next = await toggleCloudComicFavorite(
        context: context,
        from: widget.from,
        comicId: info.comicInfo.id,
        currentStatus: _isCloudCollected,
        legacyAllowCollected: info.allowCollected,
        collectionTargetId: widget.collectionTargetId,
        collectionTargetName: widget.collectionTargetName,
      );
      if (!mounted) return;
      setState(() {
        _isCloudCollected = next;
        _cloudFavoriteStateOverridden = true;
      });
      if (next) await _autoFollowIfEnabled();
      showSuccessToast(
        next
            ? t.comicInfo.cloudCollectSuccess
            : t.comicInfo.cloudUncollectSuccess,
      );
    } on FavoriteWorkflowUnsupportedException {
      if (mounted) showInfoToast(t.comicInfo.cloudCollectDisabled);
    } on FavoriteWorkflowIncompleteException catch (error) {
      if (mounted) {
        showInfoToast(error.result.message ?? '云端收藏操作未完成');
      }
    } catch (e) {
      showErrorToast(t.error.operationFailed);
    }
  }
}
