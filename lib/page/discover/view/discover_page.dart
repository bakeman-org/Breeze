// lib/page/discover/view/discover_page.dart
//
// 「发现」页：插件管理中心 + 快捷入口。
//
// 结构：
//   DiscoverPage            —— 路由入口，只负责注入 DiscoverCubit
//   └─ _DiscoverView        —— 页面骨架（AppBar / 列表 / FAB）
//       ├─ _buildPluginHome         —— 插件列表主体
//       ├─ _buildPluginCard         —— 单个插件卡片
//       ├─ _buildPluginStoreButton  —— 顶部「插件商店」入口
//       ├─ _buildSectionHeader      —— 分组小标题
//       ├─ _buildFloatingActions    —— 双 FAB（下载任务 + 搜索）
//       ├─ _openPluginSearch        —— 搜索某个插件的漫画
//       ├─ _openPluginSettings      —— 进入某插件设置
//       └─ _search                  —— 全局聚合搜索
//
// 双 FAB 设计：
//   - 上面小的：下载任务（跳 DownloadTaskRoute）
//   - 下面大的：搜索（主操作）
//   两个 FAB 必须指定不同的 heroTag，否则 Flutter 会抛
//   "There are multiple heroes that share the same tag"。

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/page/discover/service/discover_router.dart';
import 'package:zephyr/page/discover/view/plugin_order_dialog.dart';
import 'package:zephyr/page/discover/widgets/plugin_card.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/toast.dart';

// ─────────────────────────────────────────────────────────────────────
// 路由入口
// ─────────────────────────────────────────────────────────────────────

/// 「发现」页的路由入口。
///
/// 只做两件事：
///   1. 创建并注入 [DiscoverCubit]（进入页面就触发一次 load）；
///   2. 把 UI 交给 [_DiscoverView]。
///
/// 这里用 [BlocProvider] 而不是 [BlocProvider.value]，因为 cubit 的生命周期
/// 应该跟随页面一起创建/销毁。用户退出页面时 BlocProvider 会自动 close。
@RoutePage()
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiscoverCubit()..load(),
      child: const _DiscoverView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 页面主体
// ─────────────────────────────────────────────────────────────────────

/// 「发现」页的 UI 骨架。
///
/// 所有 FAB / AppBar / body 都在这层。业务细节拆到下面几个 _buildXxx 方法。
class _DiscoverView extends StatelessWidget {
  const _DiscoverView();

