import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:zephyr/source/eh/models/eh_models.dart';

final RegExp _ehImageUrlPattern = RegExp(r'<img[^>]*src="([^"]+)" style');
final RegExp _ehSkipHathKeyPattern =
    RegExp(r'''onclick="return nl\('([^\)]+)'\)"''');
final RegExp _ehOriginImageUrlPattern =
    RegExp(r'<a href="([^"]+)fullimg([^"]+)">');
final RegExp _ehShowKeyPattern = RegExp(r'var showkey="([0-9a-z]+)";');
final RegExp _ehNextImgkeyPattern = RegExp(r'/s/([0-9a-f]{10})/');
final RegExp _ehWidthPattern = RegExp(r'width:(\d+)px');
final RegExp _ehHeightPattern = RegExp(r'height:(\d+)px');

String _unescapeXml(String source) {
  return source
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'");
}

EhPageImage parseGalleryPage(String html) {
  final result = EhPageImage();

  var match = _ehImageUrlPattern.firstMatch(html);
  if (match != null) {
    result.imageUrl = _unescapeXml((match.group(1) ?? '').trim());
  }
  match = _ehSkipHathKeyPattern.firstMatch(html);
  if (match != null) {
    result.skipHathKey = _unescapeXml((match.group(1) ?? '').trim());
  }
  match = _ehOriginImageUrlPattern.firstMatch(html);
  if (match != null) {
    result.originImageUrl =
        '${_unescapeXml(match.group(1) ?? '')}fullimg${_unescapeXml(match.group(2) ?? '')}';
  }
  match = _ehShowKeyPattern.firstMatch(html);
  if (match != null) {
    result.showKey = match.group(1) ?? '';
  }

  final document = html_parser.parse(html);

  final img = document.querySelector('#sm') ?? document.querySelector('#i3 img');
  if (img != null) {
    final src = img.attributes['src'];
    if (src != null && src.isNotEmpty && result.imageUrl.isEmpty) {
      result.imageUrl = _unescapeXml(src.trim());
    }
    final style = img.attributes['style'] ?? '';
    final widthMatch = _ehWidthPattern.firstMatch(style);
    final heightMatch = _ehHeightPattern.firstMatch(style);
    if (widthMatch != null) {
      result.width = int.tryParse(widthMatch.group(1)!);
    }
    if (heightMatch != null) {
      result.height = int.tryParse(heightMatch.group(1)!);
    }
  }

  if (result.showKey.isEmpty) {
    for (final script in document.querySelectorAll('script')) {
      final scriptMatch = _ehShowKeyPattern.firstMatch(script.text);
      if (scriptMatch != null) {
        result.showKey = scriptMatch.group(1) ?? '';
        break;
      }
    }
  }

  if (result.imageUrl.isEmpty || result.showKey.isEmpty) {
    throw const EhParseException("Parse image url and show error");
  }

  Element? next = document.querySelector('#next');
  if (next == null) {
    for (final anchor in document.querySelectorAll('a')) {
      final text = anchor.text.trim();
      final href = anchor.attributes['href'] ?? '';
      if (text == '>' && href.contains('/s/')) {
        next = anchor;
        break;
      }
    }
  }
  if (next != null) {
    final href = next.attributes['href'] ?? '';
    final nextMatch = _ehNextImgkeyPattern.firstMatch(href);
    if (nextMatch != null) {
      final imgkey = nextMatch.group(1);
      if (imgkey != null && imgkey.isNotEmpty) result.nextImgkey = imgkey;
    }
  }

  return result;
}
