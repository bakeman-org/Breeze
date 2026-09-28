import 'package:auto_route/auto_route.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/changelog/widgets/announcements_tab.dart';
import 'package:zephyr/page/changelog/widgets/releases_tab.dart';

/// Changelog 页：二 Tab。
///
/// - Tab 1「更新日志」：GitHub Releases
/// - Tab 2「公告」：ntfy 消息流
@RoutePage()
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
