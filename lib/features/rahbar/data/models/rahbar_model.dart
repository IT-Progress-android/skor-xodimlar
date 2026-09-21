import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';


class RahbarUserModel extends RahbarUserEntity {
  const RahbarUserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.schoolId,
    super.schoolName,
    required super.token,
  });

  factory RahbarUserModel.fromJson(Map<String, dynamic> json, String token) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return RahbarUserModel(
      id:
          (user['id'] as num?)?.toInt() ??
          int.tryParse(user['id']?.toString() ?? '') ??
          0,
      name: (user['name'] ?? user['full_name'] ?? '').toString(),
      email: (user['email'] ?? user['login'] ?? '').toString(),
      role: (user['role'] ?? 'school_admin').toString(),
      schoolId:
          (user['school_id'] as num?)?.toInt() ??
          int.tryParse(user['school_id']?.toString() ?? ''),
      schoolName: user['school_name']?.toString(),
      token: token,
    );
  }
}

class RahbarDashboardModel extends RahbarDashboardEntity {
  const RahbarDashboardModel({
    required super.totalStaff,
    required super.presentCount,
    required super.absentCount,
    required super.leaveCount,
    required super.lateCount,
    required super.unreviewedArizalarCount,
    super.hozirIchkarida,
    super.foiz,
    super.bolimlar,
    super.kechikkanlar,
    super.yangilarArizalar,
    super.user,
    super.malumot,
  });

  factory RahbarDashboardModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> rootData = json;
    if (json['data'] is Map) {
      rootData = Map<String, dynamic>.from(json['data'] as Map);
    }

    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    // PDF §1.2 response parsing
    final hisobMap = (rootData['hisob'] is Map)
        ? Map<String, dynamic>.from(rootData['hisob'] as Map)
        : ((rootData['summary'] is Map)
              ? Map<String, dynamic>.from(rootData['summary'] as Map)
              : rootData);

    final arizalarMap = (rootData['arizalar'] is Map)
        ? Map<String, dynamic>.from(rootData['arizalar'] as Map)
        : <String, dynamic>{};

    final arizalarHisob = (arizalarMap['hisob'] is Map)
        ? Map<String, dynamic>.from(arizalarMap['hisob'] as Map)
        : <String, dynamic>{};

    final unreviewedCount = parseInt(
      arizalarHisob['kutilmoqda'] ??
          arizalarMap['kutilmoqda'] ??
          rootData['unreviewed_arizalar_count'] ??
          rootData['bildirishnoma']?['arizalar'],
    );

