// lib/service/translation/translation_api.dart
// 在线翻译 API 封装：google（免 key）/ deepl（key）。

import 'package:zephyr/main.dart';

class TranslationApi {
  TranslationApi._();

  static Future<String> translate({
    required String text,
    required String provider,
    required String apiKey,
    required String targetLang,
  }) async {
    if (text.trim().isEmpty) return '';
    switch (provider) {
      case 'deepl':
        return _deepl(text, apiKey, targetLang);
      default:
        return _google(text, targetLang);
    }
  }

  // https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh&dt=t&q=
  static Future<String> _google(String text, String targetLang) async {
    final res = await fetch(
      'https://translate.googleapis.com/translate_a/single',
      query: {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLang,
        'dt': 't',
        'q': text,
      },
      timeout: const Duration(seconds: 15),
    );
    if (!res.ok) {
      throw Exception('google translate HTTP ${res.status}');
    }
    final data = res.json;
    if (data is! List || data.isEmpty || data[0] is! List) {
      throw Exception('google translate: unexpected response');
    }
    final buffer = StringBuffer();
    for (final segment in data[0]) {
      if (segment is List && segment.isNotEmpty && segment[0] is String) {
        buffer.write(segment[0]);
      }
    }
    final translated = buffer.toString().trim();
    if (translated.isEmpty) {
      throw Exception('google translate: empty result');
    }
    return translated;
  }

  // DeepL: key 以 :fx 结尾为免费版（api-free）。
  static Future<String> _deepl(
    String text,
    String apiKey,
    String targetLang,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('deepl: missing API key');
    }
    final host = apiKey.endsWith(':fx')
        ? 'https://api-free.deepl.com'
        : 'https://api.deepl.com';
    final res = await fetch(
      '$host/v2/translate',
      method: 'POST',
      headers: {'Authorization': 'DeepL-Auth-Key ${apiKey.trim()}'},
      body: {
        'text': [text],
        'target_lang': targetLang.toLowerCase() == 'zh' ? 'ZH' : 'EN',
      },
      timeout: const Duration(seconds: 15),
    );
    if (!res.ok) {
      throw Exception('deepl HTTP ${res.status}');
    }
    final data = res.json;
    final translations = data?['translations'];
    if (translations is! List || translations.isEmpty) {
      throw Exception('deepl: unexpected response');
    }
    final translated = translations[0]?['text'];
    if (translated is! String || translated.trim().isEmpty) {
      throw Exception('deepl: empty result');
    }
    return translated.trim();
  }
}
