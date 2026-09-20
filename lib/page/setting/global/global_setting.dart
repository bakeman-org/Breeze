import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/widgets/settings/reader_settings_sheet.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_super_resolution.dart';

@RoutePage()
class GlobalSettingPage extends StatefulWidget {
  const GlobalSettingPage({super.key});

  @override
  State<GlobalSettingPage> createState() => _GlobalSettingPageState();
}

class _GlobalSettingPageState extends State<GlobalSettingPage> {
  late final Future<bool> _realSrAvailable;

  /// 分组卡片内 preference 项的紧凑内边距。
  /// 与 PreferencesShowcase 保持一致，避免每项过于松散。
  static const _itemMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  @override
  void initState() {
    super.initState();
    _realSrAvailable = RealSrSuperResolution.isDeviceSupported;
  }

  Future<void> _openSubPage(PageRouteInfo route) async {
    await context.pushRoute(route);
    if (mounted) setState(() {});
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => t.common.followSystem,
      ThemeMode.light => t.common.lightMode,
      ThemeMode.dark => t.common.darkMode,
    };
  }

  String _languageLabel(GlobalSettingState state) {
    if (state.localeFollowsSystem) return t.settings.followSystemLanguage;
    for (final appLocale in AppLocale.values) {
      if (I18nHelper.toFlutterLocale(appLocale) == state.locale) {
        return I18nHelper.displayName(appLocale);
      }
    }
    return state.locale.toLanguageTag();
  }

  /// 构造列表项起始图标：优先使用 Miuix 扩展图标，找不到则回退到 Material Icon。
  ///
  /// `MiuixIcons.extended` 并非 Material Symbols 全量镜像，某些名字可能不存在；
  /// 直接 `!` 会抛 “Null check operator used on a null value”，这里做安全回退。
  Widget _settingIcon(IconData fallback, String miuixName) {
    final vector = MiuixIcons.extended.byName(miuixName);
    if (vector != null) {
      return MiuixIcon(vector: vector, size: 22);
    }
    return Icon(fallback, size: 22);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GlobalSettingCubit>().state;

    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: t.settings.globalTitle,
        navigationIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: MiuixIconButton(
              onPressed: () => context.router.maybePop(),
              // MiuixIconButton 接受任意 Widget，这里直接用 Material 的 Icon
              // （与 PreferencesShowcase 中 _SubPage 的写法一致）。
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ),
      content: (padding) => Material(
        // MiuixScaffold 的 content 区域不提供 Material 祖先；
        // 这里包一层透明 Material，方便内部使用 InkWell 之类的组件。
        type: MaterialType.transparency,
        child: ListView(
          padding: padding.copyWith(bottom: 32),
          children: [
            // ───────── 主设置分组 ─────────
            MiuixCard(
              child: Column(
                children: [
                  MiuixArrowPreference(
                    title: t.settings.appearance,
                    summary:
                        '${_languageLabel(state)} · ${_themeLabel(state.themeMode)}',
                    startAction: _settingIcon(
                      Icons.palette_outlined,
                      'palette',
                    ),
                    insideMargin: _itemMargin,
                    onClick: () => _openSubPage(const AppearanceSettingRoute()),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: t.reader.settings,
                    summary:
                        '${t.reader.readingMode} · ${t.reader.doubleTapAction}',
                    startAction: _settingIcon(
                      Icons.menu_book_outlined,
                      'menu_book',
                    ),
                    insideMargin: _itemMargin,
                    onClick: () => showReaderSettingsSheet(context),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: t.settings.contentAndNetwork,
                    summary:
                        '${t.settings.maskedKeywords} · ${t.settings.proxy}',
                    startAction: _settingIcon(Icons.tune_outlined, 'tune'),
                    insideMargin: _itemMargin,
                    onClick: () =>
                        _openSubPage(const ContentNetworkSettingRoute()),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: t.settings.appBehavior,
                    summary: '${t.settings.splashPage} · ${t.settings.appLock}',
                    startAction: _settingIcon(
                      Icons.settings_outlined,
                      'settings',
                    ),
                    insideMargin: _itemMargin,
                    onClick: () =>
                        _openSubPage(const AppBehaviorSettingRoute()),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: t.settings.bookshelf,
                    summary: t.settings.bookshelfSubtitle,
                    startAction: _settingIcon(
                      Icons.collections_bookmark_outlined,
                      'collections_bookmark',
                    ),
                    insideMargin: _itemMargin,
                    onClick: () => _openSubPage(const BookshelfSettingRoute()),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: t.settings.storage,
                    summary: '${t.settings.cache} · ${t.settings.dataBackup}',
                    startAction: _settingIcon(
                      Icons.storage_outlined,
                      'storage',
                    ),
                    insideMargin: _itemMargin,
                    onClick: () => _openSubPage(const StorageSettingRoute()),
                  ),

                  // RealSR：仅当设备支持时显示（保留原 FutureBuilder 逻辑）。
                  FutureBuilder<bool>(
                    future: _realSrAvailable,
                    builder: (context, snapshot) {
                      if (snapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MiuixHorizontalDivider(),
                          MiuixArrowPreference(
                            title: t.settings.realSr,
                            summary: t.settings.realSrSubtitle,
                            startAction: _settingIcon(
                              Icons.auto_fix_high_outlined,
                              'auto_fix_high',
                            ),
                            insideMargin: _itemMargin,
                            onClick: () =>
                                _openSubPage(const RealSrSettingRoute()),
                          ),
                        ],
                      );
                    },
                  ),

                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: t.settings.debug,
                    summary: t.settings.logAddress,
                    startAction: _settingIcon(
                      Icons.bug_report_outlined,
                      'bug_report',
                    ),
                    insideMargin: _itemMargin,
                    onClick: () => _openSubPage(const DebugSettingRoute()),
                  ),
                ],
              ),
            ),

            // TODO: below is repeated
            // const SizedBox(height: 20),

            // // ───────── 关于与更多 ─────────
            // MiuixSmallTitle(t.settings.aboutAndMore),
            // MiuixCard(
            //   child: Column(
            //     children: [
            //       MiuixArrowPreference(
            //         title: t.settings.changelog,
            //         summary: t.settings.changelogSubtitle,
            //         startAction: _settingIcon(
            //           Icons.history_outlined,
            //           'history',
            //         ),
            //         insideMargin: _itemMargin,
            //         onClick: () => context.pushRoute(ChangelogRoute()),
            //       ),
            //       const MiuixHorizontalDivider(),
            //       MiuixArrowPreference(
            //         title: t.settings.aboutApp,
            //         summary: t.settings.aboutAppSubtitle,
            //         startAction: _settingIcon(Icons.help_outline, 'help'),
            //         insideMargin: _itemMargin,
            //         onClick: () => context.pushRoute(AboutRoute()),
            //       ),
            //     ],
            // ),
            // ),
          ],
        ),
      ),
    );
  }
}
