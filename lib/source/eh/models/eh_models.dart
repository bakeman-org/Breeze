class EhParseException implements Exception {
  const EhParseException(this.message);

  final String message;

  @override
  String toString() => 'E-Hentai 解析失败: $message';
}

enum EhGalleryCategory {
  misc(0x1, 'Misc'),
  doujinshi(0x2, 'Doujinshi'),
  manga(0x4, 'Manga'),
  artistCg(0x8, 'Artist CG'),
  gameCg(0x10, 'Game CG'),
  imageSet(0x20, 'Image Set'),
  cosplay(0x40, 'Cosplay'),
  asianPorn(0x80, 'Asian Porn'),
  nonH(0x100, 'Non-H'),
  western(0x200, 'Western'),
  privateCategory(0x400, 'Private'),
  unknown(0x800, 'Unknown');

  final int bit;

  final String displayName;

  const EhGalleryCategory(this.bit, this.displayName);
}

const int ehAllCategoryBits = 0x3ff;

const List<String> ehSimpleLanguages = <String>[
  'EN',
  'ZH',
  'ES',
  'KO',
  'RU',
  'FR',
  'PT',
  'TH',
  'DE',
  'IT',
  'VI',
  'PL',
  'HU',
  'NL',
];

const List<String> _langTagNames = <String>[
  'language:english',
  'language:chinese',
  'language:spanish',
  'language:korean',
  'language:russian',
  'language:french',
  'language:portuguese',
  'language:thai',
  'language:german',
  'language:italian',
  'language:vietnamese',
  'language:polish',
  'language:hungarian',
  'language:dutch',
];

final List<RegExp> _langTitlePatterns = <RegExp>[
  RegExp(r'[\(\[]eng(?:lish)?[\)\]]|英訳', caseSensitive: false),
  RegExp(
    r'[(（\[]ch(?:inese)?[)）\]]|[汉漢]化|中[国國][语語]|中文|中国翻訳',
    caseSensitive: false,
  ),
  RegExp(
    r'[\(\[]spanish[\)\]]|[\(\[]Español[\)\]]|スペイン翻訳',
    caseSensitive: false,
  ),
  RegExp(r'[\(\[]korean?[\)\]]|韓国翻訳', caseSensitive: false),
  RegExp(r'[\(\[]rus(?:sian)?[\)\]]|ロシア翻訳', caseSensitive: false),
  RegExp(r'[\(\[]fr(?:ench)?[\)\]]|フランス翻訳', caseSensitive: false),
  RegExp(r'[\(\[]portuguese|ポルトガル翻訳', caseSensitive: false),
  RegExp(r'[\(\[]thai(?: ภาษาไทย)?[\)\]]|แปลไทย|タイ翻訳', caseSensitive: false),
  RegExp(r'[\(\[]german[\)\]]|ドイツ翻訳', caseSensitive: false),
  RegExp(r'[\(\[]italiano?[\)\]]|イタリア翻訳', caseSensitive: false),
  RegExp(
    r'[\(\[]vietnamese(?: Tiếng Việt)?[\)\]]|ベトナム翻訳',
    caseSensitive: false,
  ),
  RegExp(r'[\(\[]polish[\)\]]|ポーランド翻訳', caseSensitive: false),
  RegExp(r'[\(\[]hun(?:garian)?[\)\]]|ハンガリー翻訳', caseSensitive: false),
  RegExp(r'[\(\[]dutch[\)\]]|オランダ翻訳', caseSensitive: false),
];

const Map<String, EhGalleryCategory> _categoryAliases =
    <String, EhGalleryCategory>{
      'misc': EhGalleryCategory.misc,
      'doujinshi': EhGalleryCategory.doujinshi,
      'manga': EhGalleryCategory.manga,
      'artistcg': EhGalleryCategory.artistCg,
      'artist cg sets': EhGalleryCategory.artistCg,
      'artist cg': EhGalleryCategory.artistCg,
      'gamecg': EhGalleryCategory.gameCg,
      'game cg sets': EhGalleryCategory.gameCg,
      'game cg': EhGalleryCategory.gameCg,
      'imageset': EhGalleryCategory.imageSet,
      'image sets': EhGalleryCategory.imageSet,
      'image set': EhGalleryCategory.imageSet,
      'cosplay': EhGalleryCategory.cosplay,
      'asianporn': EhGalleryCategory.asianPorn,
      'asian porn': EhGalleryCategory.asianPorn,
      'non-h': EhGalleryCategory.nonH,
      'western': EhGalleryCategory.western,
      'private': EhGalleryCategory.privateCategory,
      'unknown': EhGalleryCategory.unknown,
    };

