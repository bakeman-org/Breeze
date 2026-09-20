import 'package:flutter/widgets.dart';

import 'package:zephyr/main.dart';
import 'package:zephyr/widgets/hyper_toast.dart';

/// Toast 类型。与 [HyperToastType] 一一对应，保留是为了兼容旧的
/// [ToastEvent] 事件通道。
enum ToastType { info, success, warning, error }

/// 跨隔离事件：当调用方没有 context 时，通过 [eventBus] 把请求转发给
/// 顶层（NavigationBar 的 `_showToast`）去消费。
class ToastEvent {
  ToastType type;
  String? title;
  String message;
  Duration duration;

  ToastEvent({
    required this.type,
    this.title,
    required this.message,
    required this.duration,
  });
}

/// 把 [ToastType] 映射成 [HyperToastType]。
HyperToastType _mapType(ToastType type) {
  switch (type) {
    case ToastType.info:
      return HyperToastType.info;
    case ToastType.success:
      return HyperToastType.success;
    case ToastType.warning:
      return HyperToastType.warning;
    case ToastType.error:
      return HyperToastType.error;
  }
}

/// 把标题和正文拼成 HyperOS toast 能显示的多行文字。
///
/// HyperOS toast 没有独立的「标题区」，两行文本用换行符拼接即可。
String _composeText(String? title, String message) {
  if (title == null || title.isEmpty) return message;
  return '$title\n$message';
}

// ─────────────────────────────────────────────────────────────────────
// 对外 API
// ─────────────────────────────────────────────────────────────────────
//
// 4 个 showXxxToast 的签名保持不变：
//   - 传 context → 直接走 HyperToast.show；
//   - 不传 context → 通过 eventBus 转发 ToastEvent，由 NavigationBar 消费。
//
// 这样做的好处：
//   1. 所有调用点无需修改；
//   2. 底层 UI 从 toastification 换成 HyperOS 风格；
//   3. 保留无 context 的兼容路径。

void showInfoToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 2),
  BuildContext? context,
}) {
  if (context != null) {
    HyperToast.show(
      context,
      _composeText(title, message),
      type: HyperToastType.info,
      duration: duration,
    );
    return;
  }

  eventBus.fire(
    ToastEvent(
      type: ToastType.info,
      title: title,
      message: message,
      duration: duration,
    ),
  );
}

void showSuccessToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 2),
  BuildContext? context,
}) {
  if (context != null) {
    HyperToast.show(
      context,
      _composeText(title, message),
      type: HyperToastType.success,
      duration: duration,
    );
    return;
  }

  eventBus.fire(
    ToastEvent(
      type: ToastType.success,
      title: title,
      message: message,
      duration: duration,
    ),
  );
}

void showWarningToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 2),
  BuildContext? context,
}) {
  if (context != null) {
    HyperToast.show(
      context,
      _composeText(title, message),
      type: HyperToastType.warning,
      duration: duration,
    );
    return;
  }

  eventBus.fire(
    ToastEvent(
      type: ToastType.warning,
      title: title,
      message: message,
      duration: duration,
    ),
  );
}

void showErrorToast(
  String message, {
  String? title,
  Duration duration = const Duration(seconds: 5),
  BuildContext? context,
}) {
  if (context != null) {
    HyperToast.show(
      context,
      _composeText(title, message),
      type: HyperToastType.error,
      duration: duration,
    );
    return;
  }

  eventBus.fire(
    ToastEvent(
      type: ToastType.error,
      title: title,
      message: message,
      duration: duration,
    ),
  );
}
