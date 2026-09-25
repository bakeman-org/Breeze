import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/i18n/system_locale_service.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/widgets.dart';
import 'package:zephyr/page/setting/widgets/miuix_setting_helpers.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class AppearanceSettingPage extends StatelessWidget {
  const AppearanceSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;

    return SettingPageShell(
      title: t.settings.appearance,
      child: ListView(
        children: [
          settingSectionTitle(context, t.settings.appearance),
          GroupCard(
            children: [
              MiuixArrowPreference(
                title: t.settings.language,
                summary: _languageLabel(state),
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.language_outlined,
                  name: 'language',
                ),
                insideMargin: MiuixSettingHelpers.itemMargin,
                onClick: () => _pickLanguage(context, state, cubit),
              ),
              MiuixArrowPreference(
                title: t.settings.theme,
                summary: _themeModeLabel(state.themeMode),
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.dark_mode_outlined,
                  name: 'dark_mode',
                ),
                insideMargin: MiuixSettingHelpers.itemMargin,
                onClick: () => _pickThemeMode(context, state, cubit),
              ),
              MiuixSwitchPreference(
                title: t.settings.dynamicColor,
                summary: t.settings.dynamicColorSubtitle,
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.color_lens_outlined,
                  name: 'color_lens',
                ),
                value: state.dynamicColor,
                onChanged: (bool value) {
                  cubit.updateState(
                    (current) => current.copyWith(dynamicColor: value),
                  );
                },
                insideMargin: MiuixSettingHelpers.itemMargin,
              ),

              // 动态取色开启时隐藏种子色入口（与原逻辑一致）。
              if (!state.dynamicColor) changeThemeColor(context),

              MiuixSwitchPreference(
                title: t.settings.amoled,
                summary: t.settings.amoledSubtitle,
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.contrast_outlined,
                  name: 'contrast',
                ),
                value: state.isAMOLED,
                onChanged: (bool value) {
                  cubit.updateState(
                    (current) => current.copyWith(isAMOLED: value),
                  );
                },
                insideMargin: MiuixSettingHelpers.itemMargin,
              ),
              MiuixSwitchPreference(
                title: t.settings.notchAdaptation,
                summary: t.settings.notchAdaptationSubtitle,
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.smartphone_outlined,
                  name: 'smartphone',
                ),
                value: state.readSetting.comicReadTopContainer,
                onChanged: (bool value) {
                  cubit.updateReadSetting(
                    (current) => current.copyWith(comicReadTopContainer: value),
                  );
                },
                insideMargin: MiuixSettingHelpers.itemMargin,
              ),
              MiuixArrowPreference(
                title: t.settings.fontSettings,
                summary: t.settings.fontSettingsSubtitle,
                startAction: MiuixSettingHelpers.icon(
                  fallback: Icons.font_download_outlined,
                  name: 'font',
                ),
                insideMargin: MiuixSettingHelpers.itemMargin,
                onClick: () => context.pushRoute(const FontSettingRoute()),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────── 标签文本 ───────────

  String _languageLabel(GlobalSettingState state) {
    if (state.localeFollowsSystem) return t.settings.followSystemLanguage;
    for (final appLocale in AppLocale.values) {
      if (I18nHelper.toFlutterLocale(appLocale) == state.locale) {
        return I18nHelper.displayName(appLocale);
      }
    }
    return state.locale.toLanguageTag();
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => t.common.followSystem,
      ThemeMode.light => t.common.lightMode,
      ThemeMode.dark => t.common.darkMode,
    };
  }

  // ─────────── 弹出选择：语言 ───────────

  Future<void> _pickLanguage(
    BuildContext context,
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) async {
    // 语言列表：null 表示跟随系统。
    final labels = <Locale?, String>{
      null: t.settings.followSystemLanguage,
      for (final appLocale in AppLocale.values)
        I18nHelper.toFlutterLocale(appLocale): I18nHelper.displayName(
          appLocale,
        ),
    };
    final currentValue = state.localeFollowsSystem ? null : state.locale;

    // `picked == null` → 用户取消；`picked!.value == null` → 选中「跟随系统」。
    final picked = await _showOptionSheet<Locale?>(
      context: context,
      title: t.settings.language,
      labels: labels,
      currentValue: currentValue,
    );
    if (picked == null) return; // 取消
    final selected = picked.value;
    if (selected == currentValue) return;

    if (selected == null) {
      final systemInfo = await SystemLocaleService.getInfo();
      await cubit.setSystemLocale(systemInfo.locale);
    } else {
      await cubit.setLocale(selected, followsSystem: false);
    }
    if (context.mounted) {
      showInfoToast(t.settings.languageChangedRestartHint);
    }
  }

  // ─────────── 弹出选择：主题模式 ───────────

  Future<void> _pickThemeMode(
    BuildContext context,
    GlobalSettingState state,
    GlobalSettingCubit cubit,
  ) async {
    final labels = <ThemeMode, String>{
      ThemeMode.system: t.common.followSystem,
      ThemeMode.light: t.common.lightMode,
      ThemeMode.dark: t.common.darkMode,
    };

    final picked = await _showOptionSheet<ThemeMode>(
      context: context,
      title: t.settings.theme,
      labels: labels,
      currentValue: state.themeMode,
    );
    if (picked == null) return; // 取消
    final selected = picked.value; // 收窄为 ThemeMode（非空）
    if (selected == state.themeMode) return;

    cubit.updateState((current) => current.copyWith(themeMode: selected));
  }

  /// 通用底部选择面板。
  ///
  /// 返回值语义：
  ///   - `null`          → 用户取消（直接 dismiss 或没点任何项）
  ///   - `_Picked(value)` → 用户选中了 `value`；`value` 本身可以是 null
  ///                        （例如语言里的「跟随系统」）。
  ///
  /// 用 `_Picked` 包装而不用 sentinel 对象 + `as T?` 强转，是因为后者在
  /// `T` 为非空类型（如 `ThemeMode`）时，一旦用户取消就会在运行时把
  /// `Object` 强转成 `ThemeMode?` 而抛异常。
  Future<_Picked<T>?> _showOptionSheet<T>({
    required BuildContext context,
    required String title,
    required Map<T, String> labels,
    required T currentValue,
  }) {
    return showModalBottomSheet<_Picked<T>>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: MiuixSmallTitle(title),
              ),
              for (final entry in labels.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: entry.key == currentValue
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_Picked(entry.key)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// 把用户的选中值包一层，用来把「取消」(`null`) 和「选中了 null」
/// (`_Picked(null)`) 区分开。
///
/// 之所以不用 sentinel + `as T?`：当 `T` 是非空类型时，把 sentinel 强转
/// 成 `T?` 会在运行时抛异常。用包装类后，泛型只作用在 `.value` 上，类型
/// 安全由编译器保证。
class _Picked<T> {
  final T value;
  const _Picked(this.value);
}
