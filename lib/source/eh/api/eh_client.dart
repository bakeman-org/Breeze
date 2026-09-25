import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/source/eh/api/eh_url.dart';
import 'package:zephyr/source/eh/api/gallery_detail_parser.dart';
import 'package:zephyr/source/eh/api/gallery_list_parser.dart';
import 'package:zephyr/source/eh/api/gallery_page_parser.dart';
import 'package:zephyr/source/eh/auth/eh_setting.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';

class EhLoginRequiredException implements Exception {
  const EhLoginRequiredException([
    this.message = 'E-Hentai 登录失效，请检查 ipb_member_id / ipb_pass_hash / igneous',
  ]);

  final String message;

  @override
  String toString() => message;
}

class EhHttpException implements Exception {
  const EhHttpException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'E-Hentai 请求失败${statusCode == null ? '' : ' HTTP $statusCode'}: $message';
}

class EhImage509Exception implements Exception {
  const EhImage509Exception(this.url);

  final String url;

  @override
  String toString() => 'E-Hentai 图片带宽受限（509）: $url';
}

const String _ehUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';
const String _ehAccept =
    'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8';
const String _ehAcceptLanguage = 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7';
const String _ehSadPandaDisposition = 'inline; filename="sadpanda.jpg"';
const String _ehKokomadeUrl = 'https://exhentai.org/img/kokomade.jpg';

WindHttp _createEhHttp() {
  return WindHttp(
    userAgent: _ehUserAgent,
    dangerAcceptInvalidCerts: true,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    resolveHosts: activeEhResolveHosts(),
  );
}

Map<String, String> _ehHeaders({String? referer, bool withOrigin = false}) {
  final headers = <String, String>{
    'User-Agent': _ehUserAgent,
    'Accept': _ehAccept,
    'Accept-Language': _ehAcceptLanguage,
    'Referer': referer ?? ehReferer(),
    if (withOrigin) 'Origin': ehReferer(),
  };
  final cookie = ehSettingState.cookieHeader;
  if (cookie.isNotEmpty) headers['Cookie'] = cookie;
  return headers;
}

void _checkEhResponse(FetchResponse response, String body) {
  if (response.status == 401 || response.status == 403) {
    throw EhLoginRequiredException(
      'E-Hentai 拒绝访问（HTTP ${response.status}），登录信息可能已失效',
    );
  }
  final disposition = response.header('content-disposition') ?? '';
  if (disposition.trim() == _ehSadPandaDisposition) {
    throw const EhLoginRequiredException('Sad Panda，igneous 可能已失效');
  }
  final lowered = body.toLowerCase();
  if (body.contains(_ehKokomadeUrl) ||
      lowered.contains('sad panda') ||
      lowered.contains('kokomade')) {
    throw const EhLoginRequiredException('本次访问被 E-Hentai 拒绝，请检查登录信息');
  }
  if (body.trim().isEmpty) {
    throw const EhLoginRequiredException('响应内容为空，EX 登录信息可能无效');
  }
  if (response.status >= 400) {
    throw EhHttpException('请求失败', statusCode: response.status);
  }
}

Future<String> fetchEhHtml(String url, {String? referer}) async {
  final response = await _createEhHttp().fetch(
    url,
    headers: _ehHeaders(referer: referer),
  );
  final body = response.text;
  _checkEhResponse(response, body);
  return body;
}

Future<EhGalleryListResult> fetchEhGalleryList({
  String keyword = '',
  int? categoryMask,
  int page = 0,
  bool popular = false,
  String sortParam = '',
}) async {
  final url = buildEhGalleryListUrl(
    keyword: keyword,
    categoryMask: categoryMask,
    page: page,
    popular: popular,
    sortParam: sortParam,
  );
  final html = await fetchEhHtml(url);
  return parseGalleryList(html);
}

Future<EhGalleryDetail> fetchEhGalleryDetail(
  String gid,
  String token, {
  int page = 0,
}) async {
  final url = ehGalleryDetailUrl(gid, token, page: page);
  final html = await fetchEhHtml(url);
  return parseGalleryDetail(html, gid: gid, token: token);
}

Future<List<EhGalleryInfo>> fetchEhGalleryMetadataByApi(
  List<EhGalleryInfo> items,
) async {
  if (items.isEmpty) return items;
  final gidlist = [
    for (final item in items) [item.gid, item.token],
  ];
  final response = await _createEhHttp().fetch(
    ehApiUrl(),
    method: 'POST',
    headers: _ehHeaders(withOrigin: true),
    body: <String, dynamic>{
      'method': 'gdata',
      'gidlist': gidlist,
      'namespace': 1,
    },
  );
  if (response.status >= 400) {
    throw EhHttpException('gdata 请求失败', statusCode: response.status);
  }
  final data = response.json;
  if (data is! Map) {
    throw const EhParseException('gdata 响应格式错误');
  }
  final gmetadata = data['gmetadata'];
  if (gmetadata is! List) {
    throw const EhParseException('gdata 响应缺少 gmetadata');
  }
  for (final entry in gmetadata) {
    if (entry is! Map) continue;
    final gid = '${entry['gid'] ?? ''}';
    EhGalleryInfo? target;
    for (final item in items) {
      if (item.gid == gid) {
        target = item;
        break;
      }
    }
    if (target == null) continue;
    target.title = '${entry['title'] ?? target.title}';
    target.titleJpn = '${entry['title_jpn'] ?? target.titleJpn}';
    final category = '${entry['category'] ?? ''}';
    if (category.isNotEmpty) {
      target.category = category;
      target.categoryIndex = ehCategoryFromName(category).bit;
    }
    final thumb = '${entry['thumb'] ?? ''}';
    if (thumb.isNotEmpty) target.thumbUrl = fixEhThumbUrl(thumb);
    target.uploader = '${entry['uploader'] ?? target.uploader}';
    final posted = int.tryParse('${entry['posted'] ?? ''}');
    if (posted != null) target.uploaded = _formatPostedTime(posted);
    target.rating =
        double.tryParse('${entry['rating'] ?? ''}') ?? target.rating;
    final tags = entry['tags'];
    if (tags is List) {
      target.tags = tags.map((e) => '$e').toList();
    }
    final filecount = int.tryParse('${entry['filecount'] ?? ''}');
    if (filecount != null) target.pages = filecount;
    target.generateSimpleLanguage();
  }
  return items;
}

Future<EhPageImage> fetchEhImagePage(
  String viewerUrl, {
  String? referer,
}) async {
  final html = await fetchEhHtml(viewerUrl, referer: referer);
  return parseGalleryPage(html);
}

Future<EhPageImage> fetchEhGalleryPageApi({
  required String gid,
  required int page,
  required String imgkey,
  required String showKey,
  String? referer,
}) async {
  final gidValue = int.tryParse(gid);
  if (gidValue == null) {
    throw EhParseException('无效的画廊 gid: $gid');
  }
  final response = await _createEhHttp().fetch(
    ehApiUrl(),
    method: 'POST',
    headers: _ehHeaders(referer: referer, withOrigin: true),
    body: {
      'method': 'showpage',
      'gid': gidValue,
      'page': page,
      'imgkey': imgkey,
      'showkey': showKey,
    },
  );
  if (response.status >= 400) {
    throw EhHttpException('showpage 请求失败', statusCode: response.status);
  }
  return parseGalleryPageApi(response.text);
}

String _formatPostedTime(int seconds) {
  final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${pad(time.month)}-${pad(time.day)} '
      '${pad(time.hour)}:${pad(time.minute)}';
}
