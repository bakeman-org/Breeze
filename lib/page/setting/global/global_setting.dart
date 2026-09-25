import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/widgets/settings/reader_settings_sheet.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_super_resolution.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';

/// 全局设置主页。
///
/// 页面结构：
///   MiuixScaffold
///    ├── MiuixTopAppBar（标题 + 返回按钮）
///    └── ListView
///         ├── MiuixSmallTitle「常用」
///         ├── GroupCard（分组卡片，项之间自动加 IndentDivider）
///         │    ├── 外观与显示
///         │    ├── 阅读设置
///         │    ├── 内容与网络
///         │    ├── 应用行为
///         │    ├── 书架设置
///         │    ├── 存储
///         │    └── 图片超分（条件显示）
///         ├── MiuixSmallTitle「调试」
///         └── GroupCard
///              └── 调试
///
/// 所有 preference 项都不带 summary，只显示标题 —— 视觉上更简洁。
@RoutePage()
class GlobalSettingPage extends StatefulWidget {
  const GlobalSettingPage({super.key});

  @override
  State<GlobalSettingPage> createState() => _GlobalSettingPageState();
}

class _GlobalSettingPageState extends State<GlobalSettingPage> {
  /// RealSR 是否支持：异步查一次，避免每次 build 重复请求硬件信息。
  late final Future<bool> _realSrAvailable;

  /// 所有 preference 项统一的内边距。
  static const _m = MiuixSettingHelpers.itemMargin;

  @override
  void initState() {
    super.initState();
    _realSrAvailable = RealSrSuperResolution.isDeviceSupported;
  }

  /// 打开子设置页，回来后触发一次 rebuild。
  ///
  /// 部分子页会改全局设置，返回后本页可能需要刷新（虽然目前不再显示
  /// 状态 summary，但保留这个 rebuild 钩子以防后续需要）。
  Future<void> _openSubPage(PageRouteInfo route) async {
    await context.pushRoute(route);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 监听 GlobalSettingCubit：内部状态变化时本页 build 会重跑。
    // 目前 build 不读 state，但保留 watch 保证未来扩展时无需改结构。
    context.watch<GlobalSettingCubit>();

    return MiuixScaffold(
      // ───────── 顶栏 ─────────
      topBar: MiuixTopAppBar(
        title: t.settings.globalTitle,
        navigationIcon: MiuixSettingHelpers.backButton(context),
      ),

      // ───────── 内容区 ─────────
      // MiuixScaffold 的 content 是一个 builder，参数 padding 已包含
      // 状态栏、导航栏安全区，直接拼到 ListView 上即可。
      content: (padding) => Material(
        type: MaterialType.transparency,
        child: ListView(
          // 底部多留 32px，最后一项不至于贴屏幕底边。
          padding: padding.copyWith(bottom: 32),
          children: [
            // ═════════ 分组：常用 ═════════
            const Padding(
              // 上下留白使标题与卡片、标题与标题之间不挤在一起。
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: MiuixSmallTitle('常用'),
            ),
            GroupCard(
              children: [
                // ── 外观与显示 ──
                MiuixArrowPreference(
                  title: t.settings.appearance,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.palette_outlined,
                    name: 'palette',
                  ),
                  insideMargin: _m,
                  onClick: () => _openSubPage(const AppearanceSettingRoute()),
                ),

                // ── 阅读设置 ──
                // 不走 pushRoute，直接弹出底部面板。
                MiuixArrowPreference(
                  title: t.reader.settings,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.menu_book_outlined,
                    name: 'menu_book',
                  ),
                  insideMargin: _m,
                  onClick: () => showReaderSettingsSheet(context),
                ),

                // ── 内容与网络 ──
                MiuixArrowPreference(
                  title: t.settings.contentAndNetwork,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.tune_outlined,
                    name: 'tune',
                  ),
                  insideMargin: _m,
                  onClick: () =>
                      _openSubPage(const ContentNetworkSettingRoute()),
                ),

                // ── 应用行为 ──
                MiuixArrowPreference(
                  title: t.settings.appBehavior,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.settings_outlined,
                    name: 'settings',
                  ),
                  insideMargin: _m,
                  onClick: () => _openSubPage(const AppBehaviorSettingRoute()),
                ),

                // ── 书架设置 ──
                MiuixArrowPreference(
                  title: t.settings.bookshelf,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.collections_bookmark_outlined,
                    name: 'collections_bookmark',
                  ),
                  insideMargin: _m,
                  onClick: () => _openSubPage(const BookshelfSettingRoute()),
                ),

                // ── 存储 ──
                MiuixArrowPreference(
                  title: t.settings.storage,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.storage_outlined,
                    name: 'storage',
                  ),
                  insideMargin: _m,
                  onClick: () => _openSubPage(const StorageSettingRoute()),
                ),

                // ── 图片超分（条件显示） ──
                // 只有设备支持 RealSR 时才出现；FutureBuilder 完成前
                // 返回 SizedBox.shrink()，不占位。
                FutureBuilder<bool>(
                  future: _realSrAvailable,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }
                    return MiuixArrowPreference(
                      title: t.settings.realSr,
                      startAction: MiuixSettingHelpers.icon(
                        fallback: Icons.auto_fix_high_outlined,
                        name: 'auto_fix_high',
                      ),
                      insideMargin: _m,
                      onClick: () => _openSubPage(const RealSrSettingRoute()),
                    );
                  },
                ),
              ],
            ),

            // ═════════ 分组：调试 ═════════
            // 单独一张卡片，避免和用户级设置混在一起。
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: MiuixSmallTitle('调试'),
            ),
            GroupCard(
              children: [
                // ── 日志转发 ──
                MiuixArrowPreference(
                  title: t.settings.debug,
                  startAction: MiuixSettingHelpers.icon(
                    fallback: Icons.bug_report_outlined,
                    name: 'bug_report',
                  ),
                  insideMargin: _m,
                  onClick: () => _openSubPage(const DebugSettingRoute()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
