import 'package:skore_hodimlar/features/auth/domain/entities/staff_entity.dart';

class StaffModel extends StaffEntity {
  StaffModel({
    required super.id,
    required super.name,
    super.phone,
    super.tashkilot,
    super.lavozim,
    super.personCode,
    super.hasFaceProfileFlag,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      phone: json['phone'] as String?,
      tashkilot: json['tashkilot'] as String?,
      lavozim: json['lavozim'] as String?,
      personCode: json['person_code'] as String?,
      hasFaceProfileFlag: json['has_face_profile'] as bool?,
    );
  }
}
