// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: (json['id'] as num).toInt(),
  email: json['email'] as String,
  phone: json['phone'] as String? ?? '',
  firstName: json['first_name'] as String? ?? '',
  lastName: json['last_name'] as String? ?? '',
  role: json['role'] as String? ?? '',
  tenant: (json['tenant'] as num?)?.toInt(),
  tenantName: json['tenant_name'] as String?,
  tenantType: json['tenant_type'] as String?,
  tenantSchema: json['tenant_schema'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  dateJoined: json['date_joined'] as String?,
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'phone': instance.phone,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'role': instance.role,
      'tenant': instance.tenant,
      'tenant_name': instance.tenantName,
      'tenant_type': instance.tenantType,
      'tenant_schema': instance.tenantSchema,
      'is_active': instance.isActive,
      'date_joined': instance.dateJoined,
    };
