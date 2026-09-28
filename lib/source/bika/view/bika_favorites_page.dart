import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/auth/bika_setting.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_comic_card.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaFavoritesPage extends StatefulWidget {
  const BikaFavoritesPage({super.key});

  @override
  State<BikaFavoritesPage> createState() => _BikaFavoritesPageState();
}

class _BikaFavoritesPageState extends State<BikaFavoritesPage> {
  final ScrollController _scrollController = ScrollController();

  bool _loggedIn = true;
  bool _initialLoading = true;
  Object? _error;
  ComicSortType _sort = ComicSortType.dd;
  List<Doc> _comics = [];
  int _page = 1;
  int _pages = 1;
  bool _loadingMore = false;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _loggedIn = bikaNativeSetting.hasAuthorization;
    _scrollController.addListener(_onScroll);
    if (_loggedIn) _reload();
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

  int _nextSeq() {
    _requestSeq += 1;
    return _requestSeq;
  }

  Future<void> _reload() async {
    final seq = _nextSeq();
    setState(() {
      _initialLoading = true;
      _error = null;
      _page = 1;
      _pages = 1;
      _comics = [];
    });
    try {
      final resp = await fetchBikaFavoriteComics(
        UserFavoritePayload(page: 1, sort: _sort),
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = resp.comics.docs;
        _pages = resp.comics.pages;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final seq = _nextSeq();
    try {
      final resp = await fetchBikaFavoriteComics(
        UserFavoritePayload(page: 1, sort: _sort),
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = resp.comics.docs;
        _pages = resp.comics.pages;
        _page = 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      showErrorToast(e.toString());
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _initialLoading || _error != null) return;
    if (_page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final resp = await fetchBikaFavoriteComics(
        UserFavoritePayload(page: next, sort: _sort),
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _pages = resp.comics.pages;
        final existing = _comics.map((c) => c.uid).toSet();
        _comics.addAll(
          resp.comics.docs.where((c) => !existing.contains(c.uid)),
        );
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorToast(e.toString());
    }
  }

  Future<void> _selectSort(ComicSortType sort) async {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    await _reload();
  }

  Future<void> _goLogin() async {
    await context.pushRoute(const BikaLoginRoute());
    if (!mounted) return;
    final loggedIn = bikaNativeSetting.hasAuthorization;
    setState(() => _loggedIn = loggedIn);
    if (loggedIn && _comics.isEmpty && _error == null) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.favourite,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
        actions: [
          PopupMenuButton<ComicSortType>(
            tooltip: t.bika.sort,
            initialValue: _sort,
            onSelected: _selectSort,
            itemBuilder: (context) => ComicSortType.values
                .map(
                  (type) => PopupMenuItem(value: type, child: Text(type.title)),
                )
                .toList(),
            child: const Icon(Icons.sort),
          ),
        ],
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: _loggedIn ? _buildBody(context) : _buildLoginRequired(),
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            t.bika.loginRequired,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          MiuixButton(onPressed: _goLogin, child: Text(t.bika.login)),
        ],
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
            MiuixButton(onPressed: _reload, child: Text(t.bika.retry)),
          ],
        ),
      );
    }
    if (_comics.isEmpty) {
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
          BikaComicGrid(
            comics: _comics,
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
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
}
