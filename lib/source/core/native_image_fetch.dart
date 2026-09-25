import 'dart:typed_data';

import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/source/eh/api/eh_image_fetch.dart';

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

Future<Uint8List> fetchNativeSourceImage(
  String url, {
  required String source,
  Duration timeout = const Duration(seconds: 30),
}) async {
  switch (source.trim()) {
    case bikaSourceId:
      return _fetchBikaImage(url, timeout);
    case ehSourceId:
      return fetchEhImage(url, timeout: timeout);
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

Uint8List _ensureImageBytes(String url, FetchResponse response) {
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
