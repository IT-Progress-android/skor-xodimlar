import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';


class CheckTimeModel extends CheckTimeEntity {
  const CheckTimeModel({super.time, super.device});

  factory CheckTimeModel.fromJson(Map<String, dynamic> json) {
    return CheckTimeModel(
      time: json['time'] as String?,
      device: json['device'] as String?,
    );
  }
}

class AttendanceEventModel extends AttendanceEventEntity {
  const AttendanceEventModel({
    required super.direction,
    required super.label,
    required super.time,
    super.timeFull,
    super.eventTime,
    super.device,
  });

  factory AttendanceEventModel.fromJson(Map<String, dynamic> json) {
    return AttendanceEventModel(
      direction: (json['direction'] ?? 'IN').toString(),
      label:
          (json['label'] ?? (json['direction'] == 'OUT' ? 'Chiqdi' : 'Kirdi'))
              .toString(),
      time: (json['time'] ?? '').toString(),
      timeFull: json['time_full']?.toString(),
      eventTime: json['event_time']?.toString(),
      device: json['device']?.toString(),
    );
  }
}

class TodayAttendanceModel extends TodayAttendanceEntity {
  const TodayAttendanceModel({
    required super.date,
    required super.staffName,
    required super.phone,
    required super.personCode,
    required super.smena,
    required super.smenaStart,
    CheckTimeModel? super.checkIn,
    CheckTimeModel? super.checkOut,
    super.delay,
    required super.eventsCount,
    super.next,
    super.inside,
    super.counts,
    super.sessions,
    super.events,
    super.pendingRequests,
  });

