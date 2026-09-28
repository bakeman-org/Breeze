import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';

import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';

/// 「更多」Tab 的设置入口列表（Miuix 迁移版）。
///
/// 功能与旧版完全一致：下载任务 / 同步 / 追更 / 全局设置 / 更新日志 / 关于。
/// 视觉元素从 ListTile + 自绘分组标题迁移为 Miuix 的
/// `MiuixSmallTitle` + `GroupCard` + `MiuixArrowPreference`。
class SettingsWidget extends StatelessWidget {
  const SettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiuixSmallTitle(t.more.common),
        GroupCard(
          children: [
            MiuixArrowPreference(
              title: t.more.downloadTasks,
              startAction: MiuixSettingHelpers.icon(
                fallback: Icons.download_outlined,
                name: 'download',
              ),
              insideMargin: MiuixSettingHelpers.itemMargin,
              onClick: () => context.pushRoute(DownloadTaskRoute()),
            ),
            MiuixArrowPreference(
              title: t.more.sync,
              startAction: MiuixSettingHelpers.icon(
                fallback: Icons.sync_outlined,
                name: 'sync',
              ),
              insideMargin: MiuixSettingHelpers.itemMargin,
              onClick: () => context.pushRoute(SyncSettingRoute()),
            ),
            BlocSelector<ComicFollowCubit, ComicFollowState, int>(
              selector: (state) => state.updateCount,
              builder: (context, updateCount) {
                return MiuixArrowPreference(
                  title: t.more.comicFollow,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.notifications_active_outlined,
                    name: 'notifications',
                  ),
                  endActions: [
                    if (updateCount > 0) _UpdateBadge(count: updateCount),
                  ],
                  insideMargin: MiuixSettingHelpers.itemMargin,
                  onClick: () => context.pushRoute(ComicFollowRoute()),
                );
              },
            ),
            MiuixArrowPreference(
              title: t.settings.globalTitle,
              startAction: MiuixSettingHelpers.icon(
                fallback: Icons.settings_outlined,
                name: 'settings',
              ),
              insideMargin: MiuixSettingHelpers.itemMargin,
              onClick: () => context.pushRoute(GlobalSettingRoute()),
            ),
          ],
        ),
        MiuixSmallTitle(t.settings.aboutAndMore),
        GroupCard(
          children: [
            MiuixArrowPreference(
              title: t.more.changelog,
              startAction: MiuixSettingHelpers.icon(
                fallback: Icons.history,
                name: 'history',
              ),
              insideMargin: MiuixSettingHelpers.itemMargin,
              onClick: () => context.pushRoute(ChangelogRoute()),
            ),
            MiuixArrowPreference(
              title: '本地追踪',
              summary: '记录临时想法和 Bug，可绑定 GitHub 远程',
              startAction: MiuixSettingHelpers.icon(
                fallback: Icons.assignment_outlined,
                name: 'assignment',
              ),
              insideMargin: MiuixSettingHelpers.itemMargin,
              onClick: () =>
                  context.pushRoute(const LocalIssueTrackerRoute()),
            ),
            MiuixArrowPreference(
              title: t.about.title,
              startAction: MiuixSettingHelpers.icon(
                fallback: Icons.info_outline,
                name: 'info',
              ),
              insideMargin: MiuixSettingHelpers.itemMargin,
              onClick: () => context.pushRoute(AboutRoute()),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count >= 99 ? '99+' : 'NEW',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
