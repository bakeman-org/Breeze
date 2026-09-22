// lib/service/update/ntfy/ntfy_notification_bridge.dart
//
// ntfy 消息 → 系统通知的桥接。
//
// 在 bootstrap 里调用 [NtfyNotificationBridge.install] 后，
// 每条 ntfy 消息都会弹出一条系统通知。
// 通知点击后携带 payload=msg.click（如果有 URL）。

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/service/update/ntfy/ntfy_service.dart';
import 'package:zephyr/service/update/ntfy/torch_service.dart';

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
      // ★ 新增：根据消息内容触发手电筒闪烁
      // 你可以解析 msg.message 或自定义的标签来决定闪烁参数。
      // 例如，如果消息正文是 "FLASH:5:500"，则闪烁 5 次，每次 500ms。
      final flashConfig = _parseFlashConfig(msg.message);
      if (flashConfig != null) {
        // 不 await，避免阻塞通知回调
        unawaited(
          TorchService.I.flash(
            count: flashConfig.count,
            onMs: flashConfig.onMs,
            gapMs: flashConfig.gapMs,
          ),
        );
      } else {
        // 如果没有特殊配置，使用默认闪烁
        unawaited(TorchService.I.flash()); // 默认 3 次，1 秒亮，300ms 间隔
      }
    } catch (e, st) {
      logger.w('[NtfyNotify] show failed: $e', error: e, stackTrace: st);
    }
  }

  /// 解析消息中的闪烁指令，格式例如 "FLASH:5:500" 表示闪烁5次，每次亮500ms。
  /// 返回 null 表示没有特定指令，使用默认值。
  static _FlashConfig? _parseFlashConfig(String message) {
    // 这是一个简单的实现，你可以根据实际需求设计更复杂的协议。
    // 例如，可以使用 ntfy 的 tags 或 headers 来传递参数。
    final regex = RegExp(r'FLASH:(\d+):(\d+)');
    final match = regex.firstMatch(message);
    if (match != null) {
      final count = int.tryParse(match.group(1)!) ?? 3;
      final onMs = int.tryParse(match.group(2)!) ?? 1000;
      return _FlashConfig(count: count, onMs: onMs);
    }
    return null;
  }
}

class _FlashConfig {
  final int count;
  final int onMs;
  final int gapMs;
  _FlashConfig({required this.count, required this.onMs}) : gapMs = 300;
}
