import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:zephyr/source/eh/models/eh_models.dart';

final RegExp _ehErrorPattern = RegExp(r'<div class="d">\n<p>([^<]+)</p>');
final RegExp _ehDetailVarPattern = RegExp(
    r'var gid = (\d+);.+?var token = "([a-f0-9]+)";.+?var apiuid = ([\-\d]+);.+?var apikey = "([a-f0-9]+)";',
    dotAll: true);
final RegExp _torrentCountPattern =
    RegExp(r'Torrent Download \((\d+)\)');
final RegExp _coverPattern =
    RegExp(r'width:(\d+)px; height:(\d+)px.+?url\((.+?)\)', dotAll: true);
final RegExp _previewPerPagePattern =
    RegExp(r'Showing \d+ - (\d+) of ([\d,]+) images');
final RegExp _intCommaPattern = RegExp(r'^[\d,]+$');

const String _offensiveString =
    '<p>(And if you choose to ignore this warning, you lose all rights to complain about it in the future.)</p>';
const String _piningString = '<p>This gallery is pining for the fjords.</p>';
const String _unavailableString = 'This gallery is unavailable';

EhGalleryDetail parseGalleryDetail(String html,
    {String gid = '', String token = ''}) {
  if (html.contains(_offensiveString)) {
    throw const EhParseException('This gallery is offensive');
  }
  if (html.contains(_piningString)) {
    throw const EhParseException('This gallery is pining for the fjords');
  }
  if (html.contains(_unavailableString)) {
    throw const EhParseException('This gallery is unavailable');
  }
  final errorMatch = _ehErrorPattern.firstMatch(html);
  if (errorMatch != null) {
    throw EhParseException(errorMatch.group(1)?.trim() ?? 'Unknown error');
  }

  final document = html_parser.parse(html);
  final detail = EhGalleryDetail(gid: gid, token: token);

  final varMatch = _ehDetailVarPattern.firstMatch(html);
  if (varMatch != null) {
    if (detail.gid.isEmpty) detail.gid = varMatch.group(1) ?? '';
    if (detail.token.isEmpty) detail.token = varMatch.group(2) ?? '';
  }

  final torrentMatch = _torrentCountPattern.firstMatch(html);
  detail.torrentCount =
      torrentMatch == null ? 0 : int.tryParse(torrentMatch.group(1)!) ?? 0;

  final gm = document.querySelector('.gm');
  if (gm == null) {
    throw const EhParseException("Can't parse gallery detail");
  }

  final gd1 = gm.querySelector('#gd1');
  if (gd1 != null && gd1.children.isNotEmpty) {
    final style = (gd1.children.first.attributes['style'] ?? '').trim();
    final coverMatch = _coverPattern.firstMatch(style);
    if (coverMatch != null) detail.coverUrl = coverMatch.group(3)?.trim() ?? '';
  }

  final gn = gm.querySelector('#gn');
  if (gn != null) detail.title = gn.text.trim();

  final gj = gm.querySelector('#gj');
  if (gj != null) detail.titleJpn = gj.text.trim();

  final gdc = gm.querySelector('#gdc');
  if (gdc != null) {
    var ce = gdc.querySelector('.cn');
    ce ??= gdc.querySelector('.cs');
    if (ce != null) {
      detail.category = ce.text.trim();
      detail.categoryIndex = ehCategoryFromName(detail.category).bit;
    }
  }

  final gdn = gm.querySelector('#gdn');
  if (gdn != null) detail.uploader = gdn.text.trim();

  final gdd = gm.querySelector('#gdd');
  if (gdd != null &&
      gdd.children.isNotEmpty &&
      gdd.children.first.children.isNotEmpty) {
    final rows = gdd.children.first.children.first.children;
    for (final row in rows) {
      _parseDetailInfoRow(detail, row);
    }
  }

  final ratingLabel = gm.querySelector('#rating_label');
  if (ratingLabel != null) {
    final ratingStr = ratingLabel.text.trim();
    if (ratingStr == 'Not Yet Rated') {
      detail.rating = -1;
    } else {
      final index = ratingStr.indexOf(' ');
      if (index == -1 || index >= ratingStr.length) {
        detail.rating = 0;
      } else {
        detail.rating =
            double.tryParse(ratingStr.substring(index + 1).trim()) ?? 0;
      }
    }
  }

  detail.tagGroups = _parseTagGroups(document);
  for (final group in detail.tagGroups) {
    for (final tag in group.tags) {
      detail.tags.add('${group.namespace}:$tag');
    }
  }

  detail.comments = _parseComments(document);
  detail.commentsCount = detail.comments.length;

  detail.previewPages = _parsePreviewPages(document);
  detail.previewPerPage = _parsePreviewPerPage(document);
  if (detail.previewPages <= 0 &&
      detail.pages > 0 &&
      detail.previewPerPage > 0) {
    detail.previewPages = (detail.pages + detail.previewPerPage - 1) ~/
        detail.previewPerPage;
  }

  detail.generateSimpleLanguage();
  return detail;
}

