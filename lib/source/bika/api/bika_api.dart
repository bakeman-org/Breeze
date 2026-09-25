import 'package:zephyr/network/http/wind_http.dart';
import 'package:zephyr/source/bika/api/bika_client.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';

T _bikaData<T>(
  dynamic response,
  T Function(dynamic) fromJsonT,
) {
  return BaseResponse<T>.fromJson(
    response as Map<String, dynamic>,
    fromJsonT,
  ).data;
}

Future<LoginResponse> bikaLogin(LoginPayload payload) async {
  final response = await bikaRequest(
    'auth/sign-in',
    method: BikaMethod.post,
    payload: payload.toJson(),
  );
  return _bikaData(response, (data) => LoginResponse.fromJson(data));
}

Future<CategoriesResponse> fetchBikaCategories() async {
  final response = await bikaRequest('categories') as Map<String, dynamic>;
  response['data']['categories'] = (response['data']['categories'] as List<dynamic>)
      .where((category) => category['isWeb'] != true)
      .toList();
  return _bikaData(response, (data) => CategoriesResponse.fromJson(data));
}

Future<ComicsResponse> fetchBikaComics(ComicsPayload payload) async {
  final response = await bikaRequest('comics', payload: payload.toJson());
  return _bikaData(response, (data) => ComicsResponse.fromJson(data));
}

Future<ComicDetailsResponse> fetchBikaComicDetails(String id) async {
  final response = await bikaRequest('comics/$id');
  return _bikaData(response, (data) => ComicDetailsResponse.fromJson(data));
}

Future<List<Chapter>> fetchBikaChapters(String id) async {
  final url = 'comics/$id/eps';
  final response = await bikaRequest(url, payload: {'page': 1});
  final eps = _bikaData(response, (data) => ChaptersResponse.fromJson(data)).eps;
  final chapters = List<Chapter>.from(eps.docs);
  final results = await Future.wait(
    List.generate(
      eps.pages - 1,
      (index) => bikaRequest(url, payload: {'page': index + 2}),
    ),
  );
  for (final result in results) {
    final data = _bikaData(result, (data) => ChaptersResponse.fromJson(data));
    chapters.addAll(data.eps.docs);
  }
  return chapters;
}

Future<RecommendComics> fetchBikaComicRecommendation(String id) async {
  final response = await bikaRequest('comics/$id/recommendation');
  return _bikaData(response, (data) => RecommendComics.fromJson(data));
}

Future<ActionResponse> likeBikaComic(String id) async {
  final response = await bikaRequest('comics/$id/like', method: BikaMethod.post);
  return _bikaData(response, (data) => ActionResponse.fromJson(data));
}

Future<ActionResponse> favoriteBikaComic(String id) async {
  final response = await bikaRequest(
    'comics/$id/favourite',
    method: BikaMethod.post,
  );
  return _bikaData(response, (data) => ActionResponse.fromJson(data));
}

Future<CommentsResponse> fetchBikaComicComments(CommentsPayload payload) async {
  final response = await bikaRequest(
    'comics/${payload.id}/comments',
    payload: {'page': payload.page},
  );
  return _bikaData(response, (data) => CommentsResponse.fromJson(data));
}

Future<ActionResponse> likeBikaComment(String id) async {
  final response = await bikaRequest(
    'comments/$id/like',
    method: BikaMethod.post,
  );
  return _bikaData(response, (data) => ActionResponse.fromJson(data));
}

Future<void> sendBikaComment(SendCommentPayload payload) async {
  await bikaRequest(
    'comics/${payload.id}/comments',
    method: BikaMethod.post,
    payload: payload.toJson(),
  );
}

Future<SubCommentsResponse> fetchBikaSubComments(
  SubCommentsPayload payload,
) async {
  final response = await bikaRequest(
    'comments/${payload.id}/childrens',
    payload: payload.toJson(),
  );
  return _bikaData(response, (data) => SubCommentsResponse.fromJson(data));
}

Future<void> sendBikaReply(SendCommentPayload payload) async {
  await bikaRequest(
    'comments/${payload.id}',
    method: BikaMethod.post,
    payload: payload.toJson(),
  );
}

Future<SearchResponse> searchBikaComics(SearchPayload payload) async {
  final response = await bikaRequest(
    'comics/advanced-search?page=${payload.page}',
    method: BikaMethod.post,
    payload: payload.toJson(),
  );
  return _bikaData(response, (data) => SearchResponse.fromJson(data));
}

Future<ComicsResponse> fetchBikaFavoriteComics(UserFavoritePayload payload) async {
  final response = await bikaRequest(
    'users/favourite',
    payload: payload.toJson(),
  );
  return _bikaData(response, (data) => ComicsResponse.fromJson(data));
}

