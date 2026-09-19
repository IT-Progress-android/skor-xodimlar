import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String phonePretty;
  final String? tashkilot;
  final String? lavozim;
  final String? boLim;
  final String? smena;
  final List<String> workDays;
  final String? personCode;
  final String status;
  final String? photoUrl;

  /// Serverda etalon rasm bor-yo'qligi (`has_photo`).
  /// Yuz tekshiruvi aynan shu rasmga solishtiriladi.
  final bool hasPhoto;

  /// Oldindan hisoblangan yuz VEKTORI bor-yo'qligi (`has_face`).
  /// Bu rasm bor-yo'qligini bildirmaydi — vektorsiz ham rasm bo'yicha
  /// tekshirish ishlaydi.
  final bool hasFace;
  final List<String> editable;

  const ProfileEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.phonePretty,
    this.tashkilot,
    this.lavozim,
    this.boLim,
    this.smena,
    this.workDays = const [],
    this.personCode,
    this.status = 'active',
    this.photoUrl,
    this.hasPhoto = false,
    this.hasFace = false,
    this.editable = const [],
  });

  bool get canEditPhone => editable.contains('phone');
  bool get canEditPhoto => editable.contains('photo');

  @override
  List<Object?> get props => [id, phone, photoUrl, editable];
}
