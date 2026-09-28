import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/type/enum.dart';

/// 桌面小部件数据源。
///
/// 把最近下载的漫画（标题/漫画 id/来源/本地封面路径）序列化成 JSON 后
/// 通过 home_widget 写入平台侧存储，再触发原生小部件刷新。
/// Android 端原生代码从 SharedPreferences `HomeWidgetPreferences` 读取，
/// iOS 端通过 App Group UserDefaults 读取。
class HomeWidgetService {
  HomeWidgetService._();

  static const _widgetName = 'BreezeRecentWidget';
  static const _recentComicsKey = 'recent_comics';
  static const _pluginCountKey = 'plugin_count';
  static const _maxComics = 10;

  /// iOS 端需与 Widget Extension 的 App Group 名一致（见 ios/BreezeWidget/）。
  static const _iOSAppGroupId = 'group.com.zephyr.breeze';

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// 查询最近下载并同步给小部件。
  ///
  /// 失败只打日志，不影响主流程。
  static Future<void> updateWidgetData() async {
    if (!_supported) return;

    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_iOSAppGroupId);
      }
      final query = objectbox.unifiedDownloadBox.query(
        UnifiedComicDownload_.deleted.equals(false),
      )..order(UnifiedComicDownload_.downloadedAt, flags: Order.descending);
      final builtQuery = query.build()..limit = _maxComics;
      final comics = builtQuery.find();

      final payload = jsonEncode([
        for (final comic in comics)
          {
            'title': comic.title,
            'comicId': comic.comicId,
            'source': comic.source,
            'coverPath': await _resolveCoverPath(comic),
          },
      ]);

      await HomeWidget.saveWidgetData<String>(_recentComicsKey, payload);
      await HomeWidget.saveWidgetData<int>(
        _pluginCountKey,
        PluginRegistryService.I.activePlugins().length,
      );
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'BreezeRecentWidgetProvider',
        iOSName: _widgetName,
      );
    } catch (e, s) {
      logger.w('更新桌面小部件数据失败', error: e, stackTrace: s);
    }
  }

  /// 解析 cover JSON 的本地封面路径。
  ///
  /// 下载记录的 cover.path 可能是相对路径，用 [findCachedPicturePath]
  /// 复用现有查找逻辑（下载目录 → 缓存目录），返回绝对路径或空串。
  static Future<String> _resolveCoverPath(UnifiedComicDownload comic) async {
    try {
      final decoded = jsonDecode(comic.cover);
      if (decoded is! Map) return '';
      final rawPath = decoded['path']?.toString().trim() ?? '';
      if (rawPath.isEmpty) return '';
      return await findCachedPicturePath(
        from: comic.source,
        path: rawPath,
        cartoonId: comic.comicId,
        pictureType: PictureType.cover,
      );
    } catch (_) {
      return '';
    }
  }
}
