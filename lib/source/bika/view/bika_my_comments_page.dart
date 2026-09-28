import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_comic_card.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaMyCommentsPage extends StatefulWidget {
  const BikaMyCommentsPage({super.key});

  @override
  State<BikaMyCommentsPage> createState() => _BikaMyCommentsPageState();
}

class _BikaMyCommentsPageState extends State<BikaMyCommentsPage> {
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = true;
  Object? _error;
  List<PersonalComment> _comments = [];
  int _page = 1;
  int _pages = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final resp = await fetchBikaPersonalComments(1);
      if (!mounted) return;
      setState(() {
        _comments = List.from(resp.comments.docs);
        _pages = resp.comments.pages;
        _page = 1;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final resp = await fetchBikaPersonalComments(1);
      if (!mounted) return;
      setState(() {
        _comments = List.from(resp.comments.docs);
        _pages = resp.comments.pages;
        _page = 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorToast(e.toString());
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _initialLoading || _error != null) return;
    if (_page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final resp = await fetchBikaPersonalComments(next);
      if (!mounted) return;
      setState(() {
        _page = next;
        _pages = resp.comments.pages;
        final existing = _comments.map((c) => c.uid).toSet();
        _comments.addAll(
          resp.comments.docs.where((c) => !existing.contains(c.uid)),
        );
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorToast(e.toString());
    }
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.myComments,
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
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.bika.networkError,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _load, child: Text(t.bika.retry)),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [BikaListEmptyView()],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: _comments.length,
            itemBuilder: (context, index) =>
                _buildItem(context, _comments[index]),
          ),
          if (_loadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, PersonalComment comment) {
    final theme = Theme.of(context);
    final comic = comment.comic;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(comment.content, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (comic != null)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () =>
                    context.pushRoute(BikaDetailRoute(comicId: comic.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    comic.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 14,
                  color: comment.isLiked
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${comment.likesCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(comment.created_at),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