  factory TodayAttendanceModel.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] is Map
        ? Map<String, dynamic>.from(json['staff'] as Map)
        : const {};
    final today = json['today'] is Map
        ? Map<String, dynamic>.from(json['today'] as Map)
        : const {};
    final reports = json['reports'] is List
        ? json['reports'] as List
        : const [];
    final first = reports.isNotEmpty && reports.first is Map
        ? Map<String, dynamic>.from(reports.first as Map)
        : const {};

    CheckTimeModel? timeFrom(dynamic todayVal, dynamic legacyVal) {
      if (todayVal != null) return CheckTimeModel(time: todayVal.toString());
      if (legacyVal is Map) {
        return CheckTimeModel.fromJson(Map<String, dynamic>.from(legacyVal));
      }
      return null;
    }

    // Rahbar tasdig'ini kutayotgan so'rovlar (yangi backend qo'shdi).
    // Eski backend bu maydonni yubormaydi -> bo'sh ro'yxat.
    final rawPending = json['pending_requests'] ?? today['pending_requests'];
    final parsedPending = rawPending is List
        ? rawPending
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => PendingAttendanceRequestEntity(
                  id: (e['id'] as num?)?.toInt() ?? 0,
                  direction: (e['direction'] ?? 'IN').toString(),
                  createdAt: (e['yaratilgan'] ?? e['created_at'])?.toString(),
                ),
              )
              .toList()
        : const <PendingAttendanceRequestEntity>[];

    final insideVal =
        (today['inside'] ?? json['inside']) == true ||
        (today['next'] ?? json['next']) == 'ketdim';

    List<AttendanceSessionEntity> parsedSessions = [];
    if (first['sessions'] is List) {
      parsedSessions = (first['sessions'] as List)
          .map(
            (e) => AttendanceSessionModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } else if (today['sessions'] is List) {
      parsedSessions = (today['sessions'] as List)
          .map(
            (e) => AttendanceSessionModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    List<AttendanceEventEntity> parsedEvents = [];
    if (first['events'] is List) {
      parsedEvents = (first['events'] as List)
          .map(
            (e) => AttendanceEventModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } else if (today['events'] is List) {
      parsedEvents = (today['events'] as List)
          .map(
            (e) => AttendanceEventModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    AttendanceCountsEntity parsedCounts = const AttendanceCountsEntity();
    if (first['counts'] is Map) {
      parsedCounts = AttendanceCountsModel.fromJson(
        Map<String, dynamic>.from(first['counts'] as Map),
      );
    } else if (today['counts'] is Map) {
      parsedCounts = AttendanceCountsModel.fromJson(
        Map<String, dynamic>.from(today['counts'] as Map),
      );
    }

    final String parsedStaffName;
    if (staff['full_name'] != null &&
        staff['full_name'].toString().trim().isNotEmpty) {
      parsedStaffName = staff['full_name'].toString().trim();
    } else if (staff['first_name'] != null &&
        staff['first_name'].toString().trim().isNotEmpty) {
      final last = staff['last_name']?.toString().trim() ?? '';
      parsedStaffName = '$last ${staff['first_name']}'.trim();
    } else if (staff['name'] != null &&
        staff['name'].toString().trim().isNotEmpty) {
      parsedStaffName = staff['name'].toString().trim();
    } else if (json['full_name'] != null &&
        json['full_name'].toString().trim().isNotEmpty) {
      parsedStaffName = json['full_name'].toString().trim();
    } else if (json['staff_name'] != null &&
        json['staff_name'].toString().trim().isNotEmpty) {
      parsedStaffName = json['staff_name'].toString().trim();
    } else {
      parsedStaffName = (json['name'] ?? '').toString().trim();
    }

    return TodayAttendanceModel(
      date: (first['date'] ?? json['date'] ?? '').toString(),
      staffName: parsedStaffName,
      phone: (json['phone'] ?? '').toString(),
      personCode: (staff['person_code'] ?? json['person_code'] ?? '')
          .toString(),
      smena: (staff['smena'] ?? json['smena'] ?? '').toString(),
      smenaStart: (staff['smena_start'] ?? json['smena_start'] ?? '')
          .toString(),
      checkIn: timeFrom(today['check_in'], json['check_in']),
      checkOut: timeFrom(today['check_out'], json['check_out']),
      delay: BackendTextMapper.sanitizeDelay(
        (first['delay'] ?? json['delay'])?.toString(),
      ),
      eventsCount: (json['events_count'] as int?) ?? reports.length,
      next: (today['next'] ?? json['next'])?.toString(),
      inside: insideVal,
      counts: parsedCounts,
      sessions: parsedSessions,
      events: parsedEvents,
      pendingRequests: parsedPending,
    );
  }
}

class ArizaInfoModel extends ArizaInfoEntity {
  const ArizaInfoModel({
    required super.id,
    required super.turi,
    required super.nomi,
    super.izoh,
  });

  factory ArizaInfoModel.fromJson(Map<String, dynamic> json) {
    return ArizaInfoModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      turi: (json['turi'] ?? '').toString(),
      nomi: BackendTextMapper.translateArizaTuriNomi(
        (json['nomi'] ?? json['turi_nomi'] ?? '').toString(),
      ),
      izoh: json['izoh']?.toString(),
    );
  }
}

class AttendanceSessionModel extends AttendanceSessionEntity {
  const AttendanceSessionModel({
    super.checkIn,
    super.checkOut,
    super.checkInFull,
    super.checkOutFull,
    super.minutes,
    super.complete,
    super.deviceIn,
    super.deviceOut,
    super.rawIn,
    super.rawOut,
    super.note,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      checkIn: json['check_in']?.toString(),
      checkOut: json['check_out']?.toString(),
      checkInFull: json['check_in_full']?.toString(),
      checkOutFull: json['check_out_full']?.toString(),
      minutes: (json['minutes'] as num?)?.toInt(),
      complete: json['complete'] != false,
      deviceIn: json['device_in']?.toString(),
      deviceOut: json['device_out']?.toString(),
      rawIn: (json['raw_in'] as num?)?.toInt() ?? 1,
      rawOut: (json['raw_out'] as num?)?.toInt() ?? 1,
      note: json['note']?.toString(),
    );
  }
}

class AttendanceCountsModel extends AttendanceCountsEntity {
  const AttendanceCountsModel({
    super.events,
    super.inCount,
    super.outCount,
    super.sessions,
    super.open,
  });

  factory AttendanceCountsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceCountsModel(
      events: (json['events'] as num?)?.toInt() ?? 0,
      inCount: (json['in'] as num?)?.toInt() ?? 0,
      outCount: (json['out'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceReportModel extends AttendanceReportEntity {
  const AttendanceReportModel({
    required super.date,
    super.weekday,
    super.checkIn,
    super.checkOut,
    super.delay,
    super.lateMinutes,
    super.workedMinutes,
    super.spanMinutes,
    required super.status,
    super.ariza,
    super.sessions,
    super.events,
    super.counts,
  });

  factory AttendanceReportModel.fromJson(Map<String, dynamic> json) {
    String parseDate(Map<String, dynamic> map) {
      final raw =
          (map['date'] ??
                  map['sana'] ??
                  map['date_formatted'] ??
                  map['day'] ??
                  map['event_time'] ??
                  map['created_at'] ??
                  map['time'] ??
                  '')
              .toString()
              .trim();

      if (raw.isEmpty) return '';
      if (raw.contains(' ')) return raw.split(' ').first;
      if (raw.contains('T')) return raw.split('T').first;
      return raw;
    }

    String? parseTime(dynamic value) {
      if (value == null) return null;
      if (value is Map) {
        final t =
            (value['time'] ??
                    value['check_in'] ??
                    value['check_out'] ??
                    value['created_at'])
                ?.toString();
        return (t != null && t.isNotEmpty) ? t : null;
      }
      final str = value.toString().trim();
      return str.isNotEmpty ? str : null;
    }

    final dateStr = parseDate(json);
    final weekdayStr = BackendTextMapper.translateWeekday(
      (json['weekday'] ?? json['hafta_kuni'] ?? json['kun'])?.toString(),
    );
    final checkInStr = parseTime(
      json['check_in'] ?? json['checkIn'] ?? json['in'] ?? json['kelgan'],
    );
    final checkOutStr = parseTime(
      json['check_out'] ?? json['checkOut'] ?? json['out'] ?? json['ketgan'],
    );
    final delayStr = BackendTextMapper.sanitizeDelay(
      (json['delay'] ?? json['kechikish'])?.toString(),
    );

    final lateM = (json['late_minutes'] as num?)?.toInt();
    final workedM = (json['worked_minutes'] as num?)?.toInt();
    final spanM = (json['span_minutes'] as num?)?.toInt();

    // Backend status → ilovaning tiliga o'giramiz
    final rawStatus =
        (json['status'] ??
                json['status_nomi'] ??
                json['holat'] ??
                (checkInStr != null
                    ? AppLocalizations.trStatic('status_kelgan')
                    : AppLocalizations.trStatic('status_kelmagan')))
            .toString();
    final statusStr = BackendTextMapper.translateStatus(rawStatus);


    ArizaInfoModel? arizaModel;
    if (json['ariza'] is Map) {
      arizaModel = ArizaInfoModel.fromJson(
        Map<String, dynamic>.from(json['ariza'] as Map),
      );
    }

    List<AttendanceSessionEntity> parsedSessions = [];
    if (json['sessions'] is List) {
      parsedSessions = (json['sessions'] as List)
          .map(
            (e) => AttendanceSessionModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    List<AttendanceEventEntity> parsedEvents = [];
    if (json['events'] is List) {
      parsedEvents = (json['events'] as List)
          .map(
            (e) => AttendanceEventModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    AttendanceCountsEntity parsedCounts = const AttendanceCountsEntity();
    if (json['counts'] is Map) {
      parsedCounts = AttendanceCountsModel.fromJson(
        Map<String, dynamic>.from(json['counts'] as Map),
      );
    }

    return AttendanceReportModel(
      date: dateStr,
      weekday: weekdayStr,
      checkIn: checkInStr,
      checkOut: checkOutStr,
      delay: delayStr,
      lateMinutes: lateM,
      workedMinutes: workedM,
      spanMinutes: spanM,
      status: statusStr,
      ariza: arizaModel,
      sessions: parsedSessions,
      events: parsedEvents,
      counts: parsedCounts,
    );
  }
}

class CheckLocationModel extends CheckLocationEntity {
  const CheckLocationModel({
    required super.status,
    required super.message,
    super.distance,
    super.allowed,
    super.filial,
    super.filialId,
    super.distanceM,
    super.allowedM,
    super.eventTime,
    super.duplicate,
    super.requestId,
  });

  factory CheckLocationModel.fromJson(Map<String, dynamic> json) {
    int? parseFilialId(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    return CheckLocationModel(
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      distance: json['distance']?.toString(),
      allowed: json['allowed']?.toString(),
      filial: json['filial']?.toString(),
      filialId: parseFilialId(json['filial_id'] ?? json['filialId']),
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      allowedM: (json['allowed_m'] as num?)?.toDouble(),
      eventTime: json['event_time']?.toString(),
      duplicate: json['duplicate'] == true,
      requestId: parseFilialId(json['request_id']),
    );
  }
}
