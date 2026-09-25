// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i70;

import 'package:auto_route/auto_route.dart' as _i60;
import 'package:collection/collection.dart' as _i64;
import 'package:flutter/foundation.dart' as _i66;
import 'package:flutter/material.dart' as _i61;
import 'package:material_ui/material_ui.dart' as _i62;
import 'package:zephyr/cubit/string_select.dart' as _i68;
import 'package:zephyr/debug/coreml_upscale_debug_page.dart' as _i25;
import 'package:zephyr/debug/qjs_runtime_debug_page.dart' as _i49;
import 'package:zephyr/debug/show_color.dart' as _i54;
import 'package:zephyr/page/about/view/about_page.dart' as _i1;
import 'package:zephyr/page/app_bootstrap_page.dart' as _i3;
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart' as _i15;
import 'package:zephyr/page/change_log_page.dart' as _i18;
import 'package:zephyr/page/comic_follow/view/comic_follow_page.dart' as _i19;
import 'package:zephyr/page/comic_info/view/comic_info.dart' as _i20;
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart' as _i65;
import 'package:zephyr/page/comic_list/view/comic_list_page.dart' as _i21;
import 'package:zephyr/page/comic_read/type/chapter_extern.dart' as _i67;
import 'package:zephyr/page/comic_read/view/comic_read.dart' as _i22;
import 'package:zephyr/page/comments/view/comments.dart' as _i23;
import 'package:zephyr/page/comments/view/plugin_comments_scaffold.dart'
    as _i45;
import 'package:zephyr/page/discover/view/discover_page.dart' as _i28;
import 'package:zephyr/page/donwload_task/view/download_task.dart' as _i30;
import 'package:zephyr/page/download/models/unified_comic_download.dart'
    as _i69;
import 'package:zephyr/page/download/view/download.dart' as _i29;
import 'package:zephyr/page/font_setting/view/font_setting_page.dart' as _i39;
import 'package:zephyr/page/login_page.dart' as _i42;
import 'package:zephyr/page/more/view/more.dart' as _i43;
import 'package:zephyr/page/navigation_bar.dart' as _i44;
import 'package:zephyr/page/plugin_function/view/plugin_function_page.dart'
    as _i46;
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart'
    as _i47;
import 'package:zephyr/page/plugin_store/view/plugin_store_page.dart' as _i48;
import 'package:zephyr/page/search/cubit/search_cubit.dart' as _i72;
import 'package:zephyr/page/search/view/search_page.dart' as _i52;
import 'package:zephyr/page/search_aggregate/view/search_aggregate_result_page.dart'
    as _i51;
import 'package:zephyr/page/search_result/bloc/search_bloc.dart' as _i71;
import 'package:zephyr/page/search_result/search_result.dart' as _i73;
import 'package:zephyr/page/search_result/view/search_result_page.dart' as _i53;
import 'package:zephyr/page/setting/bookshelf/bookshelf_setting_page.dart'
    as _i16;
import 'package:zephyr/page/setting/cache/cache_setting_page.dart' as _i17;
import 'package:zephyr/page/setting/data_backup/data_backup_page.dart' as _i26;
import 'package:zephyr/page/setting/global/app_behavior_setting_page.dart'
    as _i2;
import 'package:zephyr/page/setting/global/appearance_setting_page.dart' as _i4;
import 'package:zephyr/page/setting/global/content_network_setting_page.dart'
    as _i24;
import 'package:zephyr/page/setting/global/debug_setting_page.dart' as _i27;
import 'package:zephyr/page/setting/global/global_setting.dart' as _i41;
import 'package:zephyr/page/setting/global/storage_setting_page.dart' as _i55;
import 'package:zephyr/page/setting/global/sync_setting_page.dart' as _i56;
import 'package:zephyr/page/setting/real_sr/real_sr_setting_page.dart' as _i50;
import 'package:zephyr/page/theme_color/view/theme_color_page.dart' as _i57;
import 'package:zephyr/page/webdav_sync/view/webdav_sync_page.dart' as _i58;
import 'package:zephyr/page/webview_page.dart' as _i59;
import 'package:zephyr/source/bika/view/bika_comments_page.dart' as _i5;
import 'package:zephyr/source/bika/view/bika_detail_page.dart' as _i6;
import 'package:zephyr/source/bika/view/bika_favorites_page.dart' as _i7;
import 'package:zephyr/source/bika/view/bika_home_page.dart' as _i8;
import 'package:zephyr/source/bika/view/bika_login_page.dart' as _i9;
import 'package:zephyr/source/bika/view/bika_mine_page.dart' as _i10;
import 'package:zephyr/source/bika/view/bika_my_comments_page.dart' as _i11;
import 'package:zephyr/source/bika/view/bika_rank_page.dart' as _i12;
import 'package:zephyr/source/bika/view/bika_search_page.dart' as _i13;
import 'package:zephyr/source/bika/view/bika_settings_page.dart' as _i14;
import 'package:zephyr/source/eh/view/eh_comments_page.dart' as _i31;
import 'package:zephyr/source/eh/view/eh_detail_page.dart' as _i32;
import 'package:zephyr/source/eh/view/eh_favorites_page.dart' as _i33;
import 'package:zephyr/source/eh/view/eh_home_page.dart' as _i34;
import 'package:zephyr/source/eh/view/eh_login_page.dart' as _i35;
import 'package:zephyr/source/eh/view/eh_popular_page.dart' as _i36;
import 'package:zephyr/source/eh/view/eh_search_page.dart' as _i37;
import 'package:zephyr/source/eh/view/eh_settings_page.dart' as _i38;
import 'package:zephyr/type/enum.dart' as _i63;
import 'package:zephyr/widgets/full_screen_image_view.dart' as _i40;

/// generated route for
/// [_i1.AboutPage]
class AboutRoute extends _i60.PageRouteInfo<void> {
  const AboutRoute({List<_i60.PageRouteInfo>? children})
    : super(AboutRoute.name, initialChildren: children);

