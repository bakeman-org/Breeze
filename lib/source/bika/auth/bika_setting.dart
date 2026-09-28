import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/main.dart';

part 'bika_setting.freezed.dart';
part 'bika_setting.g.dart';

@freezed
abstract class BikaNativeSetting with _$BikaNativeSetting {
  const factory BikaNativeSetting({
    @Default('') String account,
    @Default('') String password,
    @Default('') String authorization,
    @Default('original') String imageQuality,
    @Default('go2778') String api,
  }) = _BikaNativeSetting;

  factory BikaNativeSetting.fromJson(Map<String, dynamic> json) =>
      _$BikaNativeSettingFromJson(json);
}

extension BikaNativeSettingX on BikaNativeSetting {
  bool get hasAuthorization => authorization.trim().isNotEmpty;

  String get apiHost => api == 'picacomic'
      ? 'https://picaapi.picacomic.com/'
      : 'https://picaapi.go2778.com/';
}

BikaNativeSetting get bikaNativeSetting {
  return objectbox.userSettingBox.get(1)?.bikaNativeSetting ??
      const BikaNativeSetting();
}

void saveBikaNativeSetting(BikaNativeSetting setting) {
  final user = objectbox.userSettingBox.get(1);
  if (user == null) return;
  user.bikaNativeSetting = setting;
  objectbox.userSettingBox.put(user);
}
