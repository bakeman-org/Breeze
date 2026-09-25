import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/changelog/widgets/announcements_tab.dart';
import 'package:zephyr/page/changelog/widgets/local_issue_tracker_tab.dart';
import 'package:zephyr/page/changelog/widgets/releases_tab.dart';

/// Changelog 页：三 Tab。
///
/// - Tab 1「更新日志」：GitHub Releases
/// - Tab 2「公告」：ntfy 消息流
/// - Tab 3「本地追踪」：内嵌的本地 issue tracker
@RoutePage()
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      // Miuix 迁移：Scaffold + AppBar(bottom: TabBar) → MiuixScaffold + MiuixTopAppBar(bottomContent)。
      child: MiuixScaffold(
        topBar: MiuixTopAppBar(
          title: t.changelog.title,
          navigationIcon: MiuixIconButton(
            onPressed: () => context.maybePop(),
            child: const Icon(Icons.arrow_back),
          ),
          bottomContent: Material(
            type: MaterialType.transparency,
            child: const TabBar(
              tabs: [
                Tab(text: '更新日志'),
                Tab(text: '公告'),
                Tab(text: '本地追踪'),
              ],
            ),
          ),
        ),
        content: (padding) => Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding,
            child: const TabBarView(
              children: [
                ReleasesTab(),
                AnnouncementsTab(),
                LocalIssueTrackerTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
