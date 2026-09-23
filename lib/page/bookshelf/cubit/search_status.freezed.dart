// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchStatusState {

 String get keyword; String get sort; List<String> get sources; ShelfGroupMode get groupMode;
/// Create a copy of SearchStatusState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchStatusStateCopyWith<SearchStatusState> get copyWith => _$SearchStatusStateCopyWithImpl<SearchStatusState>(this as SearchStatusState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SearchStatusState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchStatusState&&(identical(other.keyword, _this.keyword) || other.keyword == _this.keyword)&&(identical(other.sort, _this.sort) || other.sort == _this.sort)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&(identical(other.groupMode, _this.groupMode) || other.groupMode == _this.groupMode));
}


@override
int get hashCode {
  final _this = this as SearchStatusState;
  return Object.hash(runtimeType,_this.keyword,_this.sort,const DeepCollectionEquality().hash(_this.sources),_this.groupMode);
}

@override
String toString() {
  final _this = this as SearchStatusState;
  return 'SearchStatusState(keyword: ${_this.keyword}, sort: ${_this.sort}, sources: ${_this.sources}, groupMode: ${_this.groupMode})';
}


}

/// @nodoc
abstract mixin class $SearchStatusStateCopyWith<$Res>  {
  factory $SearchStatusStateCopyWith(SearchStatusState value, $Res Function(SearchStatusState) _then) = _$SearchStatusStateCopyWithImpl;
@useResult
$Res call({
 String keyword, String sort, List<String> sources, ShelfGroupMode groupMode
});




}
/// @nodoc
class _$SearchStatusStateCopyWithImpl<$Res>
    implements $SearchStatusStateCopyWith<$Res> {
  _$SearchStatusStateCopyWithImpl(this._self, this._then);

  final SearchStatusState _self;
  final $Res Function(SearchStatusState) _then;

/// Create a copy of SearchStatusState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? keyword = null,Object? sort = null,Object? sources = null,Object? groupMode = null,}) {
  return _then(SearchStatusState(
keyword: null == keyword ? _self.keyword : keyword // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<String>,groupMode: null == groupMode ? _self.groupMode : groupMode // ignore: cast_nullable_to_non_nullable
as ShelfGroupMode,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchStatusState].
extension SearchStatusStatePatterns on SearchStatusState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchStatusState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchStatusState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchStatusState value)  $default,){
final _that = this;
switch (_that) {
case _SearchStatusState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchStatusState value)?  $default,){
final _that = this;
switch (_that) {
case _SearchStatusState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String keyword,  String sort,  List<String> sources,  ShelfGroupMode groupMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchStatusState() when $default != null:
return $default(_that.keyword,_that.sort,_that.sources,_that.groupMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String keyword,  String sort,  List<String> sources,  ShelfGroupMode groupMode)  $default,) {final _that = this;
switch (_that) {
case _SearchStatusState():
return $default(_that.keyword,_that.sort,_that.sources,_that.groupMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String keyword,  String sort,  List<String> sources,  ShelfGroupMode groupMode)?  $default,) {final _that = this;
switch (_that) {
case _SearchStatusState() when $default != null:
return $default(_that.keyword,_that.sort,_that.sources,_that.groupMode);case _:
  return null;

}
}

}

/// @nodoc


class _SearchStatusState implements SearchStatusState {
  const _SearchStatusState({this.keyword = "", this.sort = "dd",  List<String> sources = const <String>[], this.groupMode = ShelfGroupMode.none}): _sources = sources;
  

@override@JsonKey() final  String keyword;
@override@JsonKey() final  String sort;
 final  List<String> _sources;
@override@JsonKey() List<String> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

@override@JsonKey() final  ShelfGroupMode groupMode;

/// Create a copy of SearchStatusState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchStatusStateCopyWith<_SearchStatusState> get copyWith => __$SearchStatusStateCopyWithImpl<_SearchStatusState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchStatusState&&(identical(other.keyword, keyword) || other.keyword == keyword)&&(identical(other.sort, sort) || other.sort == sort)&&const DeepCollectionEquality().equals(other.sources, _sources)&&(identical(other.groupMode, groupMode) || other.groupMode == groupMode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,keyword,sort,const DeepCollectionEquality().hash(_sources),groupMode);
}

@override
String toString() {
    return 'SearchStatusState(keyword: $keyword, sort: $sort, sources: $sources, groupMode: $groupMode)';
}


}

/// @nodoc
abstract mixin class _$SearchStatusStateCopyWith<$Res> implements $SearchStatusStateCopyWith<$Res> {
  factory _$SearchStatusStateCopyWith(_SearchStatusState value, $Res Function(_SearchStatusState) _then) = __$SearchStatusStateCopyWithImpl;
@override @useResult
$Res call({
 String keyword, String sort, List<String> sources, ShelfGroupMode groupMode
});




}
/// @nodoc
class __$SearchStatusStateCopyWithImpl<$Res>
    implements _$SearchStatusStateCopyWith<$Res> {
  __$SearchStatusStateCopyWithImpl(this._self, this._then);

  final _SearchStatusState _self;
  final $Res Function(_SearchStatusState) _then;

/// Create a copy of SearchStatusState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? keyword = null,Object? sort = null,Object? sources = null,Object? groupMode = null,}) {
  return _then(_SearchStatusState(
keyword: null == keyword ? _self.keyword : keyword // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<String>,groupMode: null == groupMode ? _self.groupMode : groupMode // ignore: cast_nullable_to_non_nullable
as ShelfGroupMode,
  ));
}


}

// dart format on
