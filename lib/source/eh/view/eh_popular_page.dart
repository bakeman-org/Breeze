import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/api/gallery_list_parser.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';
import 'package:zephyr/source/eh/view/widgets/eh_gallery_list_item.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class EhPopularPage extends StatefulWidget {
  const EhPopularPage({super.key});

  @override
  State<EhPopularPage> createState() => _EhPopularPageState();
}

class _EhPopularPageState extends State<EhPopularPage> {
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = true;
  Object? _error;
  List<EhGalleryInfo> _items = [];
  int _nextOffset = 0;
  bool _hasMore = false;
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

  void _apply(EhGalleryListResult resp, bool replace) {
    final newOffset = resp.maxPage > 0 ? resp.maxPage - 1 : 0;
    final existing = replace
        ? <String>{}
        : _items.map((e) => e.gid).toSet();
    final fresh = resp.items
        .where((e) => !existing.contains(e.gid))
        .toList();
    setState(() {
      if (replace) _items = [];
      _items.addAll(fresh);
      _hasMore = newOffset > _nextOffset && resp.items.isNotEmpty;
      _nextOffset = newOffset;
    });
  }

  Future<void> _reload() async {
    final seq = _nextSeq();
    setState(() {
      _initialLoading = true;
      _error = null;
      _nextOffset = 0;
      _hasMore = false;
      _items = [];
    });
    try {
      final resp = await fetchEhGalleryList(popular: true, page: 0);
      if (!mounted || seq != _requestSeq) return;
      _apply(resp, true);
      setState(() => _initialLoading = false);
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
      final resp = await fetchEhGalleryList(popular: true, page: 0);
      if (!mounted || seq != _requestSeq) return;
      _nextOffset = 0;
      _apply(resp, true);
      setState(() => _error = null);
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      showErrorToast(e.toString());
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _initialLoading || _error != null || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final resp = await fetchEhGalleryList(
        popular: true,
        page: _nextOffset,
      );
      if (!mounted) return;
      _apply(resp, false);
      setState(() => _loadingMore = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showErrorToast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.popular,
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
            Text(t.eh.networkError, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            MiuixButton(onPressed: _reload, child: Text(t.eh.retry)),
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
