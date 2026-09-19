import 'package:equatable/equatable.dart';

class RahbarUserEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? schoolId;
  final String? schoolName;
  final String token;

  const RahbarUserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.schoolId,
    this.schoolName,
    required this.token,
  });

  @override
  List<Object?> get props => [id, email, token];
}

class RahbarDashboardEntity extends Equatable {
  final int totalStaff;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int lateCount;
  final int unreviewedArizalarCount;
  final int hozirIchkarida;
  final double foiz;
  final List<Map<String, dynamic>> bolimlar;
  final List<Map<String, dynamic>> kechikkanlar;
  final List<Map<String, dynamic>> yangilarArizalar;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? malumot;

  const RahbarDashboardEntity({
    required this.totalStaff,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
    required this.lateCount,
    required this.unreviewedArizalarCount,
    this.hozirIchkarida = 0,
    this.foiz = 0.0,
    this.bolimlar = const [],
    this.kechikkanlar = const [],
    this.yangilarArizalar = const [],
    this.user,
    this.malumot,
  });

  @override
  List<Object?> get props => [
    totalStaff,
    presentCount,
    absentCount,
    leaveCount,
    lateCount,
    unreviewedArizalarCount,
    hozirIchkarida,
    foiz,
    user,
  ];
}

class RahbarStaffAttendanceEntity extends Equatable {
  final int id;
  final String name;
  final String bolim;
  final String lavozim;
  final String? checkIn;
  final String? checkOut;
  final String status;
  final int ishlaganDaqiqa;
  final String? delay;
  final String? photo;
  final double? lat;
  final double? lng;
  final int? filialId;
  final String? filialName;

  const RahbarStaffAttendanceEntity({
    required this.id,
    required this.name,
    required this.bolim,
    required this.lavozim,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.ishlaganDaqiqa = 0,
    this.delay,
    this.photo,
    this.lat,
    this.lng,
    this.filialId,
    this.filialName,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    checkIn,
    checkOut,
    status,
    photo,
    lat,
    lng,
  ];
}

class RahbarPayrollItemEntity extends Equatable {
  final int id;
  final String name;
  final String bolim;
  final String lavozim;
  final double maosh;
  final String tolovTuri;
  final int kelganKun;
  final double jamiIshlanganSoat;

  const RahbarPayrollItemEntity({
    required this.id,
    required this.name,
    required this.bolim,
    required this.lavozim,
    required this.maosh,
    required this.tolovTuri,
    required this.kelganKun,
    required this.jamiIshlanganSoat,
  });

  @override
  List<Object?> get props => [id, name, maosh, tolovTuri];
}

class RahbarArizaEntity extends Equatable {
  final int id;
  final String xodimName;
  final String turiNomi;
  final String fromDate;
  final String toDate;
  final int kunlar;
  final String status;
  final String statusNomi;
  final String? izoh;

  const RahbarArizaEntity({
    required this.id,
    required this.xodimName,
    required this.turiNomi,
    required this.fromDate,
    required this.toDate,
    required this.kunlar,
    required this.status,
    required this.statusNomi,
    this.izoh,
  });

  @override
  List<Object?> get props => [id, xodimName, status];
}
