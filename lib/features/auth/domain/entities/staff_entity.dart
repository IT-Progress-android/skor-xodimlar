class StaffEntity {
  final int id;
  final String name;
  final String? phone;
  final String? tashkilot;
  final String? lavozim;
  final String? personCode;

  /// Serverdagi `has_face_profile` — xodimning yuz vektori bor-yo'qligi.
  /// Eski backend bu maydonni yubormaydi, shuning uchun null bo'lishi mumkin.
  final bool? hasFaceProfileFlag;

  StaffEntity({
    required this.id,
    required this.name,
    this.phone,
    this.tashkilot,
    this.lavozim,
    this.personCode,
    this.hasFaceProfileFlag,
  });

  /// Yuz tekshiruvi uchun etalon rasm mavjudmi.
  ///
  /// Avval serverning `has_face_profile` maydoniga qaraymiz. U yo'q bo'lsa
  /// (eski backend) `person_code`ga qaytamiz — lekin bu ishonchsiz: backend
  /// tekshiruviga ko'ra `person_code` terminal raqami bo'lib, yuz vektori
  /// butunlay boshqa jadvalda saqlanadi.
  bool get hasFaceProfile =>
      hasFaceProfileFlag ?? (personCode != null && personCode!.isNotEmpty);
}
