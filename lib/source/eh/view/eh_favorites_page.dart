import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/api/eh_url.dart';
import 'package:zephyr/source/eh/api/gallery_list_parser.dart';
import 'package:zephyr/source/eh/auth/eh_setting.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';
import 'package:zephyr/source/eh/view/widgets/eh_gallery_list_item.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class EhFavoritesPage extends StatefulWidget {
  const EhFavoritesPage({super.key});

  @override
  State<EhFavoritesPage> createState() => _EhFavoritesPageState();
}

class _EhFavoritesPageState extends State<EhFavoritesPage> {
  final ScrollController _scrollController = ScrollController();

  bool _loggedIn = true;
  bool _initialLoading = true;
  Object? _error;
  List<EhGalleryInfo> _items = [];
  int _page = 0;
  int _maxPage = 1;
  bool _loadingMore = false;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _loggedIn = ehSettingState.hasCredentials;
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

  Future<EhGalleryListResult> _fetchPage(int page) async {
    var url = ehFavoritesUrl();
    if (page > 0) url = '$url?page=$page';
    final html = await fetchEhHtml(url);
    return parseGalleryList(html);
  }

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
      final resp = await _fetchPage(0);
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
      final resp = await _fetchPage(0);
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
      final resp = await _fetchPage(next);
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

  Future<void> _goLogin() async {
    await context.pushRoute(const EhLoginRoute());
    if (!mounted) return;
    final loggedIn = ehSettingState.hasCredentials;
    setState(() => _loggedIn = loggedIn);
    if (loggedIn && _items.isEmpty && _error == null) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.eh.favorites,
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
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
          Text(t.eh.loginRequired, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          MiuixButton(onPressed: _goLogin, child: Text(t.eh.login)),
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
