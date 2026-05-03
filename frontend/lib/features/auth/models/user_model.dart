import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class User with _$User {
  // ignore: invalid_annotation_target
  const factory User({
    required int id,
    required String email,
    @Default('') String phone,
    @JsonKey(name: 'first_name') @Default('') String firstName,
    @JsonKey(name: 'last_name') @Default('') String lastName,
    @Default('') String role,
    int? tenant,
    @JsonKey(name: 'tenant_name') String? tenantName,
    @JsonKey(name: 'tenant_type') String? tenantType,
    @JsonKey(name: 'tenant_schema') String? tenantSchema,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'date_joined') String? dateJoined,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