EhGalleryCategory ehCategoryFromName(String name) {
  return _categoryAliases[name.trim().toLowerCase()] ??
      EhGalleryCategory.unknown;
}

class EhGalleryInfo {
  String gid;
  String token;
  String title;
  String titleJpn;
  String thumbUrl;
  String category;
  double rating;
  String uploaded;
  int pages;
  String uploader;
  List<String> tags;
  String simpleLanguage;
  int categoryIndex;

  EhGalleryInfo({
    this.gid = '',
    this.token = '',
    this.title = '',
    this.titleJpn = '',
    this.thumbUrl = '',
    this.category = '',
    this.rating = -1,
    this.uploaded = '',
    this.pages = 0,
    this.uploader = '',
    List<String>? tags,
    this.simpleLanguage = '',
    this.categoryIndex = 0x800,
  }) : tags = tags ?? <String>[];

  factory EhGalleryInfo.fromJson(Map<String, dynamic> json) {
    return EhGalleryInfo(
      gid: '${json['gid'] ?? ''}',
      token: '${json['token'] ?? ''}',
      title: '${json['title'] ?? ''}',
      titleJpn: '${json['titleJpn'] ?? ''}',
      thumbUrl: '${json['thumbUrl'] ?? ''}',
      category: '${json['category'] ?? ''}',
      rating: (json['rating'] as num?)?.toDouble() ?? -1,
      uploaded: '${json['uploaded'] ?? ''}',
      pages: (json['pages'] as num?)?.toInt() ?? 0,
      uploader: '${json['uploader'] ?? ''}',
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? <String>[],
      simpleLanguage: '${json['simpleLanguage'] ?? ''}',
      categoryIndex: (json['categoryIndex'] as num?)?.toInt() ?? 0x800,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'gid': gid,
    'token': token,
    'title': title,
    'titleJpn': titleJpn,
    'thumbUrl': thumbUrl,
    'category': category,
    'rating': rating,
    'uploaded': uploaded,
    'pages': pages,
    'uploader': uploader,
    'tags': tags,
    'simpleLanguage': simpleLanguage,
    'categoryIndex': categoryIndex,
  };

  void generateSimpleLanguage() {
    simpleLanguage = _langFromTags(tags) ?? _langFromTitle(title) ?? '';
  }

  static String? _langFromTags(List<String> tags) {
    for (final tag in tags) {
      final index = _langTagNames.indexOf(tag);
      if (index >= 0) return ehSimpleLanguages[index];
    }
    return null;
  }

  static String? _langFromTitle(String title) {
    for (var i = 0; i < _langTitlePatterns.length; i++) {
      if (_langTitlePatterns[i].hasMatch(title)) {
        return ehSimpleLanguages[i];
      }
    }
    return null;
  }
}

class EhGalleryComment {
  int id;
  String author;
  String content;
  int score;
  String postedAt;

  EhGalleryComment({
    this.id = 0,
    this.author = '',
    this.content = '',
    this.score = 0,
    this.postedAt = '',
  });

  factory EhGalleryComment.fromJson(Map<String, dynamic> json) {
    return EhGalleryComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      author: '${json['author'] ?? ''}',
      content: '${json['content'] ?? ''}',
      score: (json['score'] as num?)?.toInt() ?? 0,
      postedAt: '${json['postedAt'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'author': author,
    'content': content,
    'score': score,
    'postedAt': postedAt,
  };
}

class EhTagGroup {
  String namespace;
  List<String> tags;

  EhTagGroup({this.namespace = '', List<String>? tags})
    : tags = tags ?? <String>[];

