import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用主题的轻量缓存。
///
/// 目的：`main()` 里 ObjectBox 尚未打开时，需要**同步**读一份
/// seedColor / themeMode 用于闪屏主题，避免「闪屏固定色 → 主界面用户色」
/// 的视觉跳变。
///
/// 写入：`GlobalSettingCubit._updateDataBase` 里每次 seedColor / themeMode
///       变化时同步。
/// 读取：`main()` 里 `await AppThemeCache.init()` 之后，通过同步 getter 读。
class AppThemeCache {
  AppThemeCache._();

  static const _kSeedColorKey = 'app_theme_seed_color_v1';
  static const _kThemeModeKey = 'app_theme_mode_v1';

  static SharedPreferences? _prefs;

  /// 提前初始化。`main()` 里 await 一次。幂等。
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 同步读 seedColor。未初始化或没存过时返回 null。
  static Color? get seedColor {
    final raw = _prefs?.getInt(_kSeedColorKey);
    return raw == null ? null : Color(raw);
  }

  /// 同步读 themeMode。未初始化或没存过时返回 null。
  static ThemeMode? get themeMode {
    final raw = _prefs?.getString(_kThemeModeKey);
    if (raw == null) return null;
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  /// 写入。fire-and-forget，不阻塞 UI。
  static void write({required Color seedColor, required ThemeMode themeMode}) {
    final p = _prefs;
    if (p == null) return;
    // ignore: deprecated_member_use
    p.setInt(_kSeedColorKey, seedColor.value);
    p.setString(_kThemeModeKey, themeMode.name);
  }
}
