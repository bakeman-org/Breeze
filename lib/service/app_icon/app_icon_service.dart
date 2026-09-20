import 'dart:io';

import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';

/// 应用图标服务。
///
/// 集中管理「应用图标」这一跨页面共享的状态：
///   - Android / iOS 上读 / 写系统 alternate icon；
///   - 桌面和其他平台退化为静态资产（经典图），所有写操作是 no-op；
///   - 对外暴露 [AppIconState]，UI 通过 [ValueListenable] 订阅即可，
///     不必在每个页面里重复 `getAlternateIconName()`。
///
/// 使用方式：
/// ```dart
/// // 页面 initState 里触发一次加载（幂等，多次调用无副作用）
/// AppIconService.instance.ensureLoaded();
///
/// // build 里订阅
/// ValueListenableBuilder<AppIconState>(
///   valueListenable: AppIconService.instance,
///   builder: (_, state, __) => Image.asset(state.assetPath),
/// );
/// ```
class AppIconService extends ValueNotifier<AppIconState> {
  AppIconService._() : super(const AppIconState.classic());

  /// 全局单例。
  static final AppIconService instance = AppIconService._();

  /// 原生侧「现代」图标的 alternate icon 名称。
  ///
  /// 必须与 AndroidManifest 中 `<activity-alias android:name>` 的最后一段
  /// 保持一致（见 `com.zephyr.breeze.MainActivity.IconModern`）。
  static const modernIconName = 'IconModern';

  /// 只在这些平台上做动态图标切换。
  bool get _supported => Platform.isAndroid || Platform.isIOS;

  bool _loaded = false;
  Future<void>? _loading;

  /// 读一次系统侧当前生效的 alternate icon。
  ///
  /// - 幂等：第一次调用会真正查询，之后直接返回。
  /// - 可重入：并发调用会复用同一个 Future，避免重复查询。
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      if (_supported) {
        final name = await DynamicAppIconFlutterPlus.getAlternateIconName();
        value = AppIconState.fromName(name);
      }
      // 桌面平台保持默认经典值，不查询（平台不支持，调用会抛）。
    } catch (_) {
      // 某些 ROM 不支持动态图标，静默降级为经典。
      value = const AppIconState.classic();
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// 切换图标。
  ///
  /// - `iconName` 为 null 表示切回经典；
  /// - 桌面平台直接 no-op（只更新本地状态，原生不做任何事）。
  ///
  /// 返回 true 表示切换成功，false 表示失败（原生抛异常）。
  Future<bool> switchTo(String? iconName) async {
    // 同一个值不用重复设置。
    if (iconName == value.iconName) return true;

    if (!_supported) {
      // 桌面平台：只更新本地状态，让 UI 有反馈。
      value = AppIconState.fromName(iconName);
      return true;
    }

    try {
      await DynamicAppIconFlutterPlus.setAlternateIconName(iconName);
      value = AppIconState.fromName(iconName);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 应用图标的展示状态。
///
/// 不可变；值相等用 [iconName] 判断，方便 `ValueNotifier` 只在真正变化时
/// 通知监听者。
@immutable
class AppIconState {
  const AppIconState._({
    required this.iconName,
    required this.assetPath,
    required this.label,
  });

  /// 原生侧 alternate icon 名称；null 表示经典图标。
  final String? iconName;

  /// 预览用的 asset 路径。
  final String assetPath;

  /// 中文显示名，用于 UI 展示（如「经典」「现代」）。
  final String label;

  /// 经典图标（默认）。
  const AppIconState.classic()
    : this._(
        iconName: null,
        assetPath: 'asset/image/app-icon.png',
        label: '经典',
      );

  /// 现代图标。
  const AppIconState.modern()
    : this._(
        iconName: AppIconService.modernIconName,
        assetPath: 'asset/image/app-icon-modern.png',
        label: '现代',
      );

  /// 从原生侧的 icon 名称反推状态。
  ///
  /// 未识别的名字（理论上不会出现）一律降级为经典。
  factory AppIconState.fromName(String? name) {
    return name == AppIconService.modernIconName
        ? const AppIconState.modern()
        : const AppIconState.classic();
  }

  @override
  bool operator ==(Object other) =>
      other is AppIconState && other.iconName == iconName;

  @override
  int get hashCode => iconName.hashCode;
}
