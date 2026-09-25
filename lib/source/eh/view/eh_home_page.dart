import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';
import 'package:zephyr/source/eh/view/widgets/eh_gallery_list_item.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class EhHomePage extends StatefulWidget {
  const EhHomePage({super.key});

  @override
  State<EhHomePage> createState() => _EhHomePageState();
}

class _EhHomePageState extends State<EhHomePage> {
  final ScrollController _scrollController = ScrollController();

  static final List<EhGalleryCategory> _categories = EhGalleryCategory.values
      .where((c) => c.bit & ehAllCategoryBits != 0)
      .toList();

  bool _initialLoading = true;
  Object? _error;
  EhGalleryCategory? _selectedCategory;
  List<EhGalleryInfo> _items = [];
  int _page = 0;
  int _maxPage = 1;
  bool _loadingMore = false;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
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

  int? get _categoryMask => _selectedCategory?.bit;

  Future<void> _reload() async {
    final seq = _nextSeq();
    setState(() {
      _initialLoading = true;
      _error = null;
      _page = 0;
      _maxPage = 1;
      _items = [];
    });
    try {
      final resp = await fetchEhGalleryList(
        categoryMask: _categoryMask,
        page: 0,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = resp.items;
        _maxPage = resp.maxPage;
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
      final resp = await fetchEhGalleryList(
        categoryMask: _categoryMask,
        page: 0,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = resp.items;
        _maxPage = resp.maxPage;
        _page = 0;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      showErrorToast(e.toString());
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _initialLoading || _error != null) return;
    if (_page >= _maxPage - 1) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final resp = await fetchEhGalleryList(
        categoryMask: _categoryMask,
        page: next,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _maxPage = resp.maxPage;
        final existing = _items.map((e) => e.gid).toSet();
        _items.addAll(resp.items.where((e) => !existing.contains(e.gid)));
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorToast(e.toString());
    }
  }

  Future<void> _selectCategory(EhGalleryCategory? category) async {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.appName,
        actions: [
          MiuixIconButton(
            onPressed: () => context.pushRoute(const EhSearchRoute()),
            child: const Icon(Icons.search),
          ),
          MiuixIconButton(
            onPressed: () => context.pushRoute(const EhPopularRoute()),
            child: const Icon(Icons.local_fire_department_outlined),
          ),
          MiuixIconButton(
            onPressed: () => context.pushRoute(const EhFavoritesRoute()),
            child: const Icon(Icons.favorite_border),
          ),
          MiuixIconButton(
            onPressed: () => context.pushRoute(const EhSettingsRoute()),
            child: const Icon(Icons.settings_outlined),
          ),
        ],
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
            Text(t.eh.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _reload, child: Text(t.eh.retry)),
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
                label: Text(t.eh.category),
                selected: _selectedCategory == null,
                onSelected: (_) => _selectCategory(null),
              ),
              for (final category in _categories) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(category.displayName),
                  selected: _selectedCategory == category,
                  onSelected: (_) => _selectCategory(category),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _buildList(context)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [EhListEmptyView()],
            )
          : Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: _items.length,
                  itemBuilder: (context, index) => EhGalleryListItem(
                    info: _items[index],
                    onTap: () => context.pushRoute(
                      EhDetailRoute(
                        gid: _items[index].gid,
                        token: _items[index].token,
                      ),
                    ),
                  ),
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
