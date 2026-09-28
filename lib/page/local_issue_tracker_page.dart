import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/page/changelog/widgets/local_issue_tracker_tab.dart';

@RoutePage()
class LocalIssueTrackerPage extends StatelessWidget {
  const LocalIssueTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: '本地追踪',
        navigationIcon: MiuixIconButton(
          onPressed: () => context.maybePop(),
          child: const Icon(Icons.arrow_back),
        ),
      ),
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: padding,
          child: const LocalIssueTrackerTab(),
        ),
      ),
    );
  }
}
