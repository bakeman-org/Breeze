import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_comic_card.dart';

@RoutePage()
class BikaRankPage extends StatefulWidget {
  const BikaRankPage({super.key});

  @override
  State<BikaRankPage> createState() => _BikaRankPageState();
}

class _BikaRankPageState extends State<BikaRankPage> {
  ComicRankType _type = ComicRankType.H24;
  bool _loading = true;
  Object? _error;
  List<Doc> _comics = [];
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _nextSeq() {
    _requestSeq += 1;
    return _requestSeq;
  }

  Future<void> _load() async {
    final seq = _nextSeq();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await fetchBikaComicRank(ComicRankPayload(type: _type));
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = resp.comics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final seq = _nextSeq();
    try {
      final resp = await fetchBikaComicRank(ComicRankPayload(type: _type));
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _comics = resp.comics;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _error = e);
    }
  }

  void _selectType(ComicRankType type) {
    if (type == _type) return;
    setState(() => _type = type);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.bika.rank,
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: MiuixTabRow(
                  tabs: [t.bika.rankH24, t.bika.rankWeek, t.bika.rankMonth],
                  selectedTabIndex: ComicRankType.values.indexOf(_type),
                  onTabSelected: (index) =>
                      _selectType(ComicRankType.values[index]),
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
    if (_loading) {
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
      child: BikaComicGrid(
        comics: _comics,
        physics: const AlwaysScrollableScrollPhysics(),
      ),
    );
  }
}
