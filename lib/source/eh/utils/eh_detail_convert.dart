import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/source/core/source_registry.dart';
import 'package:zephyr/source/eh/models/eh_models.dart';

normal.NormalComicAllInfo buildEhNormalComicInfo(EhGalleryDetail detail) {
  return normal.NormalComicAllInfo(
    comicInfo: normal.ComicInfo(
      id: detail.gid,
      title: detail.title,
      titleMeta: const [],
      creator: normal.Creator(
        id: detail.uploader,
        name: detail.uploader,
        avatar: const normal.ComicImage(id: '', url: '', name: ''),
      ),
      description: '',
      cover: normal.ComicImage(
        id: detail.gid,
        url: detail.coverUrl,
        name: '',
        path: 'eh-${detail.gid}-cover',
        extern: {'from': ehSourceId},
      ),
      metadata: [
        normal.ComicInfoMetadata(
          type: 'category',
          name: detail.category,
          value: const [],
        ),
        normal.ComicInfoMetadata(
          type: 'tags',
          name: detail.tagGroups
              .expand((group) => group.tags.map((tag) => tag))
              .join(' · '),
          value: const [],
        ),
      ],
    ),
    eps: [
      normal.Ep(
        id: '',
        name: detail.title,
        order: 1,
        extern: {'token': detail.token},
      ),
    ],
    recommend: const [],
    totalViews: 0,
    totalLikes: 0,
    totalComments: detail.commentsCount,
    isFavourite: false,
    isLiked: false,
    allowComments: true,
    allowLike: false,
    allowCollected: false,
    allowDownload: true,
    extern: {
      'token': detail.token,
      'rating': detail.rating,
      'category': detail.category,
    },
  );
}

PluginComicDetailSource buildEhDetailSource(normal.NormalComicAllInfo info) {
  return PluginComicDetailSource(from: ehSourceId, normalInfo: info, raw: const {});
}