  static const String name = 'AboutRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutPage();
    },
  );
}

/// generated route for
/// [_i2.AppBehaviorSettingPage]
class AppBehaviorSettingRoute extends _i60.PageRouteInfo<void> {
  const AppBehaviorSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(AppBehaviorSettingRoute.name, initialChildren: children);

  static const String name = 'AppBehaviorSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i2.AppBehaviorSettingPage();
    },
  );
}

/// generated route for
/// [_i3.AppBootstrapPage]
class AppBootstrapRoute extends _i60.PageRouteInfo<void> {
  const AppBootstrapRoute({List<_i60.PageRouteInfo>? children})
    : super(AppBootstrapRoute.name, initialChildren: children);

  static const String name = 'AppBootstrapRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i3.AppBootstrapPage();
    },
  );
}

/// generated route for
/// [_i4.AppearanceSettingPage]
class AppearanceSettingRoute extends _i60.PageRouteInfo<void> {
  const AppearanceSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(AppearanceSettingRoute.name, initialChildren: children);

  static const String name = 'AppearanceSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i4.AppearanceSettingPage();
    },
  );
}

/// generated route for
/// [_i5.BikaCommentsPage]
class BikaCommentsRoute extends _i60.PageRouteInfo<BikaCommentsRouteArgs> {
  BikaCommentsRoute({
    _i61.Key? key,
    required String comicId,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         BikaCommentsRoute.name,
         args: BikaCommentsRouteArgs(key: key, comicId: comicId),
         initialChildren: children,
       );

  static const String name = 'BikaCommentsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<BikaCommentsRouteArgs>();
      return _i5.BikaCommentsPage(key: args.key, comicId: args.comicId);
    },
  );
}

class BikaCommentsRouteArgs {
  const BikaCommentsRouteArgs({this.key, required this.comicId});

  final _i61.Key? key;

  final String comicId;

  @override
  String toString() {
    return 'BikaCommentsRouteArgs{key: $key, comicId: $comicId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BikaCommentsRouteArgs) return false;
    return key == other.key && comicId == other.comicId;
  }

  @override
  int get hashCode => key.hashCode ^ comicId.hashCode;
}

/// generated route for
/// [_i6.BikaDetailPage]
class BikaDetailRoute extends _i60.PageRouteInfo<BikaDetailRouteArgs> {
  BikaDetailRoute({
    _i61.Key? key,
    required String comicId,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         BikaDetailRoute.name,
         args: BikaDetailRouteArgs(key: key, comicId: comicId),
         initialChildren: children,
       );

  static const String name = 'BikaDetailRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<BikaDetailRouteArgs>();
      return _i6.BikaDetailPage(key: args.key, comicId: args.comicId);
    },
  );
}

class BikaDetailRouteArgs {
  const BikaDetailRouteArgs({this.key, required this.comicId});

  final _i61.Key? key;

  final String comicId;

  @override
  String toString() {
    return 'BikaDetailRouteArgs{key: $key, comicId: $comicId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BikaDetailRouteArgs) return false;
    return key == other.key && comicId == other.comicId;
  }

  @override
  int get hashCode => key.hashCode ^ comicId.hashCode;
}

/// generated route for
/// [_i7.BikaFavoritesPage]
class BikaFavoritesRoute extends _i60.PageRouteInfo<void> {
  const BikaFavoritesRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaFavoritesRoute.name, initialChildren: children);

  static const String name = 'BikaFavoritesRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i7.BikaFavoritesPage();
    },
  );
}

/// generated route for
/// [_i8.BikaHomePage]
class BikaHomeRoute extends _i60.PageRouteInfo<void> {
  const BikaHomeRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaHomeRoute.name, initialChildren: children);

  static const String name = 'BikaHomeRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i8.BikaHomePage();
    },
  );
}

/// generated route for
/// [_i9.BikaLoginPage]
class BikaLoginRoute extends _i60.PageRouteInfo<void> {
  const BikaLoginRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaLoginRoute.name, initialChildren: children);

  static const String name = 'BikaLoginRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i9.BikaLoginPage();
    },
  );
}

/// generated route for
/// [_i10.BikaMinePage]
class BikaMineRoute extends _i60.PageRouteInfo<void> {
  const BikaMineRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaMineRoute.name, initialChildren: children);

  static const String name = 'BikaMineRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i10.BikaMinePage();
    },
  );
}

/// generated route for
/// [_i11.BikaMyCommentsPage]
class BikaMyCommentsRoute extends _i60.PageRouteInfo<void> {
  const BikaMyCommentsRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaMyCommentsRoute.name, initialChildren: children);

  static const String name = 'BikaMyCommentsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i11.BikaMyCommentsPage();
    },
  );
}

/// generated route for
/// [_i12.BikaRankPage]
class BikaRankRoute extends _i60.PageRouteInfo<void> {
  const BikaRankRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaRankRoute.name, initialChildren: children);

  static const String name = 'BikaRankRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i12.BikaRankPage();
    },
  );
}

/// generated route for
/// [_i13.BikaSearchPage]
class BikaSearchRoute extends _i60.PageRouteInfo<void> {
  const BikaSearchRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaSearchRoute.name, initialChildren: children);

  static const String name = 'BikaSearchRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i13.BikaSearchPage();
    },
  );
}

/// generated route for
/// [_i14.BikaSettingsPage]
class BikaSettingsRoute extends _i60.PageRouteInfo<void> {
  const BikaSettingsRoute({List<_i60.PageRouteInfo>? children})
    : super(BikaSettingsRoute.name, initialChildren: children);

  static const String name = 'BikaSettingsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i14.BikaSettingsPage();
    },
  );
}

/// generated route for
/// [_i15.BookshelfPage]
class BookshelfRoute extends _i60.PageRouteInfo<void> {
  const BookshelfRoute({List<_i60.PageRouteInfo>? children})
    : super(BookshelfRoute.name, initialChildren: children);

