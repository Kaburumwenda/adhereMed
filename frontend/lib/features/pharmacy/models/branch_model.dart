import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch_model.freezed.dart';
part 'branch_model.g.dart';

@freezed
abstract class Branch with _$Branch {
  // ignore: invalid_annotation_target
  const factory Branch({
    required int id,
    required String name,
    @Default('') String address,
    @Default('') String phone,
    @Default('') String email,
    @JsonKey(name: 'is_main') @Default(false) bool isMain,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _Branch;

  factory Branch.fromJson(Map<String, dynamic> json) => _$BranchFromJson(json);
}
