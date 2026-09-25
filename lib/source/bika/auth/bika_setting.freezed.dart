// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bika_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BikaNativeSetting {

 String get account; String get password; String get authorization; String get imageQuality; String get api;
/// Create a copy of BikaNativeSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BikaNativeSettingCopyWith<BikaNativeSetting> get copyWith => _$BikaNativeSettingCopyWithImpl<BikaNativeSetting>(this as BikaNativeSetting, _$identity);

  /// Serializes this BikaNativeSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BikaNativeSetting;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BikaNativeSetting&&(identical(other.account, _this.account) || other.account == _this.account)&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.authorization, _this.authorization) || other.authorization == _this.authorization)&&(identical(other.imageQuality, _this.imageQuality) || other.imageQuality == _this.imageQuality)&&(identical(other.api, _this.api) || other.api == _this.api));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BikaNativeSetting;
  return Object.hash(runtimeType,_this.account,_this.password,_this.authorization,_this.imageQuality,_this.api);
}

@override
String toString() {
  final _this = this as BikaNativeSetting;
  return 'BikaNativeSetting(account: ${_this.account}, password: ${_this.password}, authorization: ${_this.authorization}, imageQuality: ${_this.imageQuality}, api: ${_this.api})';
}


}

/// @nodoc
abstract mixin class $BikaNativeSettingCopyWith<$Res>  {
  factory $BikaNativeSettingCopyWith(BikaNativeSetting value, $Res Function(BikaNativeSetting) _then) = _$BikaNativeSettingCopyWithImpl;
@useResult
$Res call({
 String account, String password, String authorization, String imageQuality, String api
});




}
/// @nodoc
class _$BikaNativeSettingCopyWithImpl<$Res>
    implements $BikaNativeSettingCopyWith<$Res> {
  _$BikaNativeSettingCopyWithImpl(this._self, this._then);

  final BikaNativeSetting _self;
  final $Res Function(BikaNativeSetting) _then;

/// Create a copy of BikaNativeSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? account = null,Object? password = null,Object? authorization = null,Object? imageQuality = null,Object? api = null,}) {
  return _then(BikaNativeSetting(
account: null == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,authorization: null == authorization ? _self.authorization : authorization // ignore: cast_nullable_to_non_nullable
as String,imageQuality: null == imageQuality ? _self.imageQuality : imageQuality // ignore: cast_nullable_to_non_nullable
as String,api: null == api ? _self.api : api // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BikaNativeSetting].
extension BikaNativeSettingPatterns on BikaNativeSetting {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BikaNativeSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BikaNativeSetting() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BikaNativeSetting value)  $default,){
final _that = this;
switch (_that) {
case _BikaNativeSetting():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BikaNativeSetting value)?  $default,){
final _that = this;
switch (_that) {
case _BikaNativeSetting() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String account,  String password,  String authorization,  String imageQuality,  String api)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BikaNativeSetting() when $default != null:
return $default(_that.account,_that.password,_that.authorization,_that.imageQuality,_that.api);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String account,  String password,  String authorization,  String imageQuality,  String api)  $default,) {final _that = this;
switch (_that) {
case _BikaNativeSetting():
return $default(_that.account,_that.password,_that.authorization,_that.imageQuality,_that.api);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String account,  String password,  String authorization,  String imageQuality,  String api)?  $default,) {final _that = this;
switch (_that) {
case _BikaNativeSetting() when $default != null:
return $default(_that.account,_that.password,_that.authorization,_that.imageQuality,_that.api);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BikaNativeSetting implements BikaNativeSetting {
  const _BikaNativeSetting({this.account = '', this.password = '', this.authorization = '', this.imageQuality = 'original', this.api = 'go2778'});
  factory _BikaNativeSetting.fromJson(Map<String, dynamic> json) => _$BikaNativeSettingFromJson(json);

@override@JsonKey() final  String account;
@override@JsonKey() final  String password;
@override@JsonKey() final  String authorization;
@override@JsonKey() final  String imageQuality;
@override@JsonKey() final  String api;

/// Create a copy of BikaNativeSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BikaNativeSettingCopyWith<_BikaNativeSetting> get copyWith => __$BikaNativeSettingCopyWithImpl<_BikaNativeSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BikaNativeSettingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BikaNativeSetting&&(identical(other.account, account) || other.account == account)&&(identical(other.password, password) || other.password == password)&&(identical(other.authorization, authorization) || other.authorization == authorization)&&(identical(other.imageQuality, imageQuality) || other.imageQuality == imageQuality)&&(identical(other.api, api) || other.api == api));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,account,password,authorization,imageQuality,api);
}

@override
String toString() {
    return 'BikaNativeSetting(account: $account, password: $password, authorization: $authorization, imageQuality: $imageQuality, api: $api)';
}


}

/// @nodoc
abstract mixin class _$BikaNativeSettingCopyWith<$Res> implements $BikaNativeSettingCopyWith<$Res> {
  factory _$BikaNativeSettingCopyWith(_BikaNativeSetting value, $Res Function(_BikaNativeSetting) _then) = __$BikaNativeSettingCopyWithImpl;
@override @useResult
$Res call({
 String account, String password, String authorization, String imageQuality, String api
});




}
/// @nodoc
class __$BikaNativeSettingCopyWithImpl<$Res>
    implements _$BikaNativeSettingCopyWith<$Res> {
  __$BikaNativeSettingCopyWithImpl(this._self, this._then);

  final _BikaNativeSetting _self;
  final $Res Function(_BikaNativeSetting) _then;

/// Create a copy of BikaNativeSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? account = null,Object? password = null,Object? authorization = null,Object? imageQuality = null,Object? api = null,}) {
  return _then(_BikaNativeSetting(
account: null == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,authorization: null == authorization ? _self.authorization : authorization // ignore: cast_nullable_to_non_nullable
as String,imageQuality: null == imageQuality ? _self.imageQuality : imageQuality // ignore: cast_nullable_to_non_nullable
as String,api: null == api ? _self.api : api // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