  static const String name = 'BookshelfRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i15.BookshelfPage();
    },
  );
}

/// generated route for
/// [_i16.BookshelfSettingPage]
class BookshelfSettingRoute extends _i60.PageRouteInfo<void> {
  const BookshelfSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(BookshelfSettingRoute.name, initialChildren: children);

  static const String name = 'BookshelfSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i16.BookshelfSettingPage();
    },
  );
}

/// generated route for
/// [_i17.CacheSettingPage]
class CacheSettingRoute extends _i60.PageRouteInfo<void> {
  const CacheSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(CacheSettingRoute.name, initialChildren: children);

  static const String name = 'CacheSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i17.CacheSettingPage();
    },
  );
}

/// generated route for
/// [_i18.ChangelogPage]
class ChangelogRoute extends _i60.PageRouteInfo<void> {
  const ChangelogRoute({List<_i60.PageRouteInfo>? children})
    : super(ChangelogRoute.name, initialChildren: children);

  static const String name = 'ChangelogRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i18.ChangelogPage();
    },
  );
}

/// generated route for
/// [_i19.ComicFollowPage]
class ComicFollowRoute extends _i60.PageRouteInfo<void> {
  const ComicFollowRoute({List<_i60.PageRouteInfo>? children})
    : super(ComicFollowRoute.name, initialChildren: children);

  static const String name = 'ComicFollowRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i19.ComicFollowPage();
    },
  );
}

/// generated route for
/// [_i20.ComicInfoPage]
class ComicInfoRoute extends _i60.PageRouteInfo<ComicInfoRouteArgs> {
  ComicInfoRoute({
    _i62.Key? key,
    required String comicId,
    required String from,
    required _i63.ComicEntryType type,
    Map<String, dynamic>? extern,
    String? collectionTargetId,
    String? collectionTargetName,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         ComicInfoRoute.name,
         args: ComicInfoRouteArgs(
           key: key,
           comicId: comicId,
           from: from,
           type: type,
           extern: extern,
           collectionTargetId: collectionTargetId,
           collectionTargetName: collectionTargetName,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicInfoRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicInfoRouteArgs>();
      return _i20.ComicInfoPage(
        key: args.key,
        comicId: args.comicId,
        from: args.from,
        type: args.type,
        extern: args.extern,
        collectionTargetId: args.collectionTargetId,
        collectionTargetName: args.collectionTargetName,
      );
    },
  );
}

class ComicInfoRouteArgs {
  const ComicInfoRouteArgs({
    this.key,
    required this.comicId,
    required this.from,
    required this.type,
    this.extern,
    this.collectionTargetId,
    this.collectionTargetName,
  });

  final _i62.Key? key;

  final String comicId;

  final String from;

  final _i63.ComicEntryType type;

  final Map<String, dynamic>? extern;

  final String? collectionTargetId;

  final String? collectionTargetName;

  @override
  String toString() {
    return 'ComicInfoRouteArgs{key: $key, comicId: $comicId, from: $from, type: $type, extern: $extern, collectionTargetId: $collectionTargetId, collectionTargetName: $collectionTargetName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicInfoRouteArgs) return false;
    return key == other.key &&
        comicId == other.comicId &&
        from == other.from &&
        type == other.type &&
        const _i64.MapEquality<String, dynamic>().equals(
          extern,
          other.extern,
        ) &&
        collectionTargetId == other.collectionTargetId &&
        collectionTargetName == other.collectionTargetName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      comicId.hashCode ^
      from.hashCode ^
      type.hashCode ^
      const _i64.MapEquality<String, dynamic>().hash(extern) ^
      collectionTargetId.hashCode ^
      collectionTargetName.hashCode;
}

/// generated route for
/// [_i21.ComicListPage]
class ComicListRoute extends _i60.PageRouteInfo<ComicListRouteArgs> {
  ComicListRoute({
    _i62.Key? key,
    String? title,
    _i65.ComicListScene? scene,
    String? sceneSource,
    String? sceneBundleFnPath,
    String? sceneBundleFnPathFallback,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         ComicListRoute.name,
         args: ComicListRouteArgs(
           key: key,
           title: title,
           scene: scene,
           sceneSource: sceneSource,
           sceneBundleFnPath: sceneBundleFnPath,
           sceneBundleFnPathFallback: sceneBundleFnPathFallback,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicListRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicListRouteArgs>(
        orElse: () => const ComicListRouteArgs(),
      );
      return _i21.ComicListPage(
        key: args.key,
        title: args.title,
        scene: args.scene,
        sceneSource: args.sceneSource,
        sceneBundleFnPath: args.sceneBundleFnPath,
        sceneBundleFnPathFallback: args.sceneBundleFnPathFallback,
      );
    },
  );
}

class ComicListRouteArgs {
  const ComicListRouteArgs({
    this.key,
    this.title,
    this.scene,
    this.sceneSource,
    this.sceneBundleFnPath,
    this.sceneBundleFnPathFallback,
  });

  final _i62.Key? key;

  final String? title;

  final _i65.ComicListScene? scene;

  final String? sceneSource;

  final String? sceneBundleFnPath;

  final String? sceneBundleFnPathFallback;

