import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart'
    show BikaCommentsRoute, BikaDetailRoute, BikaLoginRoute, ComicReadRoute;
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/api/bika_client.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/utils/bika_detail_convert.dart';
import 'package:zephyr/source/bika/view/widgets/bika_cover_image.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaDetailPage extends StatelessWidget {
  const BikaDetailPage({super.key, required this.comicId});

  final String comicId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StringSelectCubit(),
      child: _BikaDetailView(comicId: comicId),
    );
  }
}

class _BikaDetailView extends StatefulWidget {
  const _BikaDetailView({required this.comicId});

  final String comicId;

  @override
  State<_BikaDetailView> createState() => _BikaDetailViewState();
}

class _BikaDetailViewState extends State<_BikaDetailView> {
  bool _loading = true;
  bool _unauthorized = false;
  Object? _error;
  Comic? _comic;
  List<Chapter> _chapters = [];
  List<RecommendComic> _recommendations = [];

  bool _isLiked = false;
  bool _isFavourite = false;
  int _likesCount = 0;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _unauthorized = false;
      _error = null;
    });
    try {
      final detailsFuture = fetchBikaComicDetails(widget.comicId);
      final chaptersFuture = fetchBikaChapters(widget.comicId).catchError(
        (Object e) => const <Chapter>[],
      );
      final recommendFuture = fetchBikaComicRecommendation(widget.comicId)
          .catchError((Object e) => RecommendComics(comics: const []));
      final details = await detailsFuture;
      final chapters = await chaptersFuture;
      final recommendations = await recommendFuture;
      if (!mounted) return;
      setState(() {
        _comic = details.comic;
        _chapters = chapters;
        _recommendations = recommendations.comics;
        _isLiked = details.comic.isLiked;
        _isFavourite = details.comic.isFavourite;
        _likesCount = details.comic.likesCount;
        _loading = false;
      });
    } on BikaUnauthorizedException {
      if (!mounted) return;
      setState(() {
        _unauthorized = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _goLogin() async {
    await context.pushRoute(const BikaLoginRoute());
    if (!mounted) return;
    _load();
  }

  Future<void> _like() async {
    final comic = _comic;
    if (comic == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await likeBikaComic(comic.id);
      if (!mounted) return;
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
        _actionLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      showErrorToast(e.toString());
    }
  }

  Future<void> _favourite() async {
    final comic = _comic;
    if (comic == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await favoriteBikaComic(comic.id);
      if (!mounted) return;
      setState(() {
        _isFavourite = !_isFavourite;
        _actionLoading = false;
      });
      showSuccessToast(_isFavourite ? t.bika.favouriteAdded : t.bika.favouriteRemoved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      showErrorToast(e.toString());
    }
  }

  void _openReader(BuildContext context, Chapter chapter, int epsCount) {
    final comic = _comic;
    if (comic == null) return;
    final info = buildBikaNormalComicInfo(comic, _chapters);
    context.pushRoute(
      ComicReadRoute(
        comicId: comic.id,
        order: chapter.order,
        chapterId: chapter.uid,
        logicalKey: chapter.uid,
        epsNumber: epsCount,
        from: bikaSourceId,
        type: ComicEntryType.normal,
        comicInfo: buildBikaDetailSource(info),
        stringSelectCubit: context.read<StringSelectCubit>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.appName,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_unauthorized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.bika.loginRequired, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            MiuixButton(onPressed: _goLogin, child: Text(t.bika.login)),
          ],
        ),
      );
    }
    if (_error != null || _comic == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.bika.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _load, child: Text(t.bika.retry)),
          ],
        ),
      );
    }
    return _buildDetail(context);
  }

  Widget _buildDetail(BuildContext context) {
    final comic = _comic!;
    final theme = Theme.of(context);
    final epsCount = _chapters.isNotEmpty ? _chapters.length : comic.epsCount;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BikaCoverImage(image: comic.thumb),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comic.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (comic.author == null || comic.author!.isEmpty)
                          ? comic.creator.name
                          : comic.author!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            comic.finished
                                ? t.bika.finished
                                : t.bika.serializing,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        for (final category in comic.categories)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (comic.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tag in comic.tags)
                            Text(
                              '#$tag',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(theme, Icons.visibility_outlined, t.bika.views,
                  comic.totalViews),
              _buildStat(theme, Icons.favorite_outline, t.bika.likes,
                  comic.totalLikes),
              _buildStat(theme, Icons.description_outlined, t.bika.pages,
                  comic.pagesCount),
              _buildStat(theme, Icons.format_list_numbered, t.bika.chapters,
                  comic.epsCount),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _actionLoading ? null : _like,
                icon: Icon(
                  _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: _isLiked ? theme.colorScheme.primary : null,
                ),
              ),
              Text(
                '$_likesCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isLiked ? theme.colorScheme.primary : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _actionLoading ? null : _favourite,
                icon: Icon(
                  _isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavourite ? theme.colorScheme.primary : null,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    context.pushRoute(BikaCommentsRoute(comicId: comic.id)),
                icon: const Icon(Icons.comment_outlined, size: 18),
                label: Text('${comic.totalComments ?? comic.commentsCount}'),
              ),
            ],
          ),
          if (comic.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comic.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          _buildReadSection(context, theme, comic, epsCount),
          if (_recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              t.bika.recommendation,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _buildRecommendCard(_recommendations[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(
    ThemeData theme,
    IconData icon,
    String label,
    int value,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 2),
        Text('$value', style: theme.textTheme.labelLarge),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReadSection(
    BuildContext context,
    ThemeData theme,
    Comic comic,
    int epsCount,
  ) {
    if (epsCount <= 0) return const SizedBox.shrink();
    if (epsCount == 1 || _chapters.length <= 1) {
      final chapter = _chapters.isNotEmpty
          ? _chapters.first
          : Chapter(
              uid: '',
              title: '',
              order: 1,
              updated_at: '',
              id: comic.id,
            );
      return SizedBox(
        width: double.infinity,
        child: MiuixButton(
          onPressed: () => _openReader(context, chapter, epsCount),
          child: Text(t.bika.readNow),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t.bika.chapters} (${_chapters.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        for (final chapter in _chapters)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openReader(context, chapter, epsCount),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${chapter.order}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendCard(RecommendComic comic) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 110,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.pushRoute(BikaDetailRoute(comicId: comic.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 146,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BikaCoverImage(image: comic.thumb),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                comic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
