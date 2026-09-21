// lib/service/update/ntfy/ntfy_notification_bridge.dart
//
// ntfy 消息 → 系统通知的桥接。
//
// 在 bootstrap 里调用 [NtfyNotificationBridge.install] 后，
// 每条 ntfy 消息都会弹出一条系统通知。
// 通知点击后携带 payload=msg.click（如果有 URL）。

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/service/update/ntfy/ntfy_service.dart';

class NtfyNotificationBridge {
  NtfyNotificationBridge._();

  static const String channelId = 'breeze_announcements';
  static const String channelName = 'Breeze 公告';
  static const String channelDescription = 'Breeze 开发者公告';

  static bool _installed = false;
  static int _fallbackSeq = 0;

  /// 安装桥接。只装一次，重复调用幂等。
  static void install() {
    if (_installed) return;
    _installed = true;
    NtfyService.I.onMessage = _onMessage;
  }

  static Future<void> _onMessage(NtfyMessage msg) async {
    try {
      final title = (msg.title?.trim().isNotEmpty ?? false)
          ? msg.title!.trim()
          : 'Breeze 公告';

      // 用 id 哈希作为通知 id，同一条消息不会重复弹。
      final id = msg.id.isNotEmpty
          ? (msg.id.hashCode & 0x7fffffff)
          : (++_fallbackSeq & 0x7fffffff);

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'breeze_announcements',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ★ 新版 API：全命名参数。
      //   - id / title / body / notificationDetails / payload 均为命名参数
      //   - notificationDetails 是聚合类型 NotificationDetails，不是分开的
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: msg.message,
        notificationDetails: details,
        payload: msg.click,
      );
    } catch (e, st) {
      logger.w('[NtfyNotify] show failed: $e', error: e, stackTrace: st);
    }
  }
}
