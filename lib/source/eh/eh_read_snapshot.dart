import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/model/comic_read_snapshot.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/api/eh_url.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';

final RegExp _ehPreviewLinkPattern = RegExp(
  r'href="[^"]*/s/([0-9a-f]{10})/\d+-(\d+)',
);

Future<ComicReadSnapshot> fetchEhReadSnapshot({
  required String comicId,
  required int order,
  required String token,
  dynamic comicInfo,
}) async {
  if (token.trim().isEmpty) {
    throw const EhExceptionForSnapshot('缺少画廊 token，无法读取');
  }
  final detail = await fetchEhGalleryDetail(comicId, token);
  final pageCount = detail.pages > 0 ? detail.pages : 1;
  final imgkeys = await _fetchEhImgkeys(
    gid: comicId,
    token: token,
    pageCount: pageCount,
    detail: detail,
  );

  final comicTitle = comicInfo is PluginComicDetailSource
      ? comicInfo.title
      : detail.title;
  final pages = List<ComicReadSnapshotPage>.generate(pageCount, (index) {
    final imgkey = imgkeys[index];
    return ComicReadSnapshotPage(
      id: '$comicId-$index',
      name: 'P${index + 1}',
      path: 'eh-$comicId-$index',
      url: imgkey.isEmpty ? '' : ehGalleryPageUrl(comicId, index, imgkey),
      extern: const {},
    );
  });

  return ComicReadSnapshot(
    source: ehSourceId,
    comic: ComicReadSnapshotComic(
      id: comicId,
      source: ehSourceId,
      title: comicTitle,
    ),
    chapter: ComicReadSnapshotChapter(
      id: '',
      name: detail.title,
      order: order > 0 ? order : 1,
      pages: pages,
      extern: {'token': token},
    ),
    chapters: [
      ComicReadSnapshotChapterRef(
        id: '',
        name: detail.title,
        order: 1,
        extern: {'token': token},
      ),
    ],
    extern: {'token': token},
  );
}

Future<List<String>> _fetchEhImgkeys({
  required String gid,
  required String token,
  required int pageCount,
  required EhGalleryDetail detail,
}) async {
  final keys = List<String>.filled(pageCount, '');
  final previewPages = detail.previewPages;
  final totalPreviewPages =
      (previewPages > 0 ? previewPages : 1).clamp(0, 200);
  final pendingPages = List<int>.generate(
    totalPreviewPages,
    (index) => index,
  );

  Future<void> worker() async {
    while (pendingPages.isNotEmpty) {
      final previewPage = pendingPages.removeLast();
      try {
        final html = await fetchEhHtml(
          ehGalleryDetailUrl(gid, token, page: previewPage),
        );
        for (final match in _ehPreviewLinkPattern.allMatches(html)) {
          final imgkey = match.group(1)!;
          final pageNumber = int.tryParse(match.group(2)!) ?? 0;
          if (pageNumber >= 1 && pageNumber <= pageCount) {
            keys[pageNumber - 1] = imgkey;
          }
        }
      } catch (e) {
        logger.w('获取画廊预览分页失败: gid=$gid, page=$previewPage, error=$e');
      }
    }
  }

  final workerCount = totalPreviewPages.clamp(1, 4);
  await Future.wait(
    List.generate(workerCount, (_) => worker()),
  );

  await _fillMissingImgkeys(gid: gid, keys: keys);
  return keys;
}

Future<void> _fillMissingImgkeys({
  required String gid,
  required List<String> keys,
}) async {
  for (var index = 0; index < keys.length; index++) {
    if (keys[index].isNotEmpty) continue;
    final prevKey = index > 0 ? keys[index - 1] : '';
    if (prevKey.isEmpty) continue;
    try {
      final image = await fetchEhImagePage(
        ehGalleryPageUrl(gid, index, prevKey),
      );
      final next = image.nextImgkey;
      if (next == null || next.isEmpty) continue;
      keys[index] = next;
    } catch (_) {
      continue;
    }
  }
}

class EhExceptionForSnapshot implements Exception {
  const EhExceptionForSnapshot(this.message);

  final String message;

  @override
  String toString() => message;
}
