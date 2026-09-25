// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eh_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EhSettingState _$EhSettingStateFromJson(Map<String, dynamic> json) =>
    _EhSettingState(
      site: json['site'] as String? ?? ehDomainE,
      ipbMemberId: json['ipbMemberId'] as String? ?? '',
      ipbPassHash: json['ipbPassHash'] as String? ?? '',
      igneous: json['igneous'] as String? ?? '',
      builtInHosts: json['builtInHosts'] as bool? ?? true,
    );

Map<String, dynamic> _$EhSettingStateToJson(_EhSettingState instance) =>
    <String, dynamic>{
      'site': instance.site,
      'ipbMemberId': instance.ipbMemberId,
      'ipbPassHash': instance.ipbPassHash,
      'igneous': instance.igneous,
      'builtInHosts': instance.builtInHosts,
    };
