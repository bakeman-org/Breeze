import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/model/comic_read_snapshot.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';

Future<ComicReadSnapshot> fetchBikaReadSnapshot({
  required String comicId,
  required int order,
  dynamic comicInfo,
}) async {
  final imagesFuture = fetchBikaChapterImages(
    FetchChapterImagesPayload(id: comicId, order: order),
  );
  final chaptersFuture = fetchBikaChapters(comicId).catchError((Object error) {
    return const <Chapter>[];
  });
  final images = await imagesFuture;
  final chapters = await chaptersFuture;

  final pages = images
      .map(
        (image) => ComicReadSnapshotPage(
          id: image.id?.isNotEmpty == true ? image.id! : image.uid,
          name: image.media.originalName,
          path: image.cacheKey.isNotEmpty ? image.cacheKey : image.uid,
          url: image.url,
          extern: {'bikaOrder': order},
        ),
      )
      .toList();

  final comicTitle = comicInfo is Comic
      ? comicInfo.title
      : comicInfo is PluginComicDetailSource
      ? comicInfo.title
      : '';
  final chapterName = chapters
      .where((chapter) => chapter.order == order)
      .map((chapter) => chapter.title)
      .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');

  final chapterId = chapters
      .where((chapter) => chapter.order == order)
      .map((chapter) => chapter.uid)
      .firstWhere((uid) => uid.isNotEmpty, orElse: () => '');

  return ComicReadSnapshot(
    source: 'bika',
    comic: ComicReadSnapshotComic(
      id: comicId,
      source: 'bika',
      title: comicTitle,
    ),
    chapter: ComicReadSnapshotChapter(
      id: chapterId,
      name: chapterName,
      order: order,
      pages: pages,
      extern: {},
    ),
    chapters: chapters
        .map(
          (chapter) => ComicReadSnapshotChapterRef(
            id: chapter.uid,
            name: chapter.title,
            order: chapter.order,
          ),
        )
        .toList(),
    extern: {},
  );
}
