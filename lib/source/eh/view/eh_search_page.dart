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
class EhSearchPage extends StatefulWidget {
  const EhSearchPage({super.key});

  @override
  State<EhSearchPage> createState() => _EhSearchPageState();
}

class _EhSearchPageState extends State<EhSearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static final List<EhGalleryCategory> _categories = EhGalleryCategory.values
      .where((c) => c.bit & ehAllCategoryBits != 0)
      .toList();

  final Set<EhGalleryCategory> _selectedCategories = {};
  bool _searched = false;
  bool _searching = false;
  Object? _error;
  List<EhGalleryInfo> _items = [];
  int _page = 0;
  int _maxPage = 1;
  bool _loadingMore = false;
  int _requestSeq = 0;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _keywordController.dispose();
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

  int? get _categoryMask {
    if (_selectedCategories.isEmpty) return null;
    var mask = 0;
    for (final category in _selectedCategories) {
      mask |= category.bit;
    }
    return mask;
  }

  Future<void> _search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final seq = _nextSeq();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _keyword = trimmed;
      _searched = true;
      _searching = true;
      _error = null;
      _items = [];
      _page = 0;
      _maxPage = 1;
    });
    try {
      final resp = await fetchEhGalleryList(
        keyword: trimmed,
        categoryMask: _categoryMask,
        page: 0,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = resp.items;
        _maxPage = resp.maxPage;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e;
        _searching = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _searching || _error != null || !_searched) return;
    if (_page >= _maxPage - 1) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final resp = await fetchEhGalleryList(
        keyword: _keyword,
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

  Future<void> _refresh() async {
    if (!_searched) return;
    final seq = _nextSeq();
    try {
      final resp = await fetchEhGalleryList(
        keyword: _keyword,
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

  void _toggleCategory(EhGalleryCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
    if (_searched) _search(_keyword);
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.search,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: MiuixTextField(
                  controller: _keywordController,
                  singleLine: true,
                  label: t.eh.search,
                  useLabelAsPlaceholder: true,
                  leadingIcon: const Icon(Icons.search, size: 20),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  children: [
                    for (final category in _categories) ...[
                      FilterChip(
                        label: Text(category.displayName),
                        selected: _selectedCategories.contains(category),
                        onSelected: (_) => _toggleCategory(category),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_searched) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [EhListEmptyView()],
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.eh.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(
              onPressed: () => _search(_keyword),
              child: Text(t.eh.retry),
            ),
          ],
        ),
      );
    }
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