  @override
  String toString() {
    return 'ComicListRouteArgs{key: $key, title: $title, scene: $scene, sceneSource: $sceneSource, sceneBundleFnPath: $sceneBundleFnPath, sceneBundleFnPathFallback: $sceneBundleFnPathFallback}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicListRouteArgs) return false;
    return key == other.key &&
        title == other.title &&
        scene == other.scene &&
        sceneSource == other.sceneSource &&
        sceneBundleFnPath == other.sceneBundleFnPath &&
        sceneBundleFnPathFallback == other.sceneBundleFnPathFallback;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      title.hashCode ^
      scene.hashCode ^
      sceneSource.hashCode ^
      sceneBundleFnPath.hashCode ^
      sceneBundleFnPathFallback.hashCode;
}

/// generated route for
/// [_i22.ComicReadPage]
class ComicReadRoute extends _i60.PageRouteInfo<ComicReadRouteArgs> {
  ComicReadRoute({
    _i66.Key? key,
    required String comicId,
    required int order,
    String chapterId = '',
    String requestId = '',
    String storageChapterId = '',
    String logicalKey = '',
    _i67.ChapterExtern chapterExtern = const {},
    required int epsNumber,
    required String from,
    required _i68.StringSelectCubit stringSelectCubit,
    required _i63.ComicEntryType type,
    required dynamic comicInfo,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         ComicReadRoute.name,
         args: ComicReadRouteArgs(
           key: key,
           comicId: comicId,
           order: order,
           chapterId: chapterId,
           requestId: requestId,
           storageChapterId: storageChapterId,
           logicalKey: logicalKey,
           chapterExtern: chapterExtern,
           epsNumber: epsNumber,
           from: from,
           stringSelectCubit: stringSelectCubit,
           type: type,
           comicInfo: comicInfo,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicReadRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicReadRouteArgs>();
      return _i22.ComicReadPage(
        key: args.key,
        comicId: args.comicId,
        order: args.order,
        chapterId: args.chapterId,
        requestId: args.requestId,
        storageChapterId: args.storageChapterId,
        logicalKey: args.logicalKey,
        chapterExtern: args.chapterExtern,
        epsNumber: args.epsNumber,
        from: args.from,
        stringSelectCubit: args.stringSelectCubit,
        type: args.type,
        comicInfo: args.comicInfo,
      );
    },
  );
}

class ComicReadRouteArgs {
  const ComicReadRouteArgs({
    this.key,
    required this.comicId,
    required this.order,
    this.chapterId = '',
    this.requestId = '',
    this.storageChapterId = '',
    this.logicalKey = '',
    this.chapterExtern = const {},
    required this.epsNumber,
    required this.from,
    required this.stringSelectCubit,
    required this.type,
    required this.comicInfo,
  });

  final _i66.Key? key;

  final String comicId;

  final int order;

  final String chapterId;

  final String requestId;

  final String storageChapterId;

  final String logicalKey;

  final _i67.ChapterExtern chapterExtern;

  final int epsNumber;

  final String from;

  final _i68.StringSelectCubit stringSelectCubit;

  final _i63.ComicEntryType type;

  final dynamic comicInfo;

  @override
  String toString() {
    return 'ComicReadRouteArgs{key: $key, comicId: $comicId, order: $order, chapterId: $chapterId, requestId: $requestId, storageChapterId: $storageChapterId, logicalKey: $logicalKey, chapterExtern: $chapterExtern, epsNumber: $epsNumber, from: $from, stringSelectCubit: $stringSelectCubit, type: $type, comicInfo: $comicInfo}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicReadRouteArgs) return false;
    return key == other.key &&
        comicId == other.comicId &&
        order == other.order &&
        chapterId == other.chapterId &&
        requestId == other.requestId &&
        storageChapterId == other.storageChapterId &&
        logicalKey == other.logicalKey &&
        chapterExtern == other.chapterExtern &&
        epsNumber == other.epsNumber &&
        from == other.from &&
        stringSelectCubit == other.stringSelectCubit &&
        type == other.type &&
        comicInfo == other.comicInfo;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      comicId.hashCode ^
      order.hashCode ^
      chapterId.hashCode ^
      requestId.hashCode ^
      storageChapterId.hashCode ^
      logicalKey.hashCode ^
      chapterExtern.hashCode ^
      epsNumber.hashCode ^
      from.hashCode ^
      stringSelectCubit.hashCode ^
      type.hashCode ^
      comicInfo.hashCode;
}

/// generated route for
/// [_i23.CommentsPage]
class CommentsRoute extends _i60.PageRouteInfo<CommentsRouteArgs> {
  CommentsRoute({
    _i62.Key? key,
    required String comicId,
    required String comicTitle,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         CommentsRoute.name,
         args: CommentsRouteArgs(
           key: key,
           comicId: comicId,
           comicTitle: comicTitle,
         ),
         initialChildren: children,
       );

  static const String name = 'CommentsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CommentsRouteArgs>();
      return _i23.CommentsPage(
        key: args.key,
        comicId: args.comicId,
        comicTitle: args.comicTitle,
      );
    },
  );
}

class CommentsRouteArgs {
  const CommentsRouteArgs({
    this.key,
    required this.comicId,
    required this.comicTitle,
  });

  final _i62.Key? key;

  final String comicId;

  final String comicTitle;

  @override
  String toString() {
    return 'CommentsRouteArgs{key: $key, comicId: $comicId, comicTitle: $comicTitle}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CommentsRouteArgs) return false;
    return key == other.key &&
        comicId == other.comicId &&
        comicTitle == other.comicTitle;
  }

  @override
  int get hashCode => key.hashCode ^ comicId.hashCode ^ comicTitle.hashCode;
}

/// generated route for
/// [_i24.ContentNetworkSettingPage]
class ContentNetworkSettingRoute extends _i60.PageRouteInfo<void> {
  const ContentNetworkSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(ContentNetworkSettingRoute.name, initialChildren: children);

  static const String name = 'ContentNetworkSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i24.ContentNetworkSettingPage();
    },
  );
}

/// generated route for
/// [_i25.CoreMLUpscaleDebugPage]
class CoreMLUpscaleDebugRoute extends _i60.PageRouteInfo<void> {
  const CoreMLUpscaleDebugRoute({List<_i60.PageRouteInfo>? children})
    : super(CoreMLUpscaleDebugRoute.name, initialChildren: children);

  static const String name = 'CoreMLUpscaleDebugRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i25.CoreMLUpscaleDebugPage();
    },
  );
}

/// generated route for
/// [_i26.DataBackupPage]
class DataBackupRoute extends _i60.PageRouteInfo<void> {
  const DataBackupRoute({List<_i60.PageRouteInfo>? children})
    : super(DataBackupRoute.name, initialChildren: children);

  static const String name = 'DataBackupRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i26.DataBackupPage();
    },
  );
}

/// generated route for
/// [_i27.DebugSettingPage]
class DebugSettingRoute extends _i60.PageRouteInfo<void> {
  const DebugSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(DebugSettingRoute.name, initialChildren: children);

  static const String name = 'DebugSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i27.DebugSettingPage();
    },
  );
}

/// generated route for
/// [_i28.DiscoverPage]
class DiscoverRoute extends _i60.PageRouteInfo<void> {
  const DiscoverRoute({List<_i60.PageRouteInfo>? children})
    : super(DiscoverRoute.name, initialChildren: children);

  static const String name = 'DiscoverRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i28.DiscoverPage();
    },
  );
}

/// generated route for
/// [_i29.DownloadPage]
class DownloadRoute extends _i60.PageRouteInfo<DownloadRouteArgs> {
  DownloadRoute({
    _i62.Key? key,
    required _i69.UnifiedComicDownloadInfo downloadInfo,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         DownloadRoute.name,
         args: DownloadRouteArgs(key: key, downloadInfo: downloadInfo),
         initialChildren: children,
       );

  static const String name = 'DownloadRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DownloadRouteArgs>();
      return _i29.DownloadPage(key: args.key, downloadInfo: args.downloadInfo);
    },
  );
}

class DownloadRouteArgs {
  const DownloadRouteArgs({this.key, required this.downloadInfo});

  final _i62.Key? key;

  final _i69.UnifiedComicDownloadInfo downloadInfo;

  @override
  String toString() {
    return 'DownloadRouteArgs{key: $key, downloadInfo: $downloadInfo}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DownloadRouteArgs) return false;
    return key == other.key && downloadInfo == other.downloadInfo;
  }

  @override
  int get hashCode => key.hashCode ^ downloadInfo.hashCode;
}

/// generated route for
/// [_i30.DownloadTaskPage]
class DownloadTaskRoute extends _i60.PageRouteInfo<void> {
  const DownloadTaskRoute({List<_i60.PageRouteInfo>? children})
    : super(DownloadTaskRoute.name, initialChildren: children);

  static const String name = 'DownloadTaskRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i30.DownloadTaskPage();
    },
  );
}

/// generated route for
/// [_i31.EhCommentsPage]
class EhCommentsRoute extends _i60.PageRouteInfo<EhCommentsRouteArgs> {
  EhCommentsRoute({
    _i61.Key? key,
    required String gid,
    required String token,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         EhCommentsRoute.name,
         args: EhCommentsRouteArgs(key: key, gid: gid, token: token),
         initialChildren: children,
       );

  static const String name = 'EhCommentsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EhCommentsRouteArgs>();
      return _i31.EhCommentsPage(
        key: args.key,
        gid: args.gid,
        token: args.token,
      );
    },
  );
}

class EhCommentsRouteArgs {
  const EhCommentsRouteArgs({this.key, required this.gid, required this.token});

  final _i61.Key? key;

  final String gid;

  final String token;

  @override
  String toString() {
    return 'EhCommentsRouteArgs{key: $key, gid: $gid, token: $token}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EhCommentsRouteArgs) return false;
    return key == other.key && gid == other.gid && token == other.token;
  }

  @override
  int get hashCode => key.hashCode ^ gid.hashCode ^ token.hashCode;
}

/// generated route for
/// [_i32.EhDetailPage]
class EhDetailRoute extends _i60.PageRouteInfo<EhDetailRouteArgs> {
  EhDetailRoute({
    _i61.Key? key,
    required String gid,
    required String token,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         EhDetailRoute.name,
         args: EhDetailRouteArgs(key: key, gid: gid, token: token),
         initialChildren: children,
       );

  static const String name = 'EhDetailRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EhDetailRouteArgs>();
      return _i32.EhDetailPage(key: args.key, gid: args.gid, token: args.token);
    },
  );
}

class EhDetailRouteArgs {
  const EhDetailRouteArgs({this.key, required this.gid, required this.token});

  final _i61.Key? key;

  final String gid;

  final String token;

  @override
  String toString() {
    return 'EhDetailRouteArgs{key: $key, gid: $gid, token: $token}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EhDetailRouteArgs) return false;
    return key == other.key && gid == other.gid && token == other.token;
  }

  @override
  int get hashCode => key.hashCode ^ gid.hashCode ^ token.hashCode;
}

/// generated route for
/// [_i33.EhFavoritesPage]
class EhFavoritesRoute extends _i60.PageRouteInfo<void> {
  const EhFavoritesRoute({List<_i60.PageRouteInfo>? children})
    : super(EhFavoritesRoute.name, initialChildren: children);

  static const String name = 'EhFavoritesRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i33.EhFavoritesPage();
    },
  );
}

/// generated route for
/// [_i34.EhHomePage]
class EhHomeRoute extends _i60.PageRouteInfo<void> {
  const EhHomeRoute({List<_i60.PageRouteInfo>? children})
    : super(EhHomeRoute.name, initialChildren: children);

  static const String name = 'EhHomeRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i34.EhHomePage();
    },
  );
}

/// generated route for
/// [_i35.EhLoginPage]
class EhLoginRoute extends _i60.PageRouteInfo<void> {
  const EhLoginRoute({List<_i60.PageRouteInfo>? children})
    : super(EhLoginRoute.name, initialChildren: children);

  static const String name = 'EhLoginRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i35.EhLoginPage();
    },
  );
}

/// generated route for
/// [_i36.EhPopularPage]
class EhPopularRoute extends _i60.PageRouteInfo<void> {
  const EhPopularRoute({List<_i60.PageRouteInfo>? children})
    : super(EhPopularRoute.name, initialChildren: children);

