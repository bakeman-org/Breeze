import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/page/comic_read/model/unified_plugin_chapter.dart';
import 'package:zephyr/source/bika/api/bika_api.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/utils/bika_detail_convert.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/source/eh/api/eh_client.dart';
import 'package:zephyr/source/eh/eh_read_snapshot.dart';
import 'package:zephyr/source/eh/utils/eh_detail_convert.dart';

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

Future<PluginComicDetail> getNativeComicDetail(
  String source,
  String comicId, {
  Map<String, dynamic> extern = const <String, dynamic>{},
}) async {
  switch (source.trim()) {
    case bikaSourceId:
      final details = await fetchBikaComicDetails(comicId);
      final chapters = await fetchBikaChapters(comicId);
      final info = buildBikaNormalComicInfo(details.comic, chapters);
      return PluginComicDetail(
        normalInfo: info,
        source: buildBikaDetailSource(info),
      );
    case ehSourceId:
      final token = extern['token']?.toString().trim() ?? '';
      if (token.isEmpty) {
        throw const EhExceptionForSnapshot('缺少画廊 token，无法获取详情');
      }
      final detail = await fetchEhGalleryDetail(comicId, token);
      final info = buildEhNormalComicInfo(detail);
      return PluginComicDetail(
        normalInfo: info,
        source: buildEhDetailSource(info),
      );
    default:
      throw StateError('未知的原生源: $source');
  }
}

Future<UnifiedPluginChapterResponse> getNativeChapter({
  required String source,
  required String comicId,
  required String chapterId,
  Map<String, dynamic> extern = const <String, dynamic>{},
}) async {
  switch (source.trim()) {
    case bikaSourceId:
      return _getBikaChapter(comicId, chapterId, extern);
    case ehSourceId:
      return _getEhChapter(comicId, chapterId, extern);
    default:
      throw StateError('未知的原生源: $source');
  }
}

Future<UnifiedPluginChapterResponse> _getBikaChapter(
  String comicId,
  String chapterId,
  Map<String, dynamic> extern,
) async {
  final chapters = await fetchBikaChapters(comicId);
  var matched = chapters.where((chapter) => chapter.uid == chapterId);
  if (matched.isEmpty && chapterId.isNotEmpty) {
    matched = chapters.where((chapter) => chapter.id == chapterId);
  }
  final matchedChapter = matched.isEmpty ? null : matched.first;
  final order =
      _asInt(extern['bikaOrder']) ??
      matchedChapter?.order ??
      int.tryParse(chapterId) ??
      1;
  final chapterName = matchedChapter?.title ?? '';

  final images = await fetchBikaChapterImages(
    FetchChapterImagesPayload(id: comicId, order: order),
  );
  final docs = images
      .map(
        (image) => UnifiedPluginChapterDoc(
          name: image.media.originalName,
          path: image.cacheKey.isNotEmpty ? image.cacheKey : image.uid,
          url: image.url,
          id: image.id?.isNotEmpty == true ? image.id! : image.uid,
          extern: {'bikaOrder': order},
        ),
      )
      .toList();

  return UnifiedPluginChapterResponse(
    source: bikaSourceId,
    comicId: comicId,
    chapterId: chapterId,
    extern: const <String, dynamic>{},
    scheme: const <String, dynamic>{},
    chapter: UnifiedPluginChapter(
      epId: chapterId,
      epName: chapterName,
      order: order,
      length: docs.length,
      epPages: '${docs.length}',
      docs: docs,
      extern: const <String, dynamic>{},
    ),
  );
}

Future<UnifiedPluginChapterResponse> _getEhChapter(
  String comicId,
  String chapterId,
  Map<String, dynamic> extern,
) async {
  final token = extern['token']?.toString().trim() ?? '';
  if (token.isEmpty) {
    throw const EhExceptionForSnapshot('缺少画廊 token，无法获取图片');
  }
  final snapshot = await fetchEhReadSnapshot(
    comicId: comicId,
    order: 1,
    token: token,
  );
  final docs = snapshot.chapter.pages
      .map(
        (page) => UnifiedPluginChapterDoc(
          name: page.name,
          path: page.path,
          url: page.url,
          id: page.id,
          extern: page.extern,
        ),
      )
      .toList();

  return UnifiedPluginChapterResponse(
    source: ehSourceId,
    comicId: comicId,
    chapterId: chapterId,
    extern: {'token': token},
    scheme: const <String, dynamic>{},
    chapter: UnifiedPluginChapter(
      epId: chapterId,
      epName: snapshot.chapter.name,
      order: 1,
      length: docs.length,
      epPages: '${docs.length}',
      docs: docs,
      extern: {'token': token},
    ),
  );
}
