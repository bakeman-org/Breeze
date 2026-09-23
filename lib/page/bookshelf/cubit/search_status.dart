import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/page/bookshelf/models/shelf_group_mode.dart';

part 'search_status.freezed.dart'; // 运行 build_runner 生成

@freezed
abstract class SearchStatusState with _$SearchStatusState {
  const factory SearchStatusState({
    @Default("") String keyword,
    @Default("dd") String sort,
    @Default(<String>[]) List<String> sources,
    @Default(ShelfGroupMode.none) ShelfGroupMode groupMode, // ✅ 新增
  }) = _SearchStatusState;
}
