import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart'
    show ComicReadRoute, EhCommentsRoute, EhLoginRoute;
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';
import 'package:zephyr/source/eh/utils/eh_detail_convert.dart';
import 'package:zephyr/source/eh/view/widgets/eh_thumb_image.dart';
import 'package:zephyr/type/enum.dart';

@RoutePage()
class EhDetailPage extends StatelessWidget {
  const EhDetailPage({super.key, required this.gid, required this.token});

  final String gid;
  final String token;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StringSelectCubit(),
      child: _EhDetailView(gid: gid, token: token),
    );
  }
}

class _EhDetailView extends StatefulWidget {
  const _EhDetailView({required this.gid, required this.token});

  final String gid;
  final String token;

  @override
  State<_EhDetailView> createState() => _EhDetailViewState();
}

class _EhDetailViewState extends State<_EhDetailView> {
  bool _loading = true;
  bool _loginRequired = false;
  Object? _error;
  EhGalleryDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loginRequired = false;
      _error = null;
    });
    try {
      final detail = await fetchEhGalleryDetail(widget.gid, widget.token);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on EhLoginRequiredException {
      if (!mounted) return;
      setState(() {
        _loginRequired = true;
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
    await context.pushRoute(const EhLoginRoute());
    if (!mounted) return;
    _load();
  }

  void _openReader(BuildContext context) {
    final detail = _detail;
    if (detail == null) return;
    final info = buildEhNormalComicInfo(detail);
    context.pushRoute(
      ComicReadRoute(
        comicId: detail.gid,
        order: 1,
        epsNumber: 1,
        from: 'eh',
        type: ComicEntryType.normal,
        comicInfo: buildEhDetailSource(info),
        stringSelectCubit: context.read<StringSelectCubit>(),
        chapterExtern: {'token': detail.token},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.appName,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loginRequired) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.eh.loginRequired,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            MiuixButton(onPressed: _goLogin, child: Text(t.eh.login)),
          ],
        ),
      );
    }
    if (_error != null || _detail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.eh.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _load, child: Text(t.eh.retry)),
          ],
        ),
      );
    }
    return _buildDetail(context, _detail!);
  }

  Widget _buildDetail(BuildContext context, EhGalleryDetail detail) {
    final theme = Theme.of(context);
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
                height: 165,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: EhThumbImage(
                    url: detail.coverUrl,
                    cacheKey: 'eh-${detail.gid}-cover',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.titleJpn.isNotEmpty &&
                        detail.titleJpn != detail.title) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail.titleJpn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                            detail.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        Text(
                          detail.rating >= 0
                              ? detail.rating.toStringAsFixed(1)
                              : '-',
                          style: theme.textTheme.labelSmall,
                        ),
                        if (detail.simpleLanguage.isNotEmpty)
                          Text(
                            '[${detail.simpleLanguage}]',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (detail.uploader.isNotEmpty)
                          '${t.eh.uploader}: ${detail.uploader}',
                        if (detail.uploaded.isNotEmpty)
                          '${t.eh.uploaded}: ${detail.uploaded}',
                        if (detail.pages > 0)
                          '${t.eh.pages}: ${detail.pages}',
                      ].join('\n'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.tagGroups.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final group in detail.tagGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        group.namespace,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in group.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: MiuixButton(
              onPressed: detail.pages > 0 ? () => _openReader(context) : null,
              child: Text(t.eh.readNow),
            ),
          ),
          if (detail.commentsCount > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.pushRoute(
                  EhCommentsRoute(gid: detail.gid, token: detail.token),
                ),
                icon: const Icon(Icons.comment_outlined, size: 18),
                label: Text('${t.eh.comments} (${detail.commentsCount})'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
