import 'dart:convert';

import 'package:flutter/widgets.dart' show Offset;
import 'package:shared_preferences/shared_preferences.dart';

/// 每个页面悬浮按钮组（FAB group）的位置持久化。
///
/// 设计权衡：FAB 位置数量少（4 页），用 SharedPreferences 存
/// `fab_pos_v1/<pageKey>` → `[dx, dy]` 即可，无需 ObjectBox 事务开销。
///
/// 读取：[main] 里 `await FabPositionStore.init()` 一次，之后 [getOffset] 同步读。
/// 写入：[saveOffset] fire-and-forget；若未初始化会自行 await 实例后再写。
class FabPositionStore {
  FabPositionStore._();

  static const String _kPrefix = 'fab_pos_v1/';
  static SharedPreferences? _prefs;

  /// 在 `main()` 内 `await` 一次，保证后续 [getOffset] 同步可读。
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 同步读取某页 FAB 的持久化位置。未初始化或没存过返回 null。
  static Offset? getOffset(String pageKey) {
    final raw = _prefs?.getString('$_kPrefix$pageKey');
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw);
      if (list is List && list.length == 2) {
        return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
      }
    } catch (_) {}
    return null;
  }

  /// 写入位置。未初始化时自行获取实例后写入（首次拖拽也能持久化）。
  static Future<void> saveOffset(String pageKey, Offset offset) async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(
      '$_kPrefix$pageKey',
      jsonEncode(<double>[offset.dx, offset.dy]),
    );
  }

  /// 清除某页 FAB 的位置记录（恢复默认）。
  static Future<void> removeOffset(String pageKey) async {
    final p = _prefs;
    if (p == null) {
      final fresh = await SharedPreferences.getInstance();
      await fresh.remove('$_kPrefix$pageKey');
      return;
    }
    await p.remove('$_kPrefix$pageKey');
  }
}
