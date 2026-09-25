// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bika_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BikaNativeSetting _$BikaNativeSettingFromJson(Map<String, dynamic> json) =>
    _BikaNativeSetting(
      account: json['account'] as String? ?? '',
      password: json['password'] as String? ?? '',
      authorization: json['authorization'] as String? ?? '',
      imageQuality: json['imageQuality'] as String? ?? 'original',
      api: json['api'] as String? ?? 'go2778',
    );

Map<String, dynamic> _$BikaNativeSettingToJson(_BikaNativeSetting instance) =>
    <String, dynamic>{
      'account': instance.account,
      'password': instance.password,
      'authorization': instance.authorization,
      'imageQuality': instance.imageQuality,
      'api': instance.api,
    };
