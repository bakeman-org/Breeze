import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_comic_card.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BikaSearchPage extends StatefulWidget {
  const BikaSearchPage({super.key});

  @override
  State<BikaSearchPage> createState() => _BikaSearchPageState();
}

class _BikaSearchPageState extends State<BikaSearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> _hotWords = [];
  bool _searched = false;
  bool _searching = false;
  Object? _error;
  ComicSortType _sort = ComicSortType.dd;
  List<SearchComic> _comics = [];
  int _page = 1;
  int _pages = 1;
  bool _loadingMore = false;
  int _requestSeq = 0;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHotWords();
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

  Future<void> _loadHotWords() async {
    try {
      final resp = await fetchBikaHotSearchWords();
      if (!mounted) return;
      setState(() => _hotWords = resp.keywords);
    } catch (_) {}
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
      _comics = [];
      _page = 1;
      _pages = 1;
    });
    try {
      final resp = await searchBikaComics(
        SearchPayload(keyword: trimmed, page: 1, sort: _sort),
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = resp.comics.docs;
        _pages = resp.comics.pages;
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
    if (_page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final resp = await searchBikaComics(
        SearchPayload(keyword: _keyword, page: next, sort: _sort),
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

  Future<void> _selectSort(ComicSortType sort) async {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    if (_searched) await _search(_keyword);
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.search,
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
                .map((type) => PopupMenuItem(value: type, child: Text(type.title)))
                .toList(),
            child: const Icon(Icons.sort),
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: MiuixTextField(
                  controller: _keywordController,
                  singleLine: true,
                  label: t.bika.searchHint,
                  useLabelAsPlaceholder: true,
                  leadingIcon: const Icon(Icons.search, size: 20),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
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
    if (!_searched) return _buildHotWords();
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.bika.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(
              onPressed: () => _search(_keyword),
              child: Text(t.bika.retry),
            ),
          ],
        ),
      );
    }
    if (_comics.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [BikaListEmptyView()],
      );
    }
    return RefreshIndicator(
      onRefresh: () => _search(_keyword),
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

  Widget _buildHotWords() {
    if (_hotWords.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [BikaListEmptyView(message: t.bika.hotSearchWords)],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          t.bika.hotSearchWords,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final word in _hotWords)
              ActionChip(
                label: Text(word),
                onPressed: () {
                  _keywordController.text = word;
                  _search(word);
                },
              ),
          ],
        ),
      ],
    );
  }
}
