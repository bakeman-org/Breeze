import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/type/enum.dart';

/// `breeze://` deep link 解析与分发。
///
/// 支持的 URI：
/// - `breeze://comic/{comicId}?from={source}&type=download` → 漫画详情页
/// - `breeze://plugin` → 插件页
/// - `breeze://favorite` → 书架页
///
/// 事件来源是 home_widget：
/// - 冷启动：`HomeWidget.initiallyLaunchedFromHomeWidget()`
/// - 热启动：`HomeWidget.widgetClicked`（Android 端 onNewIntent 触发）
class DeepLinkHandler {
  DeepLinkHandler._();

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    _initialized = true;

    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handle);
    HomeWidget.widgetClicked.listen(_handle);
  }

  static void _handle(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return;
    logger.i('收到 deep link: $uri');

    final host = uri.host;
    if (host == 'comic') {
      final comicId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (comicId.isEmpty) return;
      appRouter.push(
        ComicInfoRoute(
          comicId: comicId,
          from: uri.queryParameters['from'] ?? '',
          type: _parseEntryType(uri.queryParameters['type']),
        ),
      );
      return;
    }
    if (host == 'plugin') {
      appRouter.push(const PluginStoreRoute());
      return;
    }
    if (host == 'favorite') {
      appRouter.push(const BookshelfRoute());
    }
  }

  static ComicEntryType _parseEntryType(String? raw) {
    return ComicEntryType.values.asNameMap()[raw] ?? ComicEntryType.download;
  }
}
