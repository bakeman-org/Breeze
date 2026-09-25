import 'dart:typed_data';

import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/api/gallery_page_parser.dart';
import 'package:zephyr/source/eh/auth/eh_setting.dart';

class NativeImageHttpException implements Exception {
  const NativeImageHttpException(this.url, this.message, {this.statusCode});

  final String url;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    return '原生图源请求失败$status: $url: $message';
  }
}

String rewriteBikaImageUrl(String url) {
  if (!globalSetting.bikaImageAcceleration) return url;
  if (!url.contains('picacomic')) return url;
  return url.replaceFirst('picacomic', 'go2778');
}

const _ehImageUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

Future<Uint8List> fetchNativeSourceImage(
  String url, {
  required String source,
  Duration timeout = const Duration(seconds: 30),
}) async {
  switch (source.trim()) {
    case bikaSourceId:
      return _fetchBikaImage(url, timeout);
    case ehSourceId:
      return _fetchEhImage(url, timeout);
    default:
      throw StateError('未知的原生图源: $source');
  }
}

Future<Uint8List> _fetchBikaImage(String url, Duration timeout) async {
  final response = await WindHttp(
    headers: const {'User-Agent': 'okhttp/3.8.1'},
  ).fetch(rewriteBikaImageUrl(url), timeout: timeout);
  return _ensureImageBytes(url, response);
}

final RegExp _ehViewerPagePattern = RegExp(r'/s/[0-9a-f]{10}-\d+-\d+');

Future<Uint8List> _fetchEhImage(String url, Duration timeout) async {
  if (_ehViewerPagePattern.hasMatch(url)) {
    return _fetchEhImageViaViewerPage(url, timeout);
  }
  return _downloadEhImage(url, url, timeout);
}

Future<Uint8List> _fetchEhImageViaViewerPage(
  String viewerUrl,
  Duration timeout,
) async {
  final html = await fetchEhHtml(viewerUrl);
  final image = parseGalleryPage(html);
  final imageUrl = image.imageUrl.trim();
  if (imageUrl.isEmpty) {
    throw NativeImageHttpException(viewerUrl, '查看页未解析出图片地址');
  }
  return _downloadEhImage(imageUrl, viewerUrl, timeout);
}

Future<Uint8List> _downloadEhImage(
  String imageUrl,
  String requestUrl,
  Duration timeout,
) async {
  final setting = ehSettingState;
  final headers = <String, String>{
    'User-Agent': _ehImageUserAgent,
    'Referer': setting.referer,
  };
  final cookie = setting.cookieHeader;
  if (cookie.isNotEmpty) headers['Cookie'] = cookie;
  final response = await WindHttp(
    headers: headers,
    resolveHosts: activeEhResolveHosts(),
  ).fetch(imageUrl, timeout: timeout);
  return _ensureImageBytes(requestUrl, response);
}

Uint8List _ensureImageBytes(String url, FetchResponse response) {
  if (response.status == 404 || response.status == 422) {
    throw NativeImageHttpException(
      url,
      'HTTP ${response.status}',
      statusCode: response.status,
    );
  }
  if (response.status < 200 || response.status >= 300) {
    throw NativeImageHttpException(
      url,
      'HTTP ${response.status}',
      statusCode: response.status,
    );
  }
  if (response.body.isEmpty) {
    throw NativeImageHttpException(url, '响应体为空', statusCode: response.status);
  }
  return response.body;
}
