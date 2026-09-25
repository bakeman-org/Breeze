import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';

/// v8 -> v9: 将旧的 SOCKS5 代理开关迁移到通用代理配置 [ProxySettingState]。
///
/// - 旧开关开启且配置了地址：SOCKS5 模式，沿用原地址
/// - 旧开关开启但未配置地址：HTTP 模式
/// - 旧开关关闭：直连
Future<void> migrateV8ToV9() async {
  final userSetting = objectbox.userSettingBox.get(1);
  if (userSetting == null) {
    throw Exception('Global setting not found');
  }

  final current = userSetting.globalSetting;
  final hasSocks5 = current.socks5Proxy.trim().isNotEmpty;
  final mode = !current.socks5ProxyEnabled
      ? ProxyMode.direct
      : (hasSocks5 ? ProxyMode.socks5 : ProxyMode.http);
  final next = current.copyWith(
    proxySetting: ProxySettingState(mode: mode, address: current.socks5Proxy),
  );
  userSetting.globalSetting = next;
  objectbox.userSettingBox.put(userSetting);

  logger.d(
    '[migration_v8_to_v9] proxyMode=${next.proxySetting.mode.name} '
    '(proxy=${next.proxySetting.address.isEmpty ? "empty" : "set"})',
  );
}
