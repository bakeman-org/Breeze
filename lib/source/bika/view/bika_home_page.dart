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
class BikaHomePage extends StatefulWidget {
  const BikaHomePage({super.key});

  @override
  State<BikaHomePage> createState() => _BikaHomePageState();
}

class _BikaHomePageState extends State<BikaHomePage> {
  final ScrollController _scrollController = ScrollController();

  bool _loggedIn = true;
  bool _initialLoading = true;
  Object? _error;
  List<Category> _categories = [];
  String? _selectedCategory;
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
      final results = await Future.wait([
        fetchBikaComics(
          ComicsPayload(page: 1, c: _selectedCategory, s: _sort),
        ),
        fetchBikaCategories(),
      ]);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = (results[0] as ComicsResponse).comics.docs;
        _pages = (results[0] as ComicsResponse).comics.pages;
        _categories = (results[1] as CategoriesResponse).categories;
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
      final results = await Future.wait([
        fetchBikaComics(
          ComicsPayload(page: 1, c: _selectedCategory, s: _sort),
        ),
        fetchBikaCategories(),
      ]);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = (results[0] as ComicsResponse).comics.docs;
        _pages = (results[0] as ComicsResponse).comics.pages;
        _categories = (results[1] as CategoriesResponse).categories;
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
      final resp = await fetchBikaComics(
        ComicsPayload(page: next, c: _selectedCategory, s: _sort),
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _pages = resp.comics.pages;
        final existing = _comics.map((c) => c.uid).toSet();
        _comics.addAll(resp.comics.docs.where((c) => !existing.contains(c.uid)));
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorToast(e.toString());
    }
  }

  Future<void> _selectCategory(String? category) async {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    await _reload();
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
        title: t.bika.appName,
        actions: [
          MiuixIconButton(
            onPressed: () => context.pushRoute(const BikaSearchRoute()),
            child: const Icon(Icons.search),
          ),
          MiuixIconButton(
            onPressed: () => context.pushRoute(const BikaRankRoute()),
            child: const Icon(Icons.leaderboard),
          ),
          MiuixIconButton(
            onPressed: () => context.pushRoute(const BikaMineRoute()),
            child: const Icon(Icons.person_outline),
          ),
        ],
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: _loggedIn ? _buildContent(context) : _buildLoginRequired(),
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(t.bika.loginRequired, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          MiuixButton(
            onPressed: _goLogin,
            child: Text(t.bika.login),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.bika.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _reload, child: Text(t.bika.retry)),
          ],
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              ChoiceChip(
                label: Text(t.bika.allCategories),
                selected: _selectedCategory == null,
                onSelected: (_) => _selectCategory(null),
              ),
              for (final category in _categories) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(category.title),
                  selected: _selectedCategory == category.title,
                  onSelected: (_) => _selectCategory(category.title),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Spacer(),
              PopupMenuButton<ComicSortType>(
                tooltip: t.bika.sort,
                initialValue: _sort,
                onSelected: _selectSort,
                itemBuilder: (context) => ComicSortType.values
                    .map(
                      (type) => PopupMenuItem(
                        value: type,
                        child: Text(type.title),
                      ),
                    )
                    .toList(),
                child: const Icon(Icons.sort),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _comics.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [BikaListEmptyView()],
                  )
                : Stack(
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
          ),
        ),
      ],
    );
  }
}
