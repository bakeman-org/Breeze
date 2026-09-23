import 'package:zephyr/page/bookshelf/models/shelf_group_mode.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';

/// 分组结果：有序组名 + 每组漫画。
class ShelfGrouping {
  const ShelfGrouping({required this.order, required this.items});

  /// 已排序的组名列表。
  final List<String> order;

  /// 组名 -> 漫画列表（保持原有排序）。
  final Map<String, List<ComicSimplifyEntryInfo>> items;

  bool get isEmpty => order.isEmpty;
  int get total => items.values.fold(0, (sum, list) => sum + list.length);
}

/// 对下载漫画进行分组。
///
/// 纯展示层计算，不写数据库、不影响任何持久化结构。
ShelfGrouping groupDownloadComics({
  required List<ComicSimplifyEntryInfo> comics,
  required ShelfGroupMode mode,
  required Map<String, String> comicDownloadDates,
}) {
  final buckets = <String, List<ComicSimplifyEntryInfo>>{};
  for (final comic in comics) {
    final key = _groupKeyFor(comic, mode, comicDownloadDates);
    buckets.putIfAbsent(key, () => []).add(comic);
  }

  final order = buckets.keys.toList()..sort(_comparatorFor(mode));
  return ShelfGrouping(order: order, items: buckets);
}

String _groupKeyFor(
  ComicSimplifyEntryInfo comic,
  ShelfGroupMode mode,
  Map<String, String> dates,
) {
  switch (mode) {
    case ShelfGroupMode.none:
      return '';
    case ShelfGroupMode.bySource:
      final source = comic.from.trim();
      return source.isEmpty ? '未知来源' : source;
    case ShelfGroupMode.byTitle:
      final title = comic.title.trim();
      if (title.isEmpty) return '#';
      final first = String.fromCharCode(title.runes.first);
      return RegExp(r'[a-zA-Z]').hasMatch(first) ? first.toUpperCase() : first;
    case ShelfGroupMode.byDate:
      final key = '${comic.from.trim()}:${comic.id}';
      final iso = dates[key];
      final dt = iso == null ? null : DateTime.tryParse(iso);
      if (dt == null) return '未知日期';
      final local = dt.toLocal();
      // ✅ 精确到日：yyyy-MM-dd
      return '${local.year}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
  }
}

int Function(String, String) _comparatorFor(ShelfGroupMode mode) {
  switch (mode) {
    case ShelfGroupMode.byDate:
      return (a, b) => b.compareTo(a);
    case ShelfGroupMode.bySource:
    case ShelfGroupMode.byTitle:
    case ShelfGroupMode.none:
      return (a, b) => a.compareTo(b);
  }
}