    final bolimList = (rootData['bolimlar'] is List)
        ? List<Map<String, dynamic>>.from(
            (rootData['bolimlar'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];

    final kechikkanList = (rootData['kechikkanlar'] is List)
        ? List<Map<String, dynamic>>.from(
            (rootData['kechikkanlar'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];

    final yangiArizalar = (arizalarMap['yangilar'] is List)
        ? List<Map<String, dynamic>>.from(
            (arizalarMap['yangilar'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];

    final userMap = (rootData['user'] is Map)
        ? Map<String, dynamic>.from(rootData['user'] as Map)
        : null;

    final malumotMap = (rootData['malumot'] is Map)
        ? Map<String, dynamic>.from(rootData['malumot'] as Map)
        : null;

    return RahbarDashboardModel(
      totalStaff: parseInt(
        hisobMap['jami_xodim'] ??
            hisobMap['total_staff'] ??
            hisobMap['total'] ??
            hisobMap['jami_xodimlar'],
      ),
      presentCount: parseInt(
        hisobMap['kelgan'] ?? hisobMap['present_count'] ?? hisobMap['present'],
      ),
      absentCount: parseInt(
        hisobMap['kelmagan'] ?? hisobMap['absent_count'] ?? hisobMap['absent'],
      ),
      leaveCount: parseInt(
        hisobMap['arizali'] ?? hisobMap['leave_count'] ?? hisobMap['leave'],
      ),
      lateCount: parseInt(
        hisobMap['kechikkan'] ?? hisobMap['late_count'] ?? hisobMap['late'],
      ),
      unreviewedArizalarCount: unreviewedCount,
      hozirIchkarida: parseInt(hisobMap['hozir_ichkarida']),
      foiz: parseDouble(hisobMap['foiz']),
      bolimlar: bolimList,
      kechikkanlar: kechikkanList,
      yangilarArizalar: yangiArizalar,
      user: userMap,
      malumot: malumotMap,
    );
  }
}

class RahbarStaffAttendanceModel extends RahbarStaffAttendanceEntity {
  const RahbarStaffAttendanceModel({
    required super.id,
    required super.name,
    required super.bolim,
    required super.lavozim,
    super.checkIn,
    super.checkOut,
    required super.status,
    super.ishlaganDaqiqa,
    super.delay,
    super.photo,
    super.lat,
    super.lng,
    super.filialId,
    super.filialName,
  });

  factory RahbarStaffAttendanceModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    String? formatPhotoUrl(dynamic rawPhoto) {
      if (rawPhoto == null) return null;
      final str = rawPhoto.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
      if (str.startsWith('/')) {
        return 'https://app.skor.uz$str';
      }
      return 'https://app.skor.uz/$str';
    }

    final rawCheckIn =
        json['check_in'] ??
        json['checkIn'] ??
        json['kirish'] ??
        json['kirish_vaqti'] ??
        json['kelgan_vaqti'] ??
        json['in'] ??
        json['kelgan'];

    final rawCheckOut =
        json['check_out'] ??
        json['checkOut'] ??
        json['chiqish'] ??
        json['chiqish_vaqti'] ??
        json['ketgan_vaqti'] ??
        json['out'] ??
        json['ketgan'];

    final rawDelay =
        json['delay'] ??
        json['kechikish'] ??
        json['kechikish_daqiqa'] ??
        json['kechikkan'] ??
        json['late_minutes'] ??
        json['late_time'] ??
        json['late'];

    final rawPhoto =
        json['photo'] ??
        json['avatar'] ??
        json['image'] ??
        json['photo_url'] ??
        json['rasm'] ??
        json['image_url'] ??
        json['user_photo'];

    int? parseNullableInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    int? parsedFilialId;
    String? parsedFilialName;

    if (json['filial'] is Map) {
      final fMap = Map<String, dynamic>.from(json['filial'] as Map);
      parsedFilialId = parseNullableInt(
        fMap['id'] ?? fMap['filial_id'] ?? fMap['location_id'],
      );
      parsedFilialName =
          fMap['nom']?.toString() ??
          fMap['name']?.toString() ??
          fMap['title']?.toString();
    } else if (json['branch'] is Map) {
      final bMap = Map<String, dynamic>.from(json['branch'] as Map);
      parsedFilialId = parseNullableInt(
        bMap['id'] ?? bMap['branch_id'] ?? bMap['location_id'],
      );
      parsedFilialName =
          bMap['nom']?.toString() ??
          bMap['name']?.toString() ??
          bMap['title']?.toString();
    } else if (json['location'] is Map) {
      final lMap = Map<String, dynamic>.from(json['location'] as Map);
      parsedFilialId = parseNullableInt(lMap['id'] ?? lMap['location_id']);
      parsedFilialName =
          lMap['nom']?.toString() ??
          lMap['name']?.toString() ??
          lMap['title']?.toString();
    } else {
      parsedFilialId = parseNullableInt(
        json['filial_id'] ??
            json['location_id'] ??
            json['branch_id'] ??
            json['poliklinika_id'],
      );
      parsedFilialName =
          json['filial']?.toString() ??
          json['filial_nomi']?.toString() ??
          json['branch_name']?.toString() ??
          json['location_name']?.toString() ??
          json['branch']?.toString() ??
          json['tashkilot']?.toString();
    }

    return RahbarStaffAttendanceModel(
      id: parseInt(json['id'] ?? json['staff_id'] ?? json['user_id']),
      name: (json['name'] ?? json['xodim_name'] ?? json['full_name'] ?? '')
          .toString(),
      bolim: (json['bolim'] ?? json['department'] ?? '').toString(),
      lavozim: (json['lavozim'] ?? json['position'] ?? '').toString(),
      checkIn: rawCheckIn?.toString(),
      checkOut: rawCheckOut?.toString(),
      status: BackendTextMapper.translateStatus(
        (json['status'] ??
                json['holat_nomi'] ??
                json['status_nomi'] ??
                json['holat'] ??
                AppLocalizations.trStatic('status_kelmagan'))
            .toString(),
      ),
      ishlaganDaqiqa: parseInt(
        json['ishlagan_daqiqa'] ??
            json['minutes_worked'] ??
            json['ishlagan_vaqt'],
      ),
      delay: BackendTextMapper.sanitizeDelay(rawDelay?.toString()),
      photo: formatPhotoUrl(rawPhoto),
      lat: parseDouble(json['lat'] ?? json['latitude'] ?? json['location_lat']),
      lng: parseDouble(
        json['lng'] ?? json['longitude'] ?? json['location_lng'],
      ),
      filialId: parsedFilialId,
      filialName: parsedFilialName,
    );
  }
}

class RahbarPayrollItemModel extends RahbarPayrollItemEntity {
  const RahbarPayrollItemModel({
    required super.id,
    required super.name,
    required super.bolim,
    required super.lavozim,
    required super.maosh,
    required super.tolovTuri,
    required super.kelganKun,
    required super.jamiIshlanganSoat,
  });

  factory RahbarPayrollItemModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return RahbarPayrollItemModel(
      id: parseInt(json['id']),
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      bolim: (json['bolim'] ?? json['department'] ?? '').toString(),
      lavozim: (json['lavozim'] ?? json['position'] ?? '').toString(),
      maosh: parseDouble(json['maosh'] ?? json['salary']),
      tolovTuri: (json['tolov_turi'] ?? json['payment_type'] ?? 'oylik')
          .toString(),
      kelganKun: parseInt(json['kelgan_kun'] ?? json['days_present']),
      jamiIshlanganSoat: parseDouble(
        json['jami_ishlangan_soat'] ?? json['total_hours'],
      ),
    );
  }
}

class RahbarArizaModel extends RahbarArizaEntity {
  const RahbarArizaModel({
    required super.id,
    required super.xodimName,
    required super.turiNomi,
    required super.fromDate,
    required super.toDate,
    required super.kunlar,
    required super.status,
    required super.statusNomi,
    super.izoh,
  });

  factory RahbarArizaModel.fromJson(Map<String, dynamic> json) {
    final xodim = json['xodim'] is Map
        ? Map<String, dynamic>.from(json['xodim'] as Map)
        : null;
    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 1;
      return 1;
    }

    return RahbarArizaModel(
      id: parseInt(json['id']),
      xodimName:
          (xodim != null
                  ? (xodim['name'] ?? xodim['full_name'])
                  : (json['xodim_name'] ?? json['name'] ?? ''))
              .toString(),
      turiNomi: (json['turi_nomi'] ?? json['turi'] ?? json['type_name'] ?? '')
          .toString(),
      fromDate:
          (json['from_date'] ?? json['fromDate'] ?? json['start_date'] ?? '')
              .toString(),
      toDate: (json['to_date'] ?? json['toDate'] ?? json['end_date'] ?? '')
          .toString(),
      kunlar: parseInt(json['kunlar'] ?? json['days']),
      status: (json['status'] ?? 'kutilmoqda').toString(),
      statusNomi: BackendTextMapper.translateArizaStatus(
        (json['status_nomi'] ??
                json['status'] ??
                AppLocalizations.trStatic('status_kutilmoqda'))
            .toString(),
      ),
      izoh: json['izoh']?.toString() ?? json['reason']?.toString(),
    );
  }
}
