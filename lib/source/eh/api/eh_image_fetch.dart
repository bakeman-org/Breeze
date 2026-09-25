import 'dart:typed_data';

import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/api/gallery_page_parser.dart';
import 'package:zephyr/source/eh/auth/eh_setting.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';

final RegExp ehViewerPageUrlPattern = RegExp(r'/s/([0-9a-f]{10})/(\d+)-(\d+)');

const String _ehSadPandaDisposition = 'inline; filename="sadpanda.jpg"';

final Map<String, String> _ehShowKeyCache = <String, String>{};

void clearEhShowKeyCache() {
  _ehShowKeyCache.clear();
}

String _stripQuery(String url) {
  final queryIndex = url.indexOf('?');
  return queryIndex >= 0 ? url.substring(0, queryIndex) : url;
}

void _throwIfRateLimitedImageUrl(String imageUrl) {
  if (imageUrl.endsWith('/509.gif') || imageUrl.endsWith('/509s.gif')) {
    throw EhImage509Exception(imageUrl);
  }
}

Future<Uint8List> fetchEhImage(
  String url, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final match = ehViewerPageUrlPattern.firstMatch(url);
  if (match == null) {
    return _downloadEhImage(
      url,
      referer: ehSettingState.referer,
      timeout: timeout,
    );
  }
  return _fetchEhViewerPageImage(url, match, timeout);
}

Future<Uint8List> _fetchEhViewerPageImage(
  String viewerUrl,
  RegExpMatch match,
  Duration timeout,
) async {
  final imgkey = match.group(1)!;
  final gid = match.group(2)!;
  final page = int.tryParse(match.group(3)!) ?? 0;
  final basePageUrl = _stripQuery(viewerUrl);
  var skipHathKey = '';

  for (var attempt = 0; attempt < 5; attempt++) {
    final pageUrl = skipHathKey.isEmpty
        ? basePageUrl
        : '$basePageUrl?nl=$skipHathKey';
    final image = await _resolvePageResult(
      gid: gid,
      page: page,
      imgkey: imgkey,
      pageUrl: pageUrl,
      referer: basePageUrl,
    );
    final imageUrl = image.imageUrl.trim();
    if (imageUrl.isEmpty) {
      throw EhParseException('查看页未解析出图片地址: $pageUrl');
    }
    _throwIfRateLimitedImageUrl(imageUrl);
    try {
      return await _downloadEhImage(
        imageUrl,
        referer: basePageUrl,
        timeout: timeout,
      );
    } on EhImage509Exception {
      rethrow;
    } on EhLoginRequiredException {
      rethrow;
    } catch (_) {
      final retryKey = image.skipHathKey.trim();
      if (retryKey.isEmpty || retryKey == skipHathKey) {
        rethrow;
      }
      skipHathKey = retryKey;
    }
  }

  throw EhHttpException('图片下载失败（已尝试换源）: $basePageUrl');
}

Future<EhPageImage> _resolvePageResult({
  required String gid,
  required int page,
  required String imgkey,
  required String pageUrl,
  required String referer,
}) async {
  final cachedShowKey = _ehShowKeyCache[gid];
  if (cachedShowKey != null && cachedShowKey.isNotEmpty) {
    try {
      return await fetchEhGalleryPageApi(
        gid: gid,
        page: page,
        imgkey: imgkey,
        showKey: cachedShowKey,
        referer: referer,
      );
    } on EhShowKeyMismatchException {
      _ehShowKeyCache.remove(gid);
    }
  }

  final html = await fetchEhHtml(pageUrl, referer: referer);
  final result = parseGalleryPage(html);
  if (result.showKey.isNotEmpty) {
    _ehShowKeyCache[gid] = result.showKey;
  }
  return result;
}

Future<Uint8List> _downloadEhImage(
  String imageUrl, {
  required String referer,
  required Duration timeout,
}) async {
  final setting = ehSettingState;
  final headers = <String, String>{
    'User-Agent': _ehImageUserAgent,
    'Accept': _ehImageAccept,
    'Referer': referer,
  };
  final cookie = setting.cookieHeader;
  if (cookie.isNotEmpty) headers['Cookie'] = cookie;
  final response = await WindHttp(
    headers: headers,
    resolveHosts: activeEhResolveHosts(),
  ).fetch(imageUrl, timeout: timeout);

  final disposition = response.header('content-disposition') ?? '';
  if (disposition.trim() == _ehSadPandaDisposition) {
    throw const EhLoginRequiredException('Sad Panda，igneous 可能已失效');
  }
  if (response.status == 404 || response.status == 422) {
    throw EhHttpException('图片不存在', statusCode: response.status);
  }
  if (response.status < 200 || response.status >= 300) {
    throw EhHttpException('图片下载失败', statusCode: response.status);
  }
  if (response.body.isEmpty) {
    throw EhHttpException('图片响应体为空', statusCode: response.status);
  }
  return response.body;
}

const String _ehImageUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';
const String _ehImageAccept =
    'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8';