  @override
  Widget build(BuildContext context) {
    // 左手模式：FAB 位置 + 内容对齐都要跟着变。
    // 提前 watch 一次，避免同一个 build 里多次 subscribe。
    final leftHandMode = context
        .watch<GlobalSettingCubit>()
        .state
        .leftHandModeEnabled;

    return Scaffold(
      appBar: _buildAppBar(context),
      // 键盘弹出时不重设布局（这个页面没有输入框，保持稳定）。
      resizeToAvoidBottomInset: false,
      body: _buildBody(context),
      floatingActionButtonLocation: leftHandMode
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildFloatingActions(context, leftHandMode),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────────────────────────

  /// 顶部栏。
  ///
  /// 右侧两个按钮：
  ///   - 自定义插件顺序（弹出 dialog 调整插件卡片的前后顺序）
  ///   - 搜索（默认插件）
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(t.discover.title),
      actions: [
        IconButton(
          tooltip: t.discover.customOrder,
          icon: const Icon(Icons.reorder),
          onPressed: () => showPluginOrderDialog(context),
        ),
        IconButton(
          tooltip: t.discover.search,
          icon: const Icon(Icons.search),
          onPressed: () => _search(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────────────────────────

  /// Body 骨架：下拉刷新 + 居中 + 最大宽度约束。
  ///
  /// [ConstrainedBox] 到 800 是为了桌面/平板上不至于卡片被拉太长。
  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<DiscoverCubit>().reload(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildPluginHome(context),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 插件列表
  // ─────────────────────────────────────────────────────────────────

  /// 插件主页内容。
  ///
  /// 顺序：
  ///   1. 插件商店入口
  ///   2. 「插件管理」分组标题
  ///   3. 插件卡片列表（每个插件一张卡）
  Widget _buildPluginHome(BuildContext context) {
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      builder: (context, state) {
        final plugins = state.plugins.values.toList();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // 底部留 120 给 FAB 遮挡空间，保证最后一个卡片能完整滚到可点区域。
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 16),
            _buildPluginStoreButton(context),
            const SizedBox(height: 8),
            _buildSectionHeader(context, t.discover.pluginManagement),
            if (plugins.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    t.discover.noPlugins,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              for (final plugin in plugins) ...[
                _buildPluginCard(context, plugin, state),
              ],
          ],
        );
      },
    );
  }

  /// 单个插件卡片。
  ///
  /// [PluginCard] 是个独立的 widget（在 widgets/plugin_card.dart），把
  /// 卡片的 UI 和交互细节都封装在那边；这里只负责：
  ///   - 从 state 里挑出该插件当前的 info 加载状态
  ///   - 构造 4 个回调：搜索 / 设置 / 启用切换 / 重试 / 自定义 action
  Widget _buildPluginCard(
    BuildContext context,
    PluginRuntimeState plugin,
    DiscoverState state,
  ) {
    final cubit = context.read<DiscoverCubit>();
    // 插件元信息（name / icon / action）的加载状态。没拿到就按 loading 处理。
    final infoState =
        state.infoStates[plugin.uuid] ??
        const DiscoverPluginInfoState(loading: true);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: PluginCard(
        pluginUuid: plugin.uuid,
        pluginState: plugin,
        infoState: infoState,
        // 该插件是否正在被 toggle 启用状态。禁用按钮防连点。
        isToggling: state.togglingUuids.contains(plugin.uuid),
        onSearch: () => _openPluginSearch(context, plugin.uuid),
        onSettings: (title) => _openPluginSettings(context, plugin.uuid, title),
        onToggleEnabled: (enabled) => cubit.toggleEnabled(plugin.uuid, enabled),
        onRetry: () => cubit.retryLoadInfo(plugin.uuid),
        // 插件在 getInfo 里声明的快捷 action（例如「推荐」「排行榜」），
        // 点一下就跳到对应页面。attachSource 会把插件 uuid 注入 payload。
        onAction: (action) => DiscoverRouter.route(
          context,
          action: DiscoverRouter.attachSource(action, plugin.uuid),
          currentFrom: cubit.currentFrom,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 插件商店入口
  // ─────────────────────────────────────────────────────────────────

  /// 顶部「插件商店」入口行。
  ///
  /// 布局：[图标] [标题展开] [右侧提示] [箭头]
  Widget _buildPluginStoreButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.pushRoute(const PluginStoreRoute()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 22,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.discover.pluginStore,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              t.discover.browseInstall,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 分组标题
  // ─────────────────────────────────────────────────────────────────

  /// 分组标题（「插件管理」这种）。
  ///
  /// 用 primary 色 + 小号字，视觉上作为分隔但不抢眼。
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────────────────────────

  /// 双 FAB 组。
  ///
  /// 布局：竖排 Column，上小下大。
  ///   - 上面小 FAB：下载任务
  ///   - 下面大 FAB：搜索（主操作）
  ///
  /// **两个 FAB 必须有不同的 heroTag。** Flutter 的 Hero 动画通过 tag 匹配，
  /// 同页面出现两个默认 tag（`_defaultHeroTag`）会抛：
  ///   "There are multiple heroes that share the same tag"
  /// 所以这里显式给每个 FAB 一个稳定字符串 tag。
  ///
  /// [leftHandMode] 决定 Column 内 FAB 的横向对齐：左手模式下 FAB 组整体
  /// 靠左（因为 Scaffold 的 `floatingActionButtonLocation` 已经改到 start），
  /// 内部对齐也要跟着改，否则小 FAB 会脱离大 FAB。
  Widget _buildFloatingActions(BuildContext context, bool leftHandMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: leftHandMode
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'discover_download_task',
          tooltip: t.more.downloadTasks,
          onPressed: () => context.pushRoute(DownloadTaskRoute()),
          child: const Icon(Icons.download_outlined),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'discover_search',
          tooltip: t.discover.search,
          onPressed: () => _search(context),
          child: const Icon(Icons.search),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 交互回调
  // ─────────────────────────────────────────────────────────────────

  /// 进入某插件的搜索页。
  ///
  /// [from] 是插件 uuid。为空时弹错误 toast，避免跳到搜索页什么都搜不到。
  /// [aggregateMode] 传 false，因为这个入口只搜当前插件。
  void _openPluginSearch(BuildContext context, String from) {
    final source = from.trim();
    if (source.isEmpty) {
      showErrorToast(t.error.missingPluginSource(action: t.discover.search));
      return;
    }
    context.pushRoute(
      SearchRoute(
        searchState: SearchStates.initial().copyWith(from: source),
        aggregateMode: false,
      ),
    );
  }

  /// 进入某插件的设置页。
  ///
  /// 三个参数都用 uuid：`from` / `pluginUuid` / `pluginRuntimeName`。
  /// 目前插件系统和 runtime 都按 uuid 索引，所以三者一致；将来如果
  /// runtime name 和 uuid 解耦，只需要改这里。
  void _openPluginSettings(BuildContext context, String uuid, String title) {
    context.pushRoute(
      PluginSettingsRoute(
        from: uuid,
        pluginUuid: uuid,
        pluginRuntimeName: uuid,
        pluginDisplayName: title,
      ),
    );
  }

  /// 全局聚合搜索。
  ///
  /// 用 [DiscoverCubit.currentFrom]（用户上次选择的插件）作为 source。
  /// [aggregateMode] 传 true，让所有插件都参与搜索。
  void _search(BuildContext context) {
    final cubit = context.read<DiscoverCubit>();
    final source = cubit.currentFrom;
    if (source.isEmpty) {
      showErrorToast(t.discover.noPluginForSearch);
      return;
    }
    context.pushRoute(
      SearchRoute(
        searchState: SearchStates.initial().copyWith(from: source),
        aggregateMode: true,
      ),
    );
  }
}
