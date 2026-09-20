import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/page/comic_read/json/common_ep_info_json/common_ep_info_json.dart';
import 'package:zephyr/page/comic_read/type/chapter_extern.dart';
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
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/widgets/toast.dart';

enum MenuOption { export, cloudCollect, follow }

/// 预览模式：前 N 张 / 后 N 张 / 起止区间。
enum _PreviewMode { top, tail, range }

/// 预览选择的持久化 key。
const String _kShowPreviewPrefKey = 'comic_info_show_preview';
const String _kPreviewModePrefKey = 'comic_info_preview_mode';
const String _kPreviewCountPrefKey = 'comic_info_preview_count';
const String _kPreviewStartPrefKey = 'comic_info_preview_start';
const String _kPreviewEndPrefKey = 'comic_info_preview_end';

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

  // ---- 预览相关状态（全部持久化） ----
  bool _showPreview = false;
  _PreviewMode _previewMode = _PreviewMode.top;
  int _previewCount = 20; // top / tail 共用
  int _previewStart = 1; // range 用
  int _previewEnd = 20; // range 用
  int _previewTotalPages = 0;
  int _previewReloadKey = 0;

  @override
  void initState() {
    super.initState();
    _type = type;
    _comicId = widget.comicId;
    _loadPreviewPrefs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPreviewPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final show = prefs.getBool(_kShowPreviewPrefKey) ?? false;
      final modeIdx = prefs.getInt(_kPreviewModePrefKey) ?? 0;
      final count = prefs.getInt(_kPreviewCountPrefKey) ?? 20;
      final start = prefs.getInt(_kPreviewStartPrefKey) ?? 1;
      final end = prefs.getInt(_kPreviewEndPrefKey) ?? 20;

      setState(() {
        _showPreview = show;
        _previewMode = _PreviewMode
            .values[modeIdx.clamp(0, _PreviewMode.values.length - 1)];
        _previewCount = count.clamp(1, 9999);
        _previewStart = start.clamp(1, 9999);
        _previewEnd = end.clamp(1, 9999);
      });
    } catch (_) {
      // 读失败就保持默认，不影响页面。
    }
  }

  Future<void> _togglePreview() async {
    final next = !_showPreview;
    setState(() => _showPreview = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kShowPreviewPrefKey, next);
    } catch (_) {
      // 写失败就只在本次会话生效。
    }
  }

  Future<void> _persistPreviewSelection({
    required _PreviewMode mode,
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
      await prefs.setInt(_kPreviewModePrefKey, mode.index);
      await prefs.setInt(_kPreviewCountPrefKey, count);
      await prefs.setInt(_kPreviewStartPrefKey, start);
      await prefs.setInt(_kPreviewEndPrefKey, end);
    } catch (_) {
      // 忽略写入失败。
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cloudFavoritePreferred = context
        .watch<GlobalSettingCubit>()
        .state
        .cloudFavoritePreferred;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          const SizedBox(width: 50),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => popToRoot(context),
          ),
          Expanded(child: Container()),
          // ---- 预览显隐切换（文字按钮，偏好持久化） ----
          TextButton.icon(
            onPressed: _togglePreview,
            icon: Icon(
              _showPreview ? Icons.image_rounded : Icons.image_outlined,
              size: 18,
            ),
            label: Text(_showPreview ? '关闭预览' : '预览'),
          ),
          BlocSelector<ComicFollowCubit, ComicFollowState, bool>(
            selector: (state) => state.isFollowing(widget.from, _comicId),
            builder: (context, isFollowing) {
              return IconButton(
                icon: Icon(
                  isFollowing
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                ),
                tooltip: isFollowing
                    ? t.comicInfo.unfollow
                    : t.comicInfo.follow,
                onPressed: () => _toggleFollow(isFollowing),
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
              final isFollowing = context.read<ComicFollowCubit>().isFollowing(
                widget.from,
                _comicId,
              );
              final menuItems = <FluentPopupMenuItem<MenuOption>>[
                FluentPopupMenuItem<MenuOption>(
                  value: MenuOption.follow,
                  leading: Icon(
                    isFollowing
                        ? Icons.notifications_off
                        : Icons.notifications_active,
                  ),
                  title: Text(
                    isFollowing ? t.comicInfo.unfollow : t.comicInfo.follow,
                  ),
                ),
              ];

              if (_type == ComicEntryType.download) {
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
                        ? (_isLocalCollected ? Icons.star : Icons.star_border)
                        : (_isCloudCollected ? Icons.star : Icons.star_border),
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
      body: BlocBuilder<GetComicInfoBloc, GetComicInfoState>(
        builder: (context, state) {
          switch (state.status) {
            case GetComicInfoStatus.initial:
              _cloudFavoriteStateOverridden = false;
              return Center(child: CircularProgressIndicator());
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
                      SizedBox(height: 10),
                      ElevatedButton(
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
      floatingActionButtonLocation:
          context.watch<GlobalSettingCubit>().state.leftHandModeEnabled
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: _loadingComplete
          ? BlocBuilder<StringSelectCubit, String>(
              builder: (context, stringSelectDate) {
                return _ReadActionButton(
                  hasHistory: stringSelectDate.isNotEmpty,
                  onPressed: () => goToComicRead(
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
        final refreshable = RefreshIndicator(
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
                          _SectionCard(
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
                                  _DescriptionCard(
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
                          _SectionCard(
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
                        _SectionCard(
                          title: t.comicInfo.chapterList,
                          trailing: _EpisodeHeaderBadge(
                            label: t.comicInfo.episodeCount(
                              count: normalComicAllInfo.eps.length,
                            ),
                            icon: _isReversed ? Icons.south : Icons.north,
                            onTap: _toggleOrder,
                          ),
                          child: _EpisodeListSection(
                            episodes: displayEps,
                            allInfo: comicInfoDyn,
                            epsLength: normalComicAllInfo.eps.length,
                            type: _type,
                            comicId: _comicId,
                            from: widget.from,
                            isReversed: _isReversed,
                          ),
                        ),
                        // ====================================================
                        // 内嵌预览图区块（可选显示，偏好持久化）
                        // ====================================================
                        if (_showPreview) ...[
                          _buildDivider(context),
                          _SectionCard(
                            title: t.comicInfo.preview,
                            trailing: _PreviewControls(
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
                            child: _InlinePreviewGrid(
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
                          _SectionCard(
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

        return refreshable;
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
    if (Platform.isIOS) {
      return getCachePath();
    }
    final customPath = globalSetting.customExportPath.trim();
    if (customPath.isNotEmpty) {
      return customPath;
    }
    if (Platform.isAndroid) {
      final granted = await requestExportPermission();
      if (!granted) {
        throw StateError(t.comicInfo.exportPermissionDenied);
      }
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
        final iosZipPath = targetZipPath;
        final iosZipFile = File(iosZipPath);
        if (await iosZipFile.exists()) {
          await iosZipFile.delete();
        }

        await exportComic(
          _comicId,
          ExportType.zip,
          widget.from,
          path: iosZipPath,
        );

        await OpenFile.open(iosZipPath);
        showSuccessToast(t.comicInfo.exportSuccess);
        _logExportPath(iosZipPath);
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
    if (mounted) {
      showSuccessToast(t.comicInfo.followed);
    }
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
    if (!context.read<GlobalSettingCubit>().state.autoFollowOnCollect) {
      return;
    }
    final info = _currentInfo;
    if (info == null) {
      return;
    }
    final followCubit = context.read<ComicFollowCubit>();
    if (followCubit.isFollowing(widget.from, _comicId)) {
      return;
    }
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
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    await context.read<ComicFollowCubit>().removeFollow(widget.from, _comicId);
    if (mounted) {
      showSuccessToast(t.comicInfo.unfollowed);
    }
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
    if (_localCollectSyncedFor == comicId) {
      return;
    }
    _localCollectSyncedFor = comicId;
    final collected = await isLocalComicCollected(
      from: widget.from,
      comicId: comicId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isLocalCollected = collected;
    });
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
        if (!confirmed) {
          return;
        }
      }

      final next = await toggleLocalComicFavorite(
        from: widget.from,
        normalInfo: info,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLocalCollected = next;
      });
      if (next) {
        await _autoFollowIfEnabled();
      }
      showSuccessToast(
        next
            ? t.comicInfo.addedToCollection
            : t.comicInfo.removedFromCollection,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showErrorToast(
        t.comicInfo.localCollectFailed(error: normalizeSearchErrorMessage(e)),
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<bool> _showLocalUncollectConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
        );
      },
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isCloudCollected = next;
        _cloudFavoriteStateOverridden = true;
      });
      if (next) {
        await _autoFollowIfEnabled();
      }
      showSuccessToast(
        next
            ? t.comicInfo.cloudCollectSuccess
            : t.comicInfo.cloudUncollectSuccess,
      );
    } on FavoriteWorkflowUnsupportedException {
      if (mounted) {
        showInfoToast(t.comicInfo.cloudCollectDisabled);
      }
    } on FavoriteWorkflowIncompleteException catch (error) {
      if (mounted) {
        showInfoToast(error.result.message ?? '云端收藏操作未完成');
      }
    } catch (e) {
      showErrorToast(t.error.operationFailed);
    }
  }
}

// ============================================================================
// 预览区块控件：模式/参数选择 + 刷新
// ============================================================================
class _PreviewControls extends StatelessWidget {
  const _PreviewControls({
    required this.mode,
    required this.count,
    required this.start,
    required this.end,
    required this.totalPages,
    required this.onSelectionChanged,
    required this.onRefresh,
  });

  final _PreviewMode mode;
  final int count;
  final int start;
  final int end;
  final int totalPages;

  /// (mode, count, start, end)
  final void Function(_PreviewMode mode, int count, int start, int end)
  onSelectionChanged;
  final VoidCallback onRefresh;

  String get _label {
    switch (mode) {
      case _PreviewMode.top:
        return '前 $count 张';
      case _PreviewMode.tail:
        return '后 $count 张';
      case _PreviewMode.range:
        return '$start-$end';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- 预览范围胶囊 ----
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            final result = await showDialog<_PreviewSelection>(
              context: context,
              builder: (_) => _PreviewPickerDialog(
                initialMode: mode,
                initialCount: count,
                initialStart: start,
                initialEnd: end,
                maxPages: totalPages,
              ),
            );
            if (result != null) {
              onSelectionChanged(
                result.mode,
                result.count,
                result.start,
                result.end,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 14),
                const SizedBox(width: 4),
                Text(
                  _label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '刷新预览',
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

/// 对话框返回值。
class _PreviewSelection {
  const _PreviewSelection({
    required this.mode,
    required this.count,
    required this.start,
    required this.end,
  });

  final _PreviewMode mode;
  final int count;
  final int start;
  final int end;
}

/// 预览参数选择对话框。
///
/// - 顶部分段选择模式：前 N / 后 N / 起止范围
/// - 根据模式显示对应输入框
/// - [maxPages] 为 0 表示总页数未知，此时跳过上界校验
class _PreviewPickerDialog extends StatefulWidget {
  const _PreviewPickerDialog({
    required this.initialMode,
    required this.initialCount,
    required this.initialStart,
    required this.initialEnd,
    required this.maxPages,
  });

  final _PreviewMode initialMode;
  final int initialCount;
  final int initialStart;
  final int initialEnd;
  final int maxPages;

  @override
  State<_PreviewPickerDialog> createState() => _PreviewPickerDialogState();
}

class _PreviewPickerDialogState extends State<_PreviewPickerDialog> {
  late _PreviewMode _mode;
  late final TextEditingController _countController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _countController = TextEditingController(
      text: widget.initialCount.toString(),
    );
    _startController = TextEditingController(
      text: widget.initialStart.toString(),
    );
    _endController = TextEditingController(text: widget.initialEnd.toString());
  }

  @override
  void dispose() {
    _countController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _applyCountPreset(int n) {
    setState(() {
      _countController.text = n.toString();
      _error = null;
    });
  }

  void _applyRangePreset(int start, int end) {
    setState(() {
      _startController.text = start.toString();
      _endController.text = end.toString();
      _error = null;
    });
  }

  void _submit() {
    final maxPages = widget.maxPages;

    if (_mode == _PreviewMode.top || _mode == _PreviewMode.tail) {
      final n = int.tryParse(_countController.text.trim());
      if (n == null) {
        setState(() => _error = '请输入有效数字');
        return;
      }
      if (n < 1) {
        setState(() => _error = '数量不能小于 1');
        return;
      }
      if (maxPages > 0 && n > maxPages) {
        // 用户给了比总页数还大的数，直接 clamp 而不是报错
        // 让用户"输入 999 就是全部"更顺手。
        Navigator.of(context).pop(
          _PreviewSelection(
            mode: _mode,
            count: maxPages,
            start: widget.initialStart,
            end: widget.initialEnd,
          ),
        );
        return;
      }
      Navigator.of(context).pop(
        _PreviewSelection(
          mode: _mode,
          count: n,
          start: widget.initialStart,
          end: widget.initialEnd,
        ),
      );
      return;
    }

    // range
    final start = int.tryParse(_startController.text.trim());
    final end = int.tryParse(_endController.text.trim());
    if (start == null || end == null) {
      setState(() => _error = '请输入有效数字');
      return;
    }
    if (start < 1) {
      setState(() => _error = '起始页不能小于 1');
      return;
    }
    if (end < start) {
      setState(() => _error = '结束页不能小于起始页');
      return;
    }
    if (maxPages > 0 && start > maxPages) {
      setState(() => _error = '起始页不能超过总页数 $maxPages');
      return;
    }
    Navigator.of(context).pop(
      _PreviewSelection(
        mode: _mode,
        count: widget.initialCount,
        start: start,
        end: end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('预览范围'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.maxPages > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '本章共 ${widget.maxPages} 页',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // ---- 模式分段选择 ----
            SegmentedButton<_PreviewMode>(
              segments: const [
                ButtonSegment(
                  value: _PreviewMode.top,
                  label: Text('前 N 张'),
                  icon: Icon(Icons.vertical_align_top, size: 16),
                ),
                ButtonSegment(
                  value: _PreviewMode.tail,
                  label: Text('后 N 张'),
                  icon: Icon(Icons.vertical_align_bottom, size: 16),
                ),
                ButtonSegment(
                  value: _PreviewMode.range,
                  label: Text('范围'),
                  icon: Icon(Icons.tune, size: 16),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() {
                  _mode = s.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // ---- 输入区（根据模式切换） ----
            if (_mode == _PreviewMode.top || _mode == _PreviewMode.tail) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _countController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _mode == _PreviewMode.top
                            ? '前 N 张'
                            : '后 N 张',
                        isDense: true,
                        suffixText: '张',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _countChip(20),
                  _countChip(50),
                  _countChip(100),
                  if (widget.maxPages > 0)
                    ActionChip(
                      label: Text('全部 (${widget.maxPages})'),
                      onPressed: () => _applyCountPreset(widget.maxPages),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    _countChip(200),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '从（页）',
                        isDense: true,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _endController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '到（页）',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rangeChip('1-20', 1, 20),
                  _rangeChip('1-50', 1, 50),
                  _rangeChip('1-100', 1, 100),
                  if (widget.maxPages > 0)
                    _rangeChip('全部 (1-${widget.maxPages})', 1, widget.maxPages),
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(t.common.ok)),
      ],
    );
  }

  Widget _countChip(int n) {
    return ActionChip(
      label: Text('$n'),
      onPressed: () => _applyCountPreset(n),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _rangeChip(String label, int start, int end) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyRangePreset(start, end),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ============================================================================
// 内嵌预览图组件
//
// 走和阅读器相同的图片管线：
//   PageBloc  → 取章节 docs
//   PictureBloc → GetPicture(PictureInfo) → getCachePicture
//               完成分片还原并落地为本地文件
//   Image.file  → 从本地文件渲染
//
// 直接用 Image.network(fileServer) 会看到错位（JMComic 图是分片重排的）。
// ============================================================================
class _InlinePreviewGrid extends StatefulWidget {
  const _InlinePreviewGrid({
    super.key,
    required this.comicId,
    required this.from,
    required this.type,
    required this.comicInfo,
    required this.firstEp,
    this.mode = _PreviewMode.top,
    this.count = 20,
    this.startPage = 1,
    this.endPage = 20,
    this.onTotalResolved,
  });

  final String comicId;
  final String from;
  final ComicEntryType type;
  final dynamic comicInfo;
  final dynamic firstEp;

  /// 预览模式：前 N / 后 N / 起止范围。
  final _PreviewMode mode;

  /// 前 N / 后 N 使用的数量。
  final int count;

  /// 起止范围（1-indexed，闭区间）。
  final int startPage;
  final int endPage;

  /// 首次拿到 docs 时回调总页数。
  final ValueChanged<int>? onTotalResolved;

  @override
  State<_InlinePreviewGrid> createState() => _InlinePreviewGridState();
}

class _InlinePreviewGridState extends State<_InlinePreviewGrid> {
  int _lastReportedTotal = -1;

  @override
  Widget build(BuildContext context) {
    final firstEp = widget.firstEp;

    if (firstEp == null) {
      return _buildGrid(context, const <Doc>[]);
    }

    final dynamic ep = firstEp;
    final int epsId = _asInt(_tryRead(ep, 'order'), 0);
    final String chapterId = _asString(_tryRead(ep, 'id'), '');
    final dynamic rawExtern = _tryRead(ep, 'extern');
    final Map<String, dynamic> epExtern = rawExtern is Map
        ? Map<String, dynamic>.from(rawExtern)
        : const <String, dynamic>{};
    final String requestId = _asString(epExtern['requestId'], '');
    final String storageChapterId = _asString(epExtern['storageChapterId'], '');
    final String logicalKey = _asString(epExtern['logicalKey'], '');
    final ChapterExtern chapterExtern =
        (epExtern['chapterExtern'] as ChapterExtern?) ??
        const <String, dynamic>{};

    return BlocProvider(
      key: ValueKey('inline-preview:${widget.from}:${widget.comicId}'),
      create: (_) {
        return PageBloc()..add(
          PageEvent(
            widget.comicId,
            epsId,
            chapterId,
            requestId,
            storageChapterId,
            logicalKey,
            chapterExtern,
            widget.from,
            widget.type,
            comicInfo: widget.comicInfo,
          ),
        );
      },
      child: BlocBuilder<PageBloc, PageState>(
        builder: (context, state) {
          switch (state.status) {
            case PageStatus.initial:
            case PageStatus.failure:
              return _buildGrid(context, const <Doc>[]);
            case PageStatus.success:
              final docs = state.epInfo?.docs ?? const <Doc>[];
              _maybeReportTotal(docs.length);
              return _buildGrid(context, docs);
          }
        },
      ),
    );
  }

  void _maybeReportTotal(int total) {
    if (total <= 0) return;
    if (_lastReportedTotal == total) return;
    _lastReportedTotal = total;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTotalResolved?.call(total);
    });
  }

  /// 根据 mode 从完整 docs 里切出要预览的部分。
  ///
  /// - top  : 取前 N 张（N = count）
  /// - tail : 取后 N 张（N = count）
  /// - range: 取 [start, end] 闭区间（1-indexed）
  /// N 或 start/end 超出总数时自动 clamp，不崩溃。
  List<Doc> _sliceDocs(List<Doc> all) {
    if (all.isEmpty) return const <Doc>[];
    final total = all.length;

    switch (widget.mode) {
      case _PreviewMode.top:
        final n = widget.count.clamp(1, total);
        return all.take(n).toList(growable: false);
      case _PreviewMode.tail:
        final n = widget.count.clamp(1, total);
        return all.skip(total - n).toList(growable: false);
      case _PreviewMode.range:
        final start = widget.startPage.clamp(1, total);
        final end = widget.endPage < start
            ? start
            : widget.endPage.clamp(start, total);
        return all.sublist(start - 1, end);
    }
  }

  String _buildInfoText(List<Doc> docs, List<Doc> sliced, bool hasData) {
    if (!hasData) return '正在加载章节数据…';
    final totalInChapter = docs.length;
    if (sliced.isEmpty) {
      return '所选范围超出本章页数（共 $totalInChapter 页）';
    }
    switch (widget.mode) {
      case _PreviewMode.top:
        return '前 ${sliced.length} 张 / 共 $totalInChapter 页';
      case _PreviewMode.tail:
        return '后 ${sliced.length} 张 / 共 $totalInChapter 页';
      case _PreviewMode.range:
        final first = _displayIndex(sliced.first, docs) + 1;
        final last = _displayIndex(sliced.last, docs) + 1;
        return '第 $first-$last 页 / 共 $totalInChapter 页';
    }
  }

  Widget _buildGrid(BuildContext context, List<Doc> docs) {
    final hasData = docs.isNotEmpty;
    final sliced = _sliceDocs(docs);
    final shownCount = sliced.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 窄屏 2 列、宽屏 3 列。
        final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;

        const spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * spacing) /
            crossAxisCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 页数信息 ----
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 14,
                    color: context.textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _buildInfoText(docs, sliced, hasData),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---- 图片网格 ----
            if (!hasData || shownCount == 0)
              // 数据未到 或 范围取不到 → 用若干占位撑一下高度
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (int i = 0; i < _placeholderCount(); i++)
                    SizedBox(
                      width: tileWidth,
                      child: const _PreviewPlaceholderTile(),
                    ),
                ],
              )
            else
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (int i = 0; i < sliced.length; i++)
                    SizedBox(
                      width: tileWidth,
                      child: _PreviewTile(
                        key: ValueKey(
                          '${sliced[i].storageChapterId}|${sliced[i].fileServer}|${sliced[i].path}',
                        ),
                        doc: sliced[i],
                        comicId: widget.comicId,
                        from: widget.from,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  int _placeholderCount() {
    int want;
    switch (widget.mode) {
      case _PreviewMode.top:
      case _PreviewMode.tail:
        want = widget.count;
        break;
      case _PreviewMode.range:
        want = widget.endPage - widget.startPage + 1;
        break;
    }
    if (want <= 0) return 4;
    return want.clamp(1, 20);
  }

  /// 找到 doc 在 all 中的下标；找不到返回 0。
  int _displayIndex(Doc doc, List<Doc> all) {
    final idx = all.indexOf(doc);
    return idx < 0 ? 0 : idx;
  }

  static dynamic _tryRead(dynamic target, String name) {
    try {
      switch (name) {
        case 'order':
          return target.order;
        case 'id':
          return target.id;
        case 'extern':
          return target.extern;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static String _asString(dynamic v, String fallback) {
    if (v is String) return v;
    return fallback;
  }
}

// ----------------------------------------------------------------------------
// 单张预览图
//
// 走和阅读器完全相同的管线：
//   PictureBloc → GetPicture(PictureInfo) → getCachePicture
//   → 拿到已还原的本地文件路径 → Image.file 显示。
//
// 图片宽度撑满格子、高度按真实比例撑开：无留白、无裁切。
// 点击可进入全屏查看（支持双击放大/还原）。
// ----------------------------------------------------------------------------
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    super.key,
    required this.doc,
    required this.comicId,
    required this.from,
  });

  final Doc doc;
  final String comicId;
  final String from;

  @override
  Widget build(BuildContext context) {
    final resolvedChapterId = doc.storageChapterId.trim().isNotEmpty
        ? doc.storageChapterId
        : comicId;

    final pictureInfo = PictureInfo(
      from: from,
      url: doc.fileServer,
      path: doc.path,
      cartoonId: comicId,
      chapterId: resolvedChapterId,
      pictureType: PictureType.page,
      extern: doc.extern,
    );

    return BlocProvider(
      create: (_) => PictureBloc()..add(GetPicture(pictureInfo)),
      child: BlocBuilder<PictureBloc, PictureLoadState>(
        builder: (context, state) {
          switch (state.status) {
            case PictureLoadStatus.initial:
            case PictureLoadStatus.failure:
              return const _PreviewPlaceholderTile();
            case PictureLoadStatus.success:
              final imagePath = state.imagePath;
              if (imagePath == null || imagePath.isEmpty) {
                return const _PreviewPlaceholderTile();
              }
              return GestureDetector(
                onTap: () => _openFullImage(context, imagePath),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(imagePath),
                    // 宽度撑满格子，高度按真实比例撑开（不给 height）。
                    fit: BoxFit.fitWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        const _PreviewPlaceholderTile(),
                  ),
                ),
              );
          }
        },
      ),
    );
  }

  void _openFullImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullImagePage(imagePath: imagePath),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 预览图占位块
//
// 用 AspectRatio 给一个稳定的占位比例，避免加载前布局塌陷。
// ----------------------------------------------------------------------------
class _PreviewPlaceholderTile extends StatelessWidget {
  const _PreviewPlaceholderTile();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AspectRatio(
      aspectRatio: 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 28,
            color: context.textColor.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 全屏查看单张图片
//
// 支持：
//   - 双指缩放 / 拖动（InteractiveViewer）
//   - 双击放大到 2.5 倍（以双击点为中心）
//   - 放大状态下再次双击还原
//   - 缩放到 1.0 以下后双击直接跳到 2.5 倍
// ----------------------------------------------------------------------------
class _FullImagePage extends StatefulWidget {
  const _FullImagePage({required this.imagePath});

  final String imagePath;

  @override
  State<_FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<_FullImagePage> {
  static const double _doubleTapScale = 2.5;
  static const double _resetThreshold = 1.01;

  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    // 已经放大 → 双击还原
    if (currentScale > _resetThreshold) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    // 未放大 → 以双击位置为锚点放大
    final details = _doubleTapDetails;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (details == null || renderBox == null || !renderBox.hasSize) {
      return;
    }

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final matrix = Matrix4.identity()
      ..translateByDouble(
        renderBox.size.width / 2 - localPosition.dx * _doubleTapScale,
        renderBox.size.height / 2 - localPosition.dy * _doubleTapScale,
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);

    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.8,
          maxScale: 5.0,
          child: Center(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.title, this.trailing});

  final String? title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: context.theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _EpisodeHeaderBadge extends StatelessWidget {
  const _EpisodeHeaderBadge({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: context.theme.colorScheme.outlineVariant.withValues(
                alpha: 0.3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: context.textColor.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textColor.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final descriptionStyle = context.theme.textTheme.bodyMedium?.copyWith(
      height: 1.65,
      color: context.textColor.withValues(alpha: 0.9),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.comicInfo.description,
            style: context.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            widget.description,
            style: descriptionStyle,
            maxLines: _expanded ? null : 5,
          ),
          if (widget.description.length > 90) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _expanded ? t.comicInfo.collapse : t.comicInfo.expandFullText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EpisodeListSection extends StatelessWidget {
  const _EpisodeListSection({
    required this.episodes,
    required this.allInfo,
    required this.epsLength,
    required this.type,
    required this.comicId,
    required this.from,
    required this.isReversed,
  });

  final List<dynamic> episodes;
  final dynamic allInfo;
  final int epsLength;
  final ComicEntryType type;
  final String comicId;
  final String from;
  final bool isReversed;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          t.comicInfo.noChapters,
          style: context.theme.textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (var i = 0; i < episodes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EpButtonWidget(
                    doc: episodes[i] as Ep,
                    allInfo: allInfo,
                    epsLength: epsLength,
                    type: type,
                    comicId: comicId,
                    from: from,
                    index: i,
                    isReversed: isReversed,
                  ),
                ),
            ],
          );
        }

        final isDesktop = constraints.maxWidth >= 960;
        if (isDesktop) {
          return Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < episodes.length; i++)
                  SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EpButtonWidget(
                        doc: episodes[i] as Ep,
                        allInfo: allInfo,
                        epsLength: epsLength,
                        type: type,
                        comicId: comicId,
                        from: from,
                        index: i,
                        isReversed: isReversed,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final isWide = constraints.maxWidth >= 720;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: EpButtonWidget.fixedHeight,
          ),
          itemBuilder: (context, index) {
            final e = episodes[index] as Ep;
            return EpButtonWidget(
              doc: e,
              allInfo: allInfo,
              epsLength: epsLength,
              type: type,
              comicId: comicId,
              from: from,
              index: index,
              isReversed: isReversed,
            );
          },
        );
      },
    );
  }
}

class _ReadActionButton extends StatelessWidget {
  const _ReadActionButton({required this.hasHistory, required this.onPressed});

  final bool hasHistory;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(
        hasHistory ? Icons.history_rounded : Icons.menu_book_rounded,
        size: 18,
      ),
      label: Text(
        hasHistory ? t.comicInfo.continueRead : t.comicInfo.startRead,
      ),
    );
  }
}
