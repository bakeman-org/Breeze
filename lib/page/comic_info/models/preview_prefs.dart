/// 预览模式：前 N 张 / 后 N 张 / 起止区间。
enum PreviewMode { top, tail, range }

/// 预览设置的持久化 key。
class PreviewPrefsKeys {
  PreviewPrefsKeys._();

  static const show = 'comic_info_show_preview';
  static const mode = 'comic_info_preview_mode';
  static const count = 'comic_info_preview_count';
  static const start = 'comic_info_preview_start';
  static const end = 'comic_info_preview_end';
}
