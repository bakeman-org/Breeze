import 'package:auto_route/auto_route.dart';
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.changelog.title),
          centerTitle: true,
          scrolledUnderElevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: '更新日志'),
              Tab(text: '公告'),
              Tab(text: '本地追踪'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ReleasesTab(), AnnouncementsTab(), LocalIssueTrackerTab()],
        ),
      ),
    );
  }
}
