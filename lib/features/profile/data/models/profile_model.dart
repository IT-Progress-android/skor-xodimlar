import 'package:skore_hodimlar/features/profile/domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.phonePretty,
    super.tashkilot,
    super.lavozim,
    super.boLim,
    super.smena,
    super.workDays,
    super.personCode,
    super.status,
    super.photoUrl,
    super.hasPhoto,
    super.hasFace,
    super.editable,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> data;
    if (j.containsKey('profile') && j['profile'] is Map) {
      data = Map<String, dynamic>.from(j['profile'] as Map);
    } else if (j.containsKey('data') && j['data'] is Map) {
      data = Map<String, dynamic>.from(j['data'] as Map);
    } else {
      data = j;
    }

    final rawName = data['name']?.toString() ?? '';
    final firstName = data['first_name']?.toString() ?? '';
    final lastName = data['last_name']?.toString() ?? '';
    final fullName = rawName.isNotEmpty
        ? rawName
        : '$firstName $lastName'.trim();

    return ProfileModel(
      id: (data['id'] as num?)?.toInt() ?? 0,
      name: fullName.isNotEmpty ? fullName : 'Xodim',
      phone: data['phone']?.toString() ?? '',
      phonePretty:
          data['phone_pretty']?.toString() ?? (data['phone']?.toString() ?? ''),
      tashkilot: data['tashkilot']?.toString(),
      lavozim: data['lavozim']?.toString(),
      boLim: data['bo_lim']?.toString(),
      smena: data['smena']?.toString(),
      workDays: ((data['work_days'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      personCode: data['person_code']?.toString(),
      status: data['status']?.toString() ?? 'active',
      photoUrl: data['photo_url']?.toString(),
      hasPhoto:
          data['has_photo'] == true ||
          (data['photo_url']?.toString().isNotEmpty ?? false),
      hasFace: data['has_face'] == true,
      editable: ((data['editable'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
