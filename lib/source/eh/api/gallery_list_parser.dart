import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:zephyr/source/eh/api/eh_url.dart';
import 'package:zephyr/source/eh/api/gallery_detail_parser.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';

class EhGalleryListResult {
  final List<EhGalleryInfo> items;
  final int maxPage;

  const EhGalleryListResult({this.items = const [], this.maxPage = 0});
}

final RegExp _ratingPxPattern = RegExp(r'\d+px');
final RegExp _pagesPattern = RegExp(r'(\d+) page');
final RegExp _pageParamPattern = RegExp(r'page=(\d+)');
final RegExp _nextParamPattern = RegExp(r'next=(\d+)');

EhGalleryListResult parseGalleryList(String html) {
  final document = html_parser.parse(html);
  final items = _parseEntries(document);
  final maxPage = _parseMaxPage(document, html);
  return EhGalleryListResult(items: items, maxPage: maxPage);
}

List<EhGalleryInfo> _parseEntries(Document document) {
  final items = <EhGalleryInfo>[];
  final itg = document.querySelector('.itg');
  if (itg != null) {
    final rows =
        itg.localName == 'table' ? itg.querySelectorAll('tr') : itg.children;
    for (final row in rows) {
      final info = _parseGalleryEntry(row);
      if (info != null) items.add(info);
    }
  }
  if (items.isEmpty) {
    for (final row in document.querySelectorAll('.gl1t, .gl1e, .gl3t, .gltm')) {
      final info = _parseGalleryEntry(row);
      if (info != null) items.add(info);
    }
  }
  return items;
}

EhGalleryInfo? _parseGalleryEntry(Element e) {
  final glname = e.querySelector('.glname');
  if (glname == null) return null;
  final info = EhGalleryInfo();

  Element? link = glname.querySelector('a');
  if (link == null) {
    final parent = glname.parentNode;
    if (parent is Element && parent.localName == 'a') link = parent;
  }
  if (link != null) {
    final parts = parseEhGalleryDetailUrl(link.attributes['href'] ?? '');
    if (parts != null) {
      info.gid = parts.gid;
      info.token = parts.token;
    }
  }

  var titleNode = glname;
  while (titleNode.children.isNotEmpty) {
    titleNode = titleNode.children.first;
  }
  info.title = titleNode.text.trim();

  final tbody = glname.querySelector('tbody');
  if (tbody != null) {
    for (final group in parseEhTagGroupRows(tbody.children)) {
      for (final tag in group.tags) {
        info.tags.add('${group.namespace}:$tag');
      }
    }
  }

  if (info.title.isEmpty || info.gid.isEmpty || info.token.isEmpty) {
    return null;
  }

  var categoryElement = e.querySelector('.cn');
  categoryElement ??= e.querySelector('.cs');
  if (categoryElement != null) {
    info.category = categoryElement.text.trim();
    info.categoryIndex = ehCategoryFromName(info.category).bit;
  }

  final glThumb = e.querySelector('.glthumb');
  if (glThumb != null) {
    Element? img;
    if (glThumb.children.isNotEmpty) {
      img = glThumb.children.first.querySelector('img');
    }
    if (img != null) {
      var url = img.attributes['data-src'];
      if (url == null || url.isEmpty) url = img.attributes['src'];
      if (url != null && url.isNotEmpty) {
        info.thumbUrl = fixEhThumbUrl(url);
      }
    }
    if (glThumb.children.length > 1) {
      final d2 = glThumb.children[1];
      if (d2.children.length > 1) {
        final d3 = d2.children[1];
        if (d3.children.length > 1) {
          final match = _pagesPattern.firstMatch(d3.children[1].text);
          if (match != null) info.pages = int.tryParse(match.group(1)!) ?? 0;
        }
      }
    }
  }
  if (info.thumbUrl.isEmpty) {
    var gl = e.querySelector('.gl1e');
    gl ??= e.querySelector('.gl3t');
    if (gl != null) {
      final img = gl.querySelector('img');
      if (img != null) {
        final url = img.attributes['src'];
        if (url != null && url.isNotEmpty) info.thumbUrl = fixEhThumbUrl(url);
      }
    }
  }

  if (info.gid.isNotEmpty) {
    final posted = e.querySelector('#posted_${info.gid}');
    if (posted != null) info.uploaded = posted.text.trim();
  }

  for (final tagElement in e.querySelectorAll('.gt, .gtl')) {
    final title = tagElement.attributes['title'];
    if (title != null && title.isNotEmpty) info.tags.add(title);
  }

  final ir = e.querySelector('.ir');
  if (ir != null) {
    info.rating = _parseRating(ir.attributes['style'] ?? '');
  }

  var gl = e.querySelector('.glhide');
  var uploaderIndex = 0;
  var pagesIndex = 1;
  if (gl == null) {
    gl = e.querySelector('.gl3e');
    uploaderIndex = 3;
    pagesIndex = 4;
  }
  if (gl != null) {
    if (gl.children.length > uploaderIndex) {
      final children = gl.children[uploaderIndex].children;
      if (children.isNotEmpty) info.uploader = children.first.text.trim();
    }
    if (gl.children.length > pagesIndex) {
      final match = _pagesPattern.firstMatch(gl.children[pagesIndex].text);
      if (match != null) info.pages = int.tryParse(match.group(1)!) ?? 0;
    }
  }
  final gl5t = e.querySelector('.gl5t');
  if (gl5t != null && gl5t.children.length > 1) {
    final d = gl5t.children[1];
    if (d.children.length > 1) {
      final match = _pagesPattern.firstMatch(d.children[1].text);
      if (match != null) info.pages = int.tryParse(match.group(1)!) ?? 0;
    }
  }

  info.generateSimpleLanguage();
  return info;
}

double _parseRating(String ratingStyle) {
  final matches = _ratingPxPattern.allMatches(ratingStyle).toList();
  if (matches.length < 2) return -1;
  final num1 = int.tryParse(matches[0].group(0)!.replaceAll('px', ''));
  final num2 = int.tryParse(matches[1].group(0)!.replaceAll('px', ''));
  if (num1 == null || num2 == null) return -1;
  var rate = (5 - num1 ~/ 16).toDouble();
  if (num2 == 21) rate -= 0.5;
  return rate;
}

int _parseMaxPage(Document document, String html) {
  if (html.contains('No hits found</p>') ||
      html.contains('<p>You do not have any watched tags')) {
    return 0;
  }
  final tr = document.querySelector('.ptt tr');
  final tds = tr?.querySelectorAll('td');
  if (tds != null && tds.length >= 2) {
    final value = int.tryParse(tds[tds.length - 2].text.trim());
    if (value != null) return value;
  }
  var maxPage = 1;
  for (final match in _pageParamPattern.allMatches(html)) {
    final value = int.tryParse(match.group(1) ?? '') ?? 0;
    if (value > maxPage) maxPage = value;
  }
  for (final match in _nextParamPattern.allMatches(html)) {
    final value = (int.tryParse(match.group(1) ?? '') ?? 0) + 1;
    if (value > maxPage) maxPage = value;
  }
  return maxPage;
}