  static const String name = 'EhPopularRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i36.EhPopularPage();
    },
  );
}

/// generated route for
/// [_i37.EhSearchPage]
class EhSearchRoute extends _i60.PageRouteInfo<void> {
  const EhSearchRoute({List<_i60.PageRouteInfo>? children})
    : super(EhSearchRoute.name, initialChildren: children);

  static const String name = 'EhSearchRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i37.EhSearchPage();
    },
  );
}

/// generated route for
/// [_i38.EhSettingsPage]
class EhSettingsRoute extends _i60.PageRouteInfo<void> {
  const EhSettingsRoute({List<_i60.PageRouteInfo>? children})
    : super(EhSettingsRoute.name, initialChildren: children);

  static const String name = 'EhSettingsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i38.EhSettingsPage();
    },
  );
}

/// generated route for
/// [_i39.FontSettingPage]
class FontSettingRoute extends _i60.PageRouteInfo<void> {
  const FontSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(FontSettingRoute.name, initialChildren: children);

  static const String name = 'FontSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i39.FontSettingPage();
    },
  );
}

/// generated route for
/// [_i40.FullScreenImagePage]
class FullRouteImageRoute extends _i60.PageRouteInfo<FullRouteImageRouteArgs> {
  FullRouteImageRoute({
    _i62.Key? key,
    required String imagePath,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         FullRouteImageRoute.name,
         args: FullRouteImageRouteArgs(key: key, imagePath: imagePath),
         initialChildren: children,
       );

  static const String name = 'FullRouteImageRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FullRouteImageRouteArgs>();
      return _i40.FullScreenImagePage(key: args.key, imagePath: args.imagePath);
    },
  );
}

class FullRouteImageRouteArgs {
  const FullRouteImageRouteArgs({this.key, required this.imagePath});

  final _i62.Key? key;

  final String imagePath;

  @override
  String toString() {
    return 'FullRouteImageRouteArgs{key: $key, imagePath: $imagePath}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FullRouteImageRouteArgs) return false;
    return key == other.key && imagePath == other.imagePath;
  }

  @override
  int get hashCode => key.hashCode ^ imagePath.hashCode;
}

/// generated route for
/// [_i41.GlobalSettingPage]
class GlobalSettingRoute extends _i60.PageRouteInfo<void> {
  const GlobalSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(GlobalSettingRoute.name, initialChildren: children);

  static const String name = 'GlobalSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i41.GlobalSettingPage();
    },
  );
}

/// generated route for
/// [_i42.LoginPage]
class LoginRoute extends _i60.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    _i62.Key? key,
    String? from,
    Map<String, dynamic>? loginScheme,
    Map<String, dynamic>? loginData,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(
           key: key,
           from: from,
           loginScheme: loginScheme,
           loginData: loginData,
         ),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return _i42.LoginPage(
        key: args.key,
        from: args.from,
        loginScheme: args.loginScheme,
        loginData: args.loginData,
      );
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.from, this.loginScheme, this.loginData});

  final _i62.Key? key;

  final String? from;

  final Map<String, dynamic>? loginScheme;

  final Map<String, dynamic>? loginData;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, from: $from, loginScheme: $loginScheme, loginData: $loginData}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        const _i64.MapEquality<String, dynamic>().equals(
          loginScheme,
          other.loginScheme,
        ) &&
        const _i64.MapEquality<String, dynamic>().equals(
          loginData,
          other.loginData,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      from.hashCode ^
      const _i64.MapEquality<String, dynamic>().hash(loginScheme) ^
      const _i64.MapEquality<String, dynamic>().hash(loginData);
}

/// generated route for
/// [_i43.MorePage]
class MoreRoute extends _i60.PageRouteInfo<void> {
  const MoreRoute({List<_i60.PageRouteInfo>? children})
    : super(MoreRoute.name, initialChildren: children);

  static const String name = 'MoreRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i43.MorePage();
    },
  );
}

/// generated route for
/// [_i44.NavigationBar]
class NavigationBar extends _i60.PageRouteInfo<void> {
  const NavigationBar({List<_i60.PageRouteInfo>? children})
    : super(NavigationBar.name, initialChildren: children);

  static const String name = 'NavigationBar';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i44.NavigationBar();
    },
  );
}

