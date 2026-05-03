// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  int get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_name')
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_name')
  String get lastName => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  int? get tenant => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_name')
  String? get tenantName => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_type')
  String? get tenantType => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_schema')
  String? get tenantSchema => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'date_joined')
  String? get dateJoined => throw _privateConstructorUsedError;

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call({
    int id,
    String email,
    String phone,
    @JsonKey(name: 'first_name') String firstName,
    @JsonKey(name: 'last_name') String lastName,
    String role,
    int? tenant,
    @JsonKey(name: 'tenant_name') String? tenantName,
    @JsonKey(name: 'tenant_type') String? tenantType,
    @JsonKey(name: 'tenant_schema') String? tenantSchema,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'date_joined') String? dateJoined,
  });
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? phone = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? role = null,
    Object? tenant = freezed,
    Object? tenantName = freezed,
    Object? tenantType = freezed,
    Object? tenantSchema = freezed,
    Object? isActive = null,
    Object? dateJoined = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            phone: null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String,
            firstName: null == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                      as String,
            lastName: null == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            tenant: freezed == tenant
                ? _value.tenant
                : tenant // ignore: cast_nullable_to_non_nullable
                      as int?,
            tenantName: freezed == tenantName
                ? _value.tenantName
                : tenantName // ignore: cast_nullable_to_non_nullable
                      as String?,
            tenantType: freezed == tenantType
                ? _value.tenantType
                : tenantType // ignore: cast_nullable_to_non_nullable
                      as String?,
            tenantSchema: freezed == tenantSchema
                ? _value.tenantSchema
                : tenantSchema // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            dateJoined: freezed == dateJoined
                ? _value.dateJoined
                : dateJoined // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
    _$UserImpl value,
    $Res Function(_$UserImpl) then,
  ) = __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String email,
    String phone,
    @JsonKey(name: 'first_name') String firstName,
    @JsonKey(name: 'last_name') String lastName,
    String role,
    int? tenant,
    @JsonKey(name: 'tenant_name') String? tenantName,
    @JsonKey(name: 'tenant_type') String? tenantType,
    @JsonKey(name: 'tenant_schema') String? tenantSchema,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'date_joined') String? dateJoined,
  });
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
    : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? phone = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? role = null,
    Object? tenant = freezed,
    Object? tenantName = freezed,
    Object? tenantType = freezed,
    Object? tenantSchema = freezed,
    Object? isActive = null,
    Object? dateJoined = freezed,
  }) {
    return _then(
      _$UserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        phone: null == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String,
        firstName: null == firstName
            ? _value.firstName
            : firstName // ignore: cast_nullable_to_non_nullable
                  as String,
        lastName: null == lastName
            ? _value.lastName
            : lastName // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        tenant: freezed == tenant
            ? _value.tenant
            : tenant // ignore: cast_nullable_to_non_nullable
                  as int?,
        tenantName: freezed == tenantName
            ? _value.tenantName
            : tenantName // ignore: cast_nullable_to_non_nullable
                  as String?,
        tenantType: freezed == tenantType
            ? _value.tenantType
            : tenantType // ignore: cast_nullable_to_non_nullable
                  as String?,
        tenantSchema: freezed == tenantSchema
            ? _value.tenantSchema
            : tenantSchema // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        dateJoined: freezed == dateJoined
            ? _value.dateJoined
            : dateJoined // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserImpl implements _User {
  const _$UserImpl({
    required this.id,
    required this.email,
    this.phone = '',
    @JsonKey(name: 'first_name') this.firstName = '',
    @JsonKey(name: 'last_name') this.lastName = '',
    this.role = '',
    this.tenant,
    @JsonKey(name: 'tenant_name') this.tenantName,
    @JsonKey(name: 'tenant_type') this.tenantType,
    @JsonKey(name: 'tenant_schema') this.tenantSchema,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'date_joined') this.dateJoined,
  });

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final int id;
  @override
  final String email;
  @override
  @JsonKey()
  final String phone;
  @override
  @JsonKey(name: 'first_name')
  final String firstName;
  @override
  @JsonKey(name: 'last_name')
  final String lastName;
  @override
  @JsonKey()
  final String role;
  @override
  final int? tenant;
  @override
  @JsonKey(name: 'tenant_name')
  final String? tenantName;
  @override
  @JsonKey(name: 'tenant_type')
  final String? tenantType;
  @override
  @JsonKey(name: 'tenant_schema')
  final String? tenantSchema;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'date_joined')
  final String? dateJoined;

  @override
  String toString() {
    return 'User(id: $id, email: $email, phone: $phone, firstName: $firstName, lastName: $lastName, role: $role, tenant: $tenant, tenantName: $tenantName, tenantType: $tenantType, tenantSchema: $tenantSchema, isActive: $isActive, dateJoined: $dateJoined)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.tenant, tenant) || other.tenant == tenant) &&
            (identical(other.tenantName, tenantName) ||
                other.tenantName == tenantName) &&
            (identical(other.tenantType, tenantType) ||
                other.tenantType == tenantType) &&
            (identical(other.tenantSchema, tenantSchema) ||
                other.tenantSchema == tenantSchema) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.dateJoined, dateJoined) ||
                other.dateJoined == dateJoined));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    email,
    phone,
    firstName,
    lastName,
    role,
    tenant,
    tenantName,
    tenantType,
    tenantSchema,
    isActive,
    dateJoined,
  );

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(this);
  }
}

abstract class _User implements User {
  const factory _User({
    required final int id,
    required final String email,
    final String phone,
    @JsonKey(name: 'first_name') final String firstName,
    @JsonKey(name: 'last_name') final String lastName,
    final String role,
    final int? tenant,
    @JsonKey(name: 'tenant_name') final String? tenantName,
    @JsonKey(name: 'tenant_type') final String? tenantType,
    @JsonKey(name: 'tenant_schema') final String? tenantSchema,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'date_joined') final String? dateJoined,
  }) = _$UserImpl;

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  int get id;
  @override
  String get email;
  @override
  String get phone;
  @override
  @JsonKey(name: 'first_name')
  String get firstName;
  @override
  @JsonKey(name: 'last_name')
  String get lastName;
  @override
  String get role;
  @override
  int? get tenant;
  @override
  @JsonKey(name: 'tenant_name')
  String? get tenantName;
  @override
  @JsonKey(name: 'tenant_type')
  String? get tenantType;
  @override
  @JsonKey(name: 'tenant_schema')
  String? get tenantSchema;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'date_joined')
  String? get dateJoined;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
