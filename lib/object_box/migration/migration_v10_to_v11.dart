import 'dart:convert';

import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';

/// v10 -> v11: 代理设置从 enabled+type 改为四态 mode（直连/系统/HTTP/SOCKS5）。
///
/// 直接操作原始 JSON，避免新 fromJson 丢弃旧的 enabled/type 字段。
/// - enabled=true：按 type 映射为 http/socks5
/// - enabled=false：直连
/// - 已含 mode 字段：跳过
Future<void> migrateV10ToV11() async {
  final userSetting = objectbox.userSettingBox.get(1);
  if (userSetting == null) {
    throw Exception('Global setting not found');
  }

  final raw = userSetting.globalSettingData;
  if (raw == null || raw.isEmpty) {
    logger.d('[migration_v10_to_v11] globalSettingData 为空，跳过');
    return;
  }

  final json = jsonDecode(raw);
  if (json is! Map<String, dynamic>) {
    logger.d('[migration_v10_to_v11] globalSettingData 非 JSON 对象，跳过');
    return;
  }

  final proxyJson = json['proxySetting'];
  if (proxyJson is! Map<String, dynamic> || proxyJson['mode'] != null) {
    logger.d('[migration_v10_to_v11] 代理配置已是 mode 结构，跳过');
    return;
  }

  final enabled = proxyJson['enabled'] == true;
  final type = proxyJson['type'];
  final mode = !enabled
      ? ProxyMode.direct
      : (type == 'socks5' ? ProxyMode.socks5 : ProxyMode.http);

  proxyJson
    ..remove('enabled')
    ..remove('type')
    ..['mode'] = mode.name;
  json['proxySetting'] = proxyJson;

  userSetting.globalSettingData = jsonEncode(json);
  objectbox.userSettingBox.put(userSetting);

  final address = proxyJson['address'];
  logger.d(
    '[migration_v10_to_v11] proxyMode=$mode '
    '(proxy=${address is String && address.isEmpty ? "empty" : "set"})',
  );
}
