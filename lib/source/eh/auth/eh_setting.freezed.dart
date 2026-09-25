// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'eh_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EhSettingState {

 String get site; String get ipbMemberId; String get ipbPassHash; String get igneous; bool get builtInHosts;
/// Create a copy of EhSettingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EhSettingStateCopyWith<EhSettingState> get copyWith => _$EhSettingStateCopyWithImpl<EhSettingState>(this as EhSettingState, _$identity);

  /// Serializes this EhSettingState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EhSettingState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EhSettingState&&(identical(other.site, _this.site) || other.site == _this.site)&&(identical(other.ipbMemberId, _this.ipbMemberId) || other.ipbMemberId == _this.ipbMemberId)&&(identical(other.ipbPassHash, _this.ipbPassHash) || other.ipbPassHash == _this.ipbPassHash)&&(identical(other.igneous, _this.igneous) || other.igneous == _this.igneous)&&(identical(other.builtInHosts, _this.builtInHosts) || other.builtInHosts == _this.builtInHosts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EhSettingState;
  return Object.hash(runtimeType,_this.site,_this.ipbMemberId,_this.ipbPassHash,_this.igneous,_this.builtInHosts);
}

@override
String toString() {
  final _this = this as EhSettingState;
  return 'EhSettingState(site: ${_this.site}, ipbMemberId: ${_this.ipbMemberId}, ipbPassHash: ${_this.ipbPassHash}, igneous: ${_this.igneous}, builtInHosts: ${_this.builtInHosts})';
}


}

/// @nodoc
abstract mixin class $EhSettingStateCopyWith<$Res>  {
  factory $EhSettingStateCopyWith(EhSettingState value, $Res Function(EhSettingState) _then) = _$EhSettingStateCopyWithImpl;
@useResult
$Res call({
 String site, String ipbMemberId, String ipbPassHash, String igneous, bool builtInHosts
});




}
/// @nodoc
class _$EhSettingStateCopyWithImpl<$Res>
    implements $EhSettingStateCopyWith<$Res> {
  _$EhSettingStateCopyWithImpl(this._self, this._then);

  final EhSettingState _self;
  final $Res Function(EhSettingState) _then;

/// Create a copy of EhSettingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? site = null,Object? ipbMemberId = null,Object? ipbPassHash = null,Object? igneous = null,Object? builtInHosts = null,}) {
  return _then(EhSettingState(
site: null == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as String,ipbMemberId: null == ipbMemberId ? _self.ipbMemberId : ipbMemberId // ignore: cast_nullable_to_non_nullable
as String,ipbPassHash: null == ipbPassHash ? _self.ipbPassHash : ipbPassHash // ignore: cast_nullable_to_non_nullable
as String,igneous: null == igneous ? _self.igneous : igneous // ignore: cast_nullable_to_non_nullable
as String,builtInHosts: null == builtInHosts ? _self.builtInHosts : builtInHosts // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EhSettingState].
extension EhSettingStatePatterns on EhSettingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EhSettingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EhSettingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EhSettingState value)  $default,){
final _that = this;
switch (_that) {
case _EhSettingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EhSettingState value)?  $default,){
final _that = this;
switch (_that) {
case _EhSettingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String site,  String ipbMemberId,  String ipbPassHash,  String igneous,  bool builtInHosts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EhSettingState() when $default != null:
return $default(_that.site,_that.ipbMemberId,_that.ipbPassHash,_that.igneous,_that.builtInHosts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String site,  String ipbMemberId,  String ipbPassHash,  String igneous,  bool builtInHosts)  $default,) {final _that = this;
switch (_that) {
case _EhSettingState():
return $default(_that.site,_that.ipbMemberId,_that.ipbPassHash,_that.igneous,_that.builtInHosts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String site,  String ipbMemberId,  String ipbPassHash,  String igneous,  bool builtInHosts)?  $default,) {final _that = this;
switch (_that) {
case _EhSettingState() when $default != null:
return $default(_that.site,_that.ipbMemberId,_that.ipbPassHash,_that.igneous,_that.builtInHosts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EhSettingState implements EhSettingState {
  const _EhSettingState({this.site = ehDomainE, this.ipbMemberId = '', this.ipbPassHash = '', this.igneous = '', this.builtInHosts = true});
  factory _EhSettingState.fromJson(Map<String, dynamic> json) => _$EhSettingStateFromJson(json);

@override@JsonKey() final  String site;
@override@JsonKey() final  String ipbMemberId;
@override@JsonKey() final  String ipbPassHash;
@override@JsonKey() final  String igneous;
@override@JsonKey() final  bool builtInHosts;

/// Create a copy of EhSettingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EhSettingStateCopyWith<_EhSettingState> get copyWith => __$EhSettingStateCopyWithImpl<_EhSettingState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EhSettingStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EhSettingState&&(identical(other.site, site) || other.site == site)&&(identical(other.ipbMemberId, ipbMemberId) || other.ipbMemberId == ipbMemberId)&&(identical(other.ipbPassHash, ipbPassHash) || other.ipbPassHash == ipbPassHash)&&(identical(other.igneous, igneous) || other.igneous == igneous)&&(identical(other.builtInHosts, builtInHosts) || other.builtInHosts == builtInHosts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,site,ipbMemberId,ipbPassHash,igneous,builtInHosts);
}

@override
String toString() {
    return 'EhSettingState(site: $site, ipbMemberId: $ipbMemberId, ipbPassHash: $ipbPassHash, igneous: $igneous, builtInHosts: $builtInHosts)';
}


}

/// @nodoc
abstract mixin class _$EhSettingStateCopyWith<$Res> implements $EhSettingStateCopyWith<$Res> {
  factory _$EhSettingStateCopyWith(_EhSettingState value, $Res Function(_EhSettingState) _then) = __$EhSettingStateCopyWithImpl;
@override @useResult
$Res call({
 String site, String ipbMemberId, String ipbPassHash, String igneous, bool builtInHosts
});




}
/// @nodoc
class __$EhSettingStateCopyWithImpl<$Res>
    implements _$EhSettingStateCopyWith<$Res> {
  __$EhSettingStateCopyWithImpl(this._self, this._then);

  final _EhSettingState _self;
  final $Res Function(_EhSettingState) _then;

/// Create a copy of EhSettingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? site = null,Object? ipbMemberId = null,Object? ipbPassHash = null,Object? igneous = null,Object? builtInHosts = null,}) {
  return _then(_EhSettingState(
site: null == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as String,ipbMemberId: null == ipbMemberId ? _self.ipbMemberId : ipbMemberId // ignore: cast_nullable_to_non_nullable
as String,ipbPassHash: null == ipbPassHash ? _self.ipbPassHash : ipbPassHash // ignore: cast_nullable_to_non_nullable
as String,igneous: null == igneous ? _self.igneous : igneous // ignore: cast_nullable_to_non_nullable
as String,builtInHosts: null == builtInHosts ? _self.builtInHosts : builtInHosts // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
