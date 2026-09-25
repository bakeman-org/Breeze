import 'package:zephyr/source/eh/auth/eh_setting.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';

class EhGalleryUrlParts {
  final String gid;
  final String token;

  const EhGalleryUrlParts(this.gid, this.token);
}

final RegExp _ehDetailUrlStrictPattern = RegExp(
  r'https?://(?:exhentai\.org|e-hentai\.org|lofi\.e-hentai\.org)/(?:g|mpv)/(\d+)/([0-9a-f]{10})',
);
final RegExp _ehDetailUrlLoosePattern = RegExp(
  r'(\d+)/([0-9a-f]{10})(?:[^0-9a-f]|$)',
);

String _ehDomain() => ehSettingState.domain;

String ehHost() => 'https://${_ehDomain()}/';

String ehReferer() => 'https://${_ehDomain()}';

String ehApiUrl() => _ehDomain() == ehDomainEx
    ? 'https://exhentai.org/api.php'
    : 'https://api.e-hentai.org/api.php';

String ehUConfigUrl() => '${ehHost()}uconfig.php';

String ehHomeUrl() => '${ehHost()}home.php';

String ehFavoritesUrl() => '${ehHost()}favorites.php';

String ehPopularUrl() => 'https://${_ehDomain()}/popular';

String ehWatchedUrl() => '${ehHost()}watched';

String ehNewsUrl() => 'https://$ehDomainE/news.php';

String ehForumsUrl() => 'https://forums.e-hentai.org/';

String ehGalleryDetailUrl(
  String gid,
  String token, {
  int page = 0,
  bool allComments = false,
}) {
  var url = '${ehHost()}g/$gid/$token/';
  final params = <String>[];
  if (page > 0) params.add('p=$page');
  if (allComments) params.add('hc=1');
  if (params.isNotEmpty) url = '$url?${params.join('&')}';
  return url;
}

String ehGalleryPageUrl(String gid, int page, String imgkey) =>
    '${ehHost()}s/$imgkey/$gid-${page + 1}';

String ehAddFavoritesUrl(String gid, String token) =>
    '${ehHost()}gallerypopups.php?gid=$gid&t=$token&act=addfav';

String ehTagDefinitionUrl(String tag) =>
    'https://ehwiki.org/wiki/${tag.replaceAll(' ', '_')}';

String buildEhGalleryListUrl({
  String keyword = '',
  int? categoryMask,
  int page = 0,
  bool popular = false,
  String sortParam = '',
}) {
  var url = popular ? ehPopularUrl() : ehHost();
  final params = <String, String>{};
  if (categoryMask != null &&
      categoryMask != 0 &&
      categoryMask != ehAllCategoryBits) {
    params['f_cats'] = '${(~categoryMask) & ehAllCategoryBits}';
  }
  final kw = keyword.trim();
  if (kw.isNotEmpty) params['f_search'] = kw;
  if (page > 0) params[popular ? 'next' : 'page'] = '$page';
  final encoded = params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');
  final sort = sortParam.trim();
  if (sort.isNotEmpty) {
    url = encoded.isEmpty ? '$url?$sort' : '$url?$encoded&$sort';
  } else if (encoded.isNotEmpty) {
    url = '$url?$encoded';
  }
  return url;
}

EhGalleryUrlParts? parseEhGalleryDetailUrl(String url) {
  var match = _ehDetailUrlStrictPattern.firstMatch(url);
  match ??= _ehDetailUrlLoosePattern.firstMatch(url);
  if (match == null) return null;
  final gid = match.group(1);
  final token = match.group(2);
  if (gid == null || token == null || gid.isEmpty) return null;
  return EhGalleryUrlParts(gid, token);
}

String fixEhThumbUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final segments = uri.pathSegments;
  if (segments.length < 3) return url;
  final last = segments[segments.length - 1];
  final second = segments[segments.length - 2];
  final third = segments[segments.length - 3];
  if (last.startsWith(third) && last.startsWith(second, third.length)) {
    return 'https://ehgt.org/$third/$second/$last';
  }
  return url;
}