/// generated route for
/// [_i45.PluginCommentsScaffold]
class PluginCommentsScaffoldRoute
    extends _i60.PageRouteInfo<PluginCommentsScaffoldRouteArgs> {
  PluginCommentsScaffoldRoute({
    _i62.Key? key,
    required String from,
    required String comicId,
    required String comicTitle,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         PluginCommentsScaffoldRoute.name,
         args: PluginCommentsScaffoldRouteArgs(
           key: key,
           from: from,
           comicId: comicId,
           comicTitle: comicTitle,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginCommentsScaffoldRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginCommentsScaffoldRouteArgs>();
      return _i45.PluginCommentsScaffold(
        key: args.key,
        from: args.from,
        comicId: args.comicId,
        comicTitle: args.comicTitle,
      );
    },
  );
}

class PluginCommentsScaffoldRouteArgs {
  const PluginCommentsScaffoldRouteArgs({
    this.key,
    required this.from,
    required this.comicId,
    required this.comicTitle,
  });

  final _i62.Key? key;

  final String from;

  final String comicId;

  final String comicTitle;

  @override
  String toString() {
    return 'PluginCommentsScaffoldRouteArgs{key: $key, from: $from, comicId: $comicId, comicTitle: $comicTitle}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginCommentsScaffoldRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        comicId == other.comicId &&
        comicTitle == other.comicTitle;
  }

  @override
  int get hashCode =>
      key.hashCode ^ from.hashCode ^ comicId.hashCode ^ comicTitle.hashCode;
}

/// generated route for
/// [_i46.PluginFunctionPage]
class PluginFunctionRoute extends _i60.PageRouteInfo<PluginFunctionRouteArgs> {
  PluginFunctionRoute({
    _i62.Key? key,
    required String from,
    required String functionId,
    required String title,
    required _i70.Future<void> Function(Map<String, dynamic>) onAction,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         PluginFunctionRoute.name,
         args: PluginFunctionRouteArgs(
           key: key,
           from: from,
           functionId: functionId,
           title: title,
           onAction: onAction,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginFunctionRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginFunctionRouteArgs>();
      return _i46.PluginFunctionPage(
        key: args.key,
        from: args.from,
        functionId: args.functionId,
        title: args.title,
        onAction: args.onAction,
      );
    },
  );
}

class PluginFunctionRouteArgs {
  const PluginFunctionRouteArgs({
    this.key,
    required this.from,
    required this.functionId,
    required this.title,
    required this.onAction,
  });

  final _i62.Key? key;

  final String from;

  final String functionId;

  final String title;

  final _i70.Future<void> Function(Map<String, dynamic>) onAction;

  @override
  String toString() {
    return 'PluginFunctionRouteArgs{key: $key, from: $from, functionId: $functionId, title: $title, onAction: $onAction}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginFunctionRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        functionId == other.functionId &&
        title == other.title;
  }

  @override
  int get hashCode =>
      key.hashCode ^ from.hashCode ^ functionId.hashCode ^ title.hashCode;
}

/// generated route for
/// [_i47.PluginSettingsPage]
class PluginSettingsRoute extends _i60.PageRouteInfo<PluginSettingsRouteArgs> {
  PluginSettingsRoute({
    _i62.Key? key,
    required String from,
    required String pluginUuid,
    required String pluginRuntimeName,
    required String pluginDisplayName,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         PluginSettingsRoute.name,
         args: PluginSettingsRouteArgs(
           key: key,
           from: from,
           pluginUuid: pluginUuid,
           pluginRuntimeName: pluginRuntimeName,
           pluginDisplayName: pluginDisplayName,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginSettingsRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginSettingsRouteArgs>();
      return _i47.PluginSettingsPage(
        key: args.key,
        from: args.from,
        pluginUuid: args.pluginUuid,
        pluginRuntimeName: args.pluginRuntimeName,
        pluginDisplayName: args.pluginDisplayName,
      );
    },
  );
}

class PluginSettingsRouteArgs {
  const PluginSettingsRouteArgs({
    this.key,
    required this.from,
    required this.pluginUuid,
    required this.pluginRuntimeName,
    required this.pluginDisplayName,
  });

  final _i62.Key? key;

  final String from;

  final String pluginUuid;

  final String pluginRuntimeName;

  final String pluginDisplayName;

  @override
  String toString() {
    return 'PluginSettingsRouteArgs{key: $key, from: $from, pluginUuid: $pluginUuid, pluginRuntimeName: $pluginRuntimeName, pluginDisplayName: $pluginDisplayName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginSettingsRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        pluginUuid == other.pluginUuid &&
        pluginRuntimeName == other.pluginRuntimeName &&
        pluginDisplayName == other.pluginDisplayName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      from.hashCode ^
      pluginUuid.hashCode ^
      pluginRuntimeName.hashCode ^
      pluginDisplayName.hashCode;
}

/// generated route for
/// [_i48.PluginStorePage]
class PluginStoreRoute extends _i60.PageRouteInfo<void> {
  const PluginStoreRoute({List<_i60.PageRouteInfo>? children})
    : super(PluginStoreRoute.name, initialChildren: children);

  static const String name = 'PluginStoreRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i48.PluginStorePage();
    },
  );
}

/// generated route for
/// [_i49.QjsRuntimeDebugPage]
class QjsRuntimeDebugRoute extends _i60.PageRouteInfo<void> {
  const QjsRuntimeDebugRoute({List<_i60.PageRouteInfo>? children})
    : super(QjsRuntimeDebugRoute.name, initialChildren: children);

  static const String name = 'QjsRuntimeDebugRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i49.QjsRuntimeDebugPage();
    },
  );
}

/// generated route for
/// [_i50.RealSrSettingPage]
class RealSrSettingRoute extends _i60.PageRouteInfo<void> {
  const RealSrSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(RealSrSettingRoute.name, initialChildren: children);

  static const String name = 'RealSrSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i50.RealSrSettingPage();
    },
  );
}

/// generated route for
/// [_i51.SearchAggregateResultPage]
class SearchAggregateResultRoute
    extends _i60.PageRouteInfo<SearchAggregateResultRouteArgs> {
  SearchAggregateResultRoute({
    _i62.Key? key,
    required _i71.SearchEvent searchEvent,
    _i72.SearchCubit? searchCubit,
    Map<String, bool> selectedSources = const {},
    List<_i60.PageRouteInfo>? children,
  }) : super(
         SearchAggregateResultRoute.name,
         args: SearchAggregateResultRouteArgs(
           key: key,
           searchEvent: searchEvent,
           searchCubit: searchCubit,
           selectedSources: selectedSources,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchAggregateResultRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchAggregateResultRouteArgs>();
      return _i60.WrappedRoute(
        child: _i51.SearchAggregateResultPage(
          key: args.key,
          searchEvent: args.searchEvent,
          searchCubit: args.searchCubit,
          selectedSources: args.selectedSources,
        ),
      );
    },
  );
}

class SearchAggregateResultRouteArgs {
  const SearchAggregateResultRouteArgs({
    this.key,
    required this.searchEvent,
    this.searchCubit,
    this.selectedSources = const {},
  });

  final _i62.Key? key;

  final _i71.SearchEvent searchEvent;

  final _i72.SearchCubit? searchCubit;

  final Map<String, bool> selectedSources;

