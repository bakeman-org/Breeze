import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';

import 'package:zephyr/page/search/view/search_scheme_renderer.dart';

@RoutePage()
class SearchPage extends StatelessWidget {
  final SearchStates searchState;
  final bool aggregateMode;

  const SearchPage({
    super.key,
    required this.searchState,
    this.aggregateMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => SearchCubit(searchState))],
      child: _SearchPageContent(
        searchState: searchState,
        aggregateMode: aggregateMode,
      ),
    );
  }
}

class _SearchPageContent extends StatefulWidget {
  final SearchStates searchState;
  final bool aggregateMode;

  const _SearchPageContent({
    required this.searchState,
    required this.aggregateMode,
  });

  @override
  State<_SearchPageContent> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPageContent> {
  late final SearchSchemeRenderer _renderer;

  @override
  void initState() {
    super.initState();
    _renderer = SearchSchemeRenderer(aggregateMode: widget.aggregateMode);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Miuix 迁移：Scaffold + SafeArea → MiuixScaffold。
    // content 的 padding 已含系统栏内边距，替代原 SafeArea；
    // scheme 渲染器（搜索栏 / 分隔线 / 历史）结构不变。
    return MiuixScaffold(
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: _renderer.build()),
      ),
    );
  }
}
