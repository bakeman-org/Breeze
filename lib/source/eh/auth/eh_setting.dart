import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/source/eh/api/eh_hosts.dart';

part 'eh_setting.freezed.dart';
part 'eh_setting.g.dart';

const ehDomainE = 'e-hentai.org';
const ehDomainEx = 'exhentai.org';

@freezed
abstract class EhSettingState with _$EhSettingState {
  const factory EhSettingState({
    @Default(ehDomainE) String site,
    @Default('') String ipbMemberId,
    @Default('') String ipbPassHash,
    @Default('') String igneous,
    @Default(true) bool builtInHosts,
  }) = _EhSettingState;

  factory EhSettingState.fromJson(Map<String, dynamic> json) =>
      _$EhSettingStateFromJson(json);
}

extension EhSettingStateX on EhSettingState {
  bool get hasCredentials => ipbMemberId.isNotEmpty && ipbPassHash.isNotEmpty;

  bool get isEx => site == ehDomainEx;

  String get domain => isEx ? ehDomainEx : ehDomainE;

  String get host => 'https://$domain/';

  String get referer => 'https://$domain';

  String get apiHost => '${host}api.php';

  String get cookieHeader {
    if (!hasCredentials) return '';
    return [
      'ipb_member_id=$ipbMemberId',
      'ipb_pass_hash=$ipbPassHash',
      if (igneous.isNotEmpty) 'igneous=$igneous',
    ].join('; ');
  }
}

EhSettingState get ehSettingState {
  return objectbox.userSettingBox.get(1)?.ehSetting ?? const EhSettingState();
}

void saveEhSettingState(EhSettingState setting) {
  final user = objectbox.userSettingBox.get(1);
  if (user == null) return;
  user.ehSetting = setting;
  objectbox.userSettingBox.put(user);
}

Map<String, List<String>>? activeEhResolveHosts() {
  return ehResolveHosts(ehSettingState.builtInHosts);
}