  factory EhTagGroup.fromJson(Map<String, dynamic> json) {
    return EhTagGroup(
      namespace: '${json['namespace'] ?? ''}',
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? <String>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'namespace': namespace,
    'tags': tags,
  };
}

class EhGalleryDetail extends EhGalleryInfo {
  String coverUrl;
  int commentsCount;
  List<EhGalleryComment> comments;
  List<EhTagGroup> tagGroups;
  int torrentCount;
  bool visible;
  int previewPages;
  int previewPerPage;

  EhGalleryDetail({
    super.gid = '',
    super.token = '',
    super.title = '',
    super.titleJpn = '',
    super.thumbUrl = '',
    super.category = '',
    super.rating = -1,
    super.uploaded = '',
    super.pages = 0,
    super.uploader = '',
    super.tags,
    super.simpleLanguage = '',
    super.categoryIndex = 0x800,
    this.coverUrl = '',
    this.commentsCount = 0,
    List<EhGalleryComment>? comments,
    List<EhTagGroup>? tagGroups,
    this.torrentCount = 0,
    this.visible = true,
    this.previewPages = 0,
    this.previewPerPage = 0,
  }) : comments = comments ?? <EhGalleryComment>[],
       tagGroups = tagGroups ?? <EhTagGroup>[];

  factory EhGalleryDetail.fromJson(Map<String, dynamic> json) {
    final base = EhGalleryInfo.fromJson(json);
    return EhGalleryDetail(
      gid: base.gid,
      token: base.token,
      title: base.title,
      titleJpn: base.titleJpn,
      thumbUrl: base.thumbUrl,
      category: base.category,
      rating: base.rating,
      uploaded: base.uploaded,
      pages: base.pages,
      uploader: base.uploader,
      tags: base.tags,
      simpleLanguage: base.simpleLanguage,
      categoryIndex: base.categoryIndex,
      coverUrl: '${json['coverUrl'] ?? ''}',
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      comments:
          (json['comments'] as List?)
              ?.map(
                (e) => EhGalleryComment.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          <EhGalleryComment>[],
      tagGroups:
          (json['tagGroups'] as List?)
              ?.map(
                (e) => EhTagGroup.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          <EhTagGroup>[],
      torrentCount: (json['torrentCount'] as num?)?.toInt() ?? 0,
      visible: json['visible'] as bool? ?? true,
      previewPages: (json['previewPages'] as num?)?.toInt() ?? 0,
      previewPerPage: (json['previewPerPage'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'coverUrl': coverUrl,
    'commentsCount': commentsCount,
    'comments': comments.map((e) => e.toJson()).toList(),
    'tagGroups': tagGroups.map((e) => e.toJson()).toList(),
    'torrentCount': torrentCount,
    'visible': visible,
    'previewPages': previewPages,
    'previewPerPage': previewPerPage,
  };
}

class EhGalleryPageInfo {
  int pageCount;

  EhGalleryPageInfo({this.pageCount = 0});

  factory EhGalleryPageInfo.fromJson(Map<String, dynamic> json) {
    return EhGalleryPageInfo(
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'pageCount': pageCount};
}

class EhPageImage {
  String imageUrl;
  int? width;
  int? height;
  String? nextImgkey;
  String showKey;
  String skipHathKey;
  String originImageUrl;

  EhPageImage({
    this.imageUrl = '',
    this.width,
    this.height,
    this.nextImgkey,
    this.showKey = '',
    this.skipHathKey = '',
    this.originImageUrl = '',
  });

  factory EhPageImage.fromJson(Map<String, dynamic> json) {
    return EhPageImage(
      imageUrl: '${json['imageUrl'] ?? ''}',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      nextImgkey: json['nextImgkey'] == null ? null : '${json['nextImgkey']}',
      showKey: '${json['showKey'] ?? ''}',
      skipHathKey: '${json['skipHathKey'] ?? ''}',
      originImageUrl: '${json['originImageUrl'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'imageUrl': imageUrl,
    'width': width,
    'height': height,
    'nextImgkey': nextImgkey,
    'showKey': showKey,
    'skipHathKey': skipHathKey,
    'originImageUrl': originImageUrl,
  };
}
