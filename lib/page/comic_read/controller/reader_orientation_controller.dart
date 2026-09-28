import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/util/debouncer.dart';

/// 管理阅读页临时使用的屏幕方向。
///
/// Android 及 iOS 的大屏设备不强制设置方向，避免和系统的多窗口及大屏策略冲突。
class ReaderOrientationController {
  static Future<void> _pendingRequest = Future<void>.value();
  static ReaderOrientationController? _activeController;

  ReaderOrientationController() {
    _activeController = this;
  }

  bool get _isSupportedPhone {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }

    return !isTabletWithOutContext();
  }

  Future<void> setLandscape(bool enabled) async {
    if (!_isActive || !_isSupportedPhone) {
      return;
    }

    final orientations = enabled
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        // 关闭横屏阅读时，不强制锁竖屏，而是释放回全方向跟随系统，
        // 这样应用其他页面在用户旋转系统时也能横屏。
        : DeviceOrientation.values;
    final previousRequest = _pendingRequest;
    final request = _applyAfter(previousRequest, orientations);
    _pendingRequest = request;
    await request;
  }

  /// 退出阅读页时释放方向锁定，让其他页面可自由跟随系统旋转。
  Future<void> restorePortrait() async {
    if (!_isActive) {
      return;
    }

    await setLandscape(false);
    if (identical(_activeController, this)) {
      _activeController = null;
    }
  }

  bool get _isActive => identical(_activeController, this);

  Future<void> _applyAfter(
    Future<void> previousRequest,
    List<DeviceOrientation> orientations,
  ) async {
    try {
      await previousRequest;
    } catch (_) {
      // 一个方向请求失败时，后续请求仍然应该继续执行。
    }
    await SystemChrome.setPreferredOrientations(orientations);
  }
}