Future<List<ChapterImage>> fetchBikaChapterImages(
  FetchChapterImagesPayload payload,
) async {
  final url = 'comics/${payload.id}/order/${payload.order}/pages';
  final response = await bikaRequest(url, payload: {'page': 1});
  final pages = _bikaData(
    response,
    (data) => FetchChapterImagesResponse.fromJson(data),
  ).pages;
  final images = List<ChapterImage>.from(pages.docs);
  final responses = await Future.wait(
    List.generate(
      pages.pages - 1,
      (index) => bikaRequest(url, payload: {'page': index + 2}),
    ),
  );
  for (final result in responses) {
    final data = _bikaData(
      result,
      (data) => FetchChapterImagesResponse.fromJson(data),
    );
    images.addAll(data.pages.docs);
  }
  return images;
}

Future<UserProfileResponse> fetchBikaUserProfile() async {
  final response = await bikaRequest('users/profile');
  return _bikaData(response, (data) => UserProfileResponse.fromJson(data));
}

Future<ComicRankResponse> fetchBikaComicRank(ComicRankPayload payload) async {
  final response = await bikaRequest('comics/leaderboard', payload: payload.toJson());
  return _bikaData(response, (data) => ComicRankResponse.fromJson(data));
}

Future<void> bikaPunchIn() async {
  await bikaRequest('users/punch-in', method: BikaMethod.post);
}

Future<KnightRankResponse> fetchBikaKnightRank() async {
  final response = await bikaRequest('comics/knight-leaderboard');
  return _bikaData(response, (data) => KnightRankResponse.fromJson(data));
}

Future<RandomComicsResponse> fetchBikaRandomComics() async {
  final response = await bikaRequest('comics/random');
  return _bikaData(response, (data) => RandomComicsResponse.fromJson(data));
}

Future<PersonalCommentsResponse> fetchBikaPersonalComments(int page) async {
  final response = await bikaRequest(
    'users/my-comments',
    payload: {'page': page},
  );
  return _bikaData(response, (data) => PersonalCommentsResponse.fromJson(data));
}

Map<String, dynamic>? _hotSearchWordsCache;

Future<HotSearchWordsResponse> fetchBikaHotSearchWords() async {
  final cached = _hotSearchWordsCache;
  final response =
      cached ?? await bikaRequest('keywords') as Map<String, dynamic>;
  _hotSearchWordsCache ??= response;
  return _bikaData(response, (data) => HotSearchWordsResponse.fromJson(data));
}

Future<void> updateBikaAvatar(String base64) async {
  await bikaRequest(
    'users/avatar',
    method: BikaMethod.put,
    payload: {'avatar': 'data:image/jpeg;base64,$base64'},
  );
}

Future<void> updateBikaProfile(String slogan) async {
  await bikaRequest(
    'users/profile',
    method: BikaMethod.put,
    payload: {'slogan': slogan},
  );
}

Future<void> updateBikaPassword(UpdatePasswordPayload payload) async {
  await bikaRequest(
    'users/password',
    method: BikaMethod.put,
    payload: payload.toJson(),
  );
}

Future<void> bikaRegister(RegisterPayload payload) async {
  await bikaRequest(
    'auth/register',
    method: BikaMethod.post,
    payload: payload.toJson(),
  );
}

Future<ExtraRecommendComicIdsResponse> fetchExtraRecommendComicIds(
  ExtraRecommendComicPayload payload,
) async {
  const maxRetries = 3;
  Object? lastError;
  for (var i = 0; i < maxRetries; i++) {
    try {
      final response = await WindHttp().fetch(
        'https://macapi1.com/picacomic/rec/${payload.id}',
        query: {'limit': payload.limit},
      );
      if (!response.ok) {
        throw BikaApiException('请求失败', statusCode: response.status);
      }
      return ExtraRecommendComicIdsResponse.fromJson(
        response.json as Map<String, dynamic>,
      );
    } catch (e) {
      lastError = e;
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(seconds: 2 * i));
      }
    }
  }
  throw BikaApiException('获取推荐失败: $lastError');
}

Future<void> postReadTrack(ReadTrackPayload payload) async {
  const maxRetries = 3;
  for (var i = 0; i < maxRetries; i++) {
    try {
      await WindHttp().fetch(
        'https://macapi1.com/picacomic/rec/track',
        method: 'POST',
        body: payload.toJson(),
      );
      return;
    } catch (e) {
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(seconds: 2 * i));
      }
    }
  }
}
