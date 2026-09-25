import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/core/source_registry.dart';

normal.NormalComicAllInfo buildBikaNormalComicInfo(
  Comic comic,
  List<Chapter> chapters,
) {
  final avatar = comic.creator.avatar;
  return normal.NormalComicAllInfo(
    comicInfo: normal.ComicInfo(
      id: comic.id,
      title: comic.title,
      titleMeta: const [],
      creator: normal.Creator(
        id: comic.creator.id,
        name: comic.creator.name,
        avatar: normal.ComicImage(
          id: comic.creator.id,
          url: avatar?.url ?? '',
          name: avatar?.originalName ?? '',
          path: avatar?.cacheKey ?? '',
          extern: {'from': bikaSourceId},
        ),
      ),
      description: comic.description,
      cover: normal.ComicImage(
        id: comic.id,
        url: comic.thumb.url,
        name: comic.thumb.originalName,
        path: comic.thumb.cacheKey,
        extern: {'from': bikaSourceId},
      ),
      metadata: [
        normal.ComicInfoMetadata(
          type: 'author',
          name: comic.author ?? '',
          value: const [],
        ),
        normal.ComicInfoMetadata(
          type: 'categories',
          name: comic.categories.join(' · '),
          value: const [],
        ),
        normal.ComicInfoMetadata(
          type: 'tags',
          name: comic.tags.join(' · '),
          value: const [],
        ),
      ],
    ),
    eps: chapters
        .map(
          (chapter) => normal.Ep(
            id: chapter.uid,
            name: chapter.title,
            order: chapter.order,
            logicalKey: chapter.uid,
            extern: {'bikaOrder': chapter.order},
          ),
        )
        .toList(),
    recommend: const [],
    totalViews: comic.totalViews,
    totalLikes: comic.likesCount,
    totalComments: comic.commentsCount,
    isFavourite: comic.isFavourite,
    isLiked: comic.isLiked,
    allowComments: comic.allowComment,
    allowLike: true,
    allowCollected: true,
    allowDownload: comic.allowDownload,
    extern: {'from': bikaSourceId},
  );
}

PluginComicDetailSource buildBikaDetailSource(normal.NormalComicAllInfo info) {
  return PluginComicDetailSource(from: bikaSourceId, normalInfo: info, raw: const {});
}