void _parseDetailInfoRow(EhGalleryDetail detail, Element row) {
  if (row.children.length < 2) return;
  final key = row.children[0].text.trim();
  var value = _ownText(row.children[1]).trim();
  if (value.isEmpty) value = row.children[1].text.trim();
  if (key.startsWith('Posted')) {
    detail.uploaded = value;
  } else if (key.startsWith('Visible')) {
    detail.visible = value.startsWith('Yes');
  } else if (key.startsWith('Length')) {
    final index = value.indexOf(' ');
    detail.pages = index > 0
        ? int.tryParse(value.substring(0, index).replaceAll(',', '')) ?? 1
        : 1;
  }
}

String _ownText(Element element) {
  final buffer = StringBuffer();
  for (final node in element.nodes) {
    if (node is Text) buffer.write(node.data);
  }
  return buffer.toString();
}

List<EhTagGroup> parseEhTagGroupRows(List<Element> rows) {
  final groups = <EhTagGroup>[];
  for (final row in rows) {
    try {
      if (row.children.length < 2) continue;
      var namespace = row.children[0].text.trim();
      if (namespace.isEmpty || !namespace.endsWith(':')) continue;
      namespace = namespace.substring(0, namespace.length - 1).trim();
      final tags = <String>[];
      for (final tagElement in row.children[1].children) {
        var tag = tagElement.text.trim();
        final index = tag.indexOf('|');
        if (index >= 0) tag = tag.substring(0, index).trim();
        if (tag.isNotEmpty) tags.add(tag);
      }
      if (tags.isNotEmpty) groups.add(EhTagGroup(namespace: namespace, tags: tags));
    } catch (_) {
      continue;
    }
  }
  return groups;
}

List<EhTagGroup> _parseTagGroups(Document document) {
  final taglist = document.querySelector('#taglist');
  if (taglist == null) return const [];
  try {
    return parseEhTagGroupRows(taglist.querySelectorAll('tr'));
  } catch (_) {
    return const [];
  }
}

List<EhGalleryComment> _parseComments(Document document) {
  final cdiv = document.querySelector('#cdiv');
  if (cdiv == null) return const [];
  final comments = <EhGalleryComment>[];
  final c1s = cdiv.querySelectorAll('.c1');
  for (final element in c1s) {
    final comment = _parseComment(element);
    if (comment != null) comments.add(comment);
  }
  return comments;
}

EhGalleryComment? _parseComment(Element element) {
  try {
    final comment = EhGalleryComment();

    final anchor = _previousElementSibling(element);
    if (anchor != null) {
      final name = (anchor.attributes['name'] ?? '').trim();
      if (name.length > 1) comment.id = int.tryParse(name.substring(1)) ?? 0;
    }

    final c5 = element.querySelector('.c5');
    if (c5 != null && c5.children.isNotEmpty) {
      comment.score = int.tryParse(c5.children.first.text.trim()) ?? 0;
    }

    final c3 = element.querySelector('.c3');
    if (c3 != null) {
      var temp = _ownText(c3).trim();
      if (temp.startsWith('Posted on ')) {
        temp = temp.substring('Posted on '.length);
      }
      if (temp.endsWith(' by:')) {
        temp = temp.substring(0, temp.length - ' by:'.length);
      }
      comment.postedAt = temp.trim();
      if (c3.children.isNotEmpty) {
        comment.author = c3.children.first.text.trim();
      }
    }
    if (comment.author.isEmpty) {
      final c4 = element.querySelector('.c4');
      if (c4 != null) comment.author = c4.text.trim();
    }

    final c6 = element.querySelector('.c6');
    if (c6 != null) comment.content = c6.text.trim();

    return comment;
  } catch (_) {
    return null;
  }
}

Element? _previousElementSibling(Element element) {
  final parent = element.parentNode;
  if (parent == null) return null;
  final nodes = parent.nodes;
  final index = nodes.indexOf(element);
  for (var i = index - 1; i >= 0; i--) {
    final node = nodes[i];
    if (node is Element) return node;
  }
  return null;
}

int _parsePreviewPages(Document document) {
  final tr = document.querySelector('.ptt tr');
  final tds = tr?.querySelectorAll('td');
  if (tds != null && tds.length >= 2) {
    final raw = tds[tds.length - 2].text.trim();
    if (_intCommaPattern.hasMatch(raw)) {
      return int.tryParse(raw.replaceAll(',', '')) ?? 0;
    }
  }
  return 0;
}

int _parsePreviewPerPage(Document document) {
  final gpc = document.querySelector('.gpc');
  if (gpc == null) return 0;
  final match = _previewPerPagePattern.firstMatch(gpc.text.trim());
  if (match == null) return 0;
  return int.tryParse(match.group(1) ?? '') ?? 0;
}