  @override
  String toString() {
    return 'SearchAggregateResultRouteArgs{key: $key, searchEvent: $searchEvent, searchCubit: $searchCubit, selectedSources: $selectedSources}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchAggregateResultRouteArgs) return false;
    return key == other.key &&
        searchEvent == other.searchEvent &&
        searchCubit == other.searchCubit &&
        const _i64.MapEquality<String, bool>().equals(
          selectedSources,
          other.selectedSources,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      searchEvent.hashCode ^
      searchCubit.hashCode ^
      const _i64.MapEquality<String, bool>().hash(selectedSources);
}

/// generated route for
/// [_i52.SearchPage]
class SearchRoute extends _i60.PageRouteInfo<SearchRouteArgs> {
  SearchRoute({
    _i62.Key? key,
    required _i72.SearchStates searchState,
    bool aggregateMode = true,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         SearchRoute.name,
         args: SearchRouteArgs(
           key: key,
           searchState: searchState,
           aggregateMode: aggregateMode,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchRouteArgs>();
      return _i52.SearchPage(
        key: args.key,
        searchState: args.searchState,
        aggregateMode: args.aggregateMode,
      );
    },
  );
}

class SearchRouteArgs {
  const SearchRouteArgs({
    this.key,
    required this.searchState,
    this.aggregateMode = true,
  });

  final _i62.Key? key;

  final _i72.SearchStates searchState;

  final bool aggregateMode;

  @override
  String toString() {
    return 'SearchRouteArgs{key: $key, searchState: $searchState, aggregateMode: $aggregateMode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchRouteArgs) return false;
    return key == other.key &&
        searchState == other.searchState &&
        aggregateMode == other.aggregateMode;
  }

  @override
  int get hashCode =>
      key.hashCode ^ searchState.hashCode ^ aggregateMode.hashCode;
}

/// generated route for
/// [_i53.SearchResultPage]
class SearchResultRoute extends _i60.PageRouteInfo<SearchResultRouteArgs> {
  SearchResultRoute({
    _i62.Key? key,
    required _i73.SearchEvent searchEvent,
    _i72.SearchCubit? searchCubit,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         SearchResultRoute.name,
         args: SearchResultRouteArgs(
           key: key,
           searchEvent: searchEvent,
           searchCubit: searchCubit,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchResultRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchResultRouteArgs>();
      return _i60.WrappedRoute(
        child: _i53.SearchResultPage(
          key: args.key,
          searchEvent: args.searchEvent,
          searchCubit: args.searchCubit,
        ),
      );
    },
  );
}

class SearchResultRouteArgs {
  const SearchResultRouteArgs({
    this.key,
    required this.searchEvent,
    this.searchCubit,
  });

  final _i62.Key? key;

  final _i73.SearchEvent searchEvent;

  final _i72.SearchCubit? searchCubit;

  @override
  String toString() {
    return 'SearchResultRouteArgs{key: $key, searchEvent: $searchEvent, searchCubit: $searchCubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchResultRouteArgs) return false;
    return key == other.key &&
        searchEvent == other.searchEvent &&
        searchCubit == other.searchCubit;
  }

  @override
  int get hashCode =>
      key.hashCode ^ searchEvent.hashCode ^ searchCubit.hashCode;
}

/// generated route for
/// [_i54.ShowColorPage]
class ShowColorRoute extends _i60.PageRouteInfo<void> {
  const ShowColorRoute({List<_i60.PageRouteInfo>? children})
    : super(ShowColorRoute.name, initialChildren: children);

  static const String name = 'ShowColorRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i54.ShowColorPage();
    },
  );
}

/// generated route for
/// [_i55.StorageSettingPage]
class StorageSettingRoute extends _i60.PageRouteInfo<void> {
  const StorageSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(StorageSettingRoute.name, initialChildren: children);

  static const String name = 'StorageSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i55.StorageSettingPage();
    },
  );
}

/// generated route for
/// [_i56.SyncSettingPage]
class SyncSettingRoute extends _i60.PageRouteInfo<void> {
  const SyncSettingRoute({List<_i60.PageRouteInfo>? children})
    : super(SyncSettingRoute.name, initialChildren: children);

  static const String name = 'SyncSettingRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i56.SyncSettingPage();
    },
  );
}

/// generated route for
/// [_i57.ThemeColorPage]
class ThemeColorRoute extends _i60.PageRouteInfo<void> {
  const ThemeColorRoute({List<_i60.PageRouteInfo>? children})
    : super(ThemeColorRoute.name, initialChildren: children);

  static const String name = 'ThemeColorRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i57.ThemeColorPage();
    },
  );
}

/// generated route for
/// [_i58.WebDavSyncPage]
class WebDavSyncRoute extends _i60.PageRouteInfo<void> {
  const WebDavSyncRoute({List<_i60.PageRouteInfo>? children})
    : super(WebDavSyncRoute.name, initialChildren: children);

  static const String name = 'WebDavSyncRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      return const _i58.WebDavSyncPage();
    },
  );
}

/// generated route for
/// [_i59.WebViewPage]
class WebViewRoute extends _i60.PageRouteInfo<WebViewRouteArgs> {
  WebViewRoute({
    _i62.Key? key,
    required List<String> info,
    List<_i60.PageRouteInfo>? children,
  }) : super(
         WebViewRoute.name,
         args: WebViewRouteArgs(key: key, info: info),
         initialChildren: children,
       );

  static const String name = 'WebViewRoute';

  static _i60.PageInfo page = _i60.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WebViewRouteArgs>();
      return _i59.WebViewPage(key: args.key, info: args.info);
    },
  );
}

class WebViewRouteArgs {
  const WebViewRouteArgs({this.key, required this.info});

  final _i62.Key? key;

  final List<String> info;

  @override
  String toString() {
    return 'WebViewRouteArgs{key: $key, info: $info}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WebViewRouteArgs) return false;
    return key == other.key &&
        const _i64.ListEquality<String>().equals(info, other.info);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const _i64.ListEquality<String>().hash(info);
}
