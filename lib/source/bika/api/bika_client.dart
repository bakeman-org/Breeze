import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/source/bika/auth/bika_setting.dart';

enum BikaMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE');

  final String value;

  const BikaMethod(this.value);
}

const _bikaApiKey = 'C69BAF41DA5ABD1FFEDC6D2FEA56B';
const _bikaSecretKey =
    "~d}\$Q7\$eIni=V)9\\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn";
const _bikaNonce = '4ce7a7aa759b40f794d189a88b84aba8';

const _bikaDefaultHeaders = <String, String>{
  'accept': 'application/vnd.picacomic.com.v1+json',
  'User-Agent': 'okhttp/3.8.1',
  'Content-Type': 'application/json; charset=UTF-8',
  'api-key': _bikaApiKey,
  'app-build-version': '45',
  'app-platform': 'android',
  'app-uuid': 'defaultUuid',
  'app-version': '2.2.1.3.3.4',
  'nonce': _bikaNonce,
  'app-channel': '1',
};

class BikaApiException implements Exception {
  const BikaApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'Bika API 错误${statusCode == null ? '' : ' HTTP $statusCode'}: $message';
}

class BikaUnauthorizedException extends BikaApiException {
  const BikaUnauthorizedException() : super('登录失效', statusCode: 401);
}

String _bikaSignature(String url, String timestamp, BikaMethod method) {
  final key = (url + timestamp + _bikaNonce + method.value + _bikaApiKey)
      .toLowerCase();
  final hmac = Hmac(sha256, utf8.encode(_bikaSecretKey));
  return hmac.convert(utf8.encode(key)).toString();
}

Map<String, String> _bikaHeaders(String url, BikaMethod method) {
  final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  final setting = bikaNativeSetting;
  return {
    ..._bikaDefaultHeaders,
    'time': timestamp,
    'signature': _bikaSignature(url, timestamp, method),
    'authorization': setting.authorization,
    'image-quality': setting.imageQuality,
  };
}

Future<dynamic> bikaRequest(
  String path, {
  BikaMethod method = BikaMethod.get,
  Map<String, dynamic>? payload,
}) async {
  final host = bikaNativeSetting.apiHost;
  var signedUrl = path;
  var url = '$host$path';
  if (method == BikaMethod.get && payload != null && payload.isNotEmpty) {
    final query = Uri(
      queryParameters: payload.map((key, value) => MapEntry(key, '$value')),
    ).query;
    if (query.isNotEmpty) {
      signedUrl = '$path?$query';
      url = '$url?$query';
    }
  }
  final headers = _bikaHeaders(signedUrl, method);

  var attempt = 0;
  while (true) {
    attempt += 1;
    try {
      final response = await WindHttp().fetch(
        url,
        method: method.value,
        headers: headers,
        body: method == BikaMethod.get ? null : payload,
      );
      if (response.status == 200) {
        return response.json;
      }
      if (response.status == 401) {
        throw const BikaUnauthorizedException();
      }
      if (response.status == 400) {
        final data = response.json;
        final message = data is Map && data['message'] != null
            ? '${data['message']}'
            : '请求失败';
        throw BikaApiException(message, statusCode: 400);
      }
      throw BikaApiException('请求失败', statusCode: response.status);
    } on BikaUnauthorizedException {
      rethrow;
    } on BikaApiException catch (e) {
      final status = e.statusCode;
      final retryable = status != null && status >= 500 && status < 600;
      if (retryable && attempt < 3) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      rethrow;
    } on TimeoutException {
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      throw const BikaApiException('连接超时');
    } on Exception catch (e) {
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      throw BikaApiException('网络请求失败: $e');
    }
  }
}
