import 'package:equatable/equatable.dart';

class CheckTimeEntity extends Equatable {
  final String? time;
  final String? device;

  const CheckTimeEntity({this.time, this.device});

  @override
  List<Object?> get props => [time, device];
}

class AttendanceEventEntity extends Equatable {
  final String direction;
  final String label;
  final String time;
  final String? timeFull;
  final String? eventTime;
  final String? device;

  const AttendanceEventEntity({
    required this.direction,
    required this.label,
    required this.time,
    this.timeFull,
    this.eventTime,
    this.device,
  });

  bool get isIn => direction.toUpperCase() == 'IN';

  @override
  List<Object?> get props => [
    direction,
    label,
    time,
    timeFull,
    eventTime,
    device,
  ];
}

class AttendanceSessionEntity extends Equatable {
  final String? checkIn;
  final String? checkOut;
  final String? checkInFull;
  final String? checkOutFull;
  final int? minutes;
  final bool complete;
  final String? deviceIn;
  final String? deviceOut;
  final int rawIn;
  final int rawOut;
  final String? note;

  const AttendanceSessionEntity({
    this.checkIn,
    this.checkOut,
    this.checkInFull,
    this.checkOutFull,
    this.minutes,
    this.complete = true,
    this.deviceIn,
    this.deviceOut,
    this.rawIn = 1,
    this.rawOut = 1,
    this.note,
  });

  @override
  List<Object?> get props => [
    checkIn,
    checkOut,
    minutes,
    complete,
    deviceIn,
    deviceOut,
    note,
  ];
}

class AttendanceCountsEntity extends Equatable {
  final int events;
  final int inCount;
  final int outCount;
  final int sessions;
  final int open;

  const AttendanceCountsEntity({
    this.events = 0,
    this.inCount = 0,
    this.outCount = 0,
    this.sessions = 0,
    this.open = 0,
  });

  @override
  List<Object?> get props => [events, inCount, outCount, sessions, open];
}

/// Rahbar tasdig'ini kutayotgan "qo'lda belgilash" so'rovi.
/// `attendance/day` javobidagi `pending_requests` massividan o'qiladi.
class PendingAttendanceRequestEntity extends Equatable {
  final int id;
  final String direction;
  final String? createdAt;

  const PendingAttendanceRequestEntity({
    required this.id,
    required this.direction,
    this.createdAt,
  });

  bool get isIn => direction.toUpperCase() == 'IN';

  @override
  List<Object?> get props => [id, direction, createdAt];
}

class TodayAttendanceEntity extends Equatable {
  final String date;
  final String staffName;
  final String phone;
  final String personCode;
  final String smena;
  final String smenaStart;
  final CheckTimeEntity? checkIn;
  final CheckTimeEntity? checkOut;
  final String? delay;
  final int eventsCount;
  final String? next;
  final bool inside;
  final AttendanceCountsEntity counts;
  final List<AttendanceSessionEntity> sessions;
  final List<AttendanceEventEntity> events;

  /// Rahbar tasdig'ini kutayotgan so'rovlar (yuz tekshiruvisiz belgilangan).
  final List<PendingAttendanceRequestEntity> pendingRequests;

  const TodayAttendanceEntity({
    required this.date,
    required this.staffName,
    required this.phone,
    required this.personCode,
    required this.smena,
    required this.smenaStart,
    this.checkIn,
    this.checkOut,
    this.delay,
    required this.eventsCount,
    this.next,
    this.inside = false,
    this.counts = const AttendanceCountsEntity(),
    this.sessions = const [],
    this.events = const [],
    this.pendingRequests = const [],
  });

  @override
  List<Object?> get props => [
    date,
    staffName,
    phone,
    inside,
    next,
    counts,
    pendingRequests,
    sessions,
    events,
  ];
}

class ArizaInfoEntity extends Equatable {
  final int id;
  final String turi;
  final String nomi;
  final String? izoh;

  const ArizaInfoEntity({
    required this.id,
    required this.turi,
    required this.nomi,
    this.izoh,
  });

  @override
  List<Object?> get props => [id, turi, nomi, izoh];
}

class AttendanceReportEntity extends Equatable {
  final String date;
  final String? weekday;
  final String? checkIn;
  final String? checkOut;
  final String? delay;
  final int? lateMinutes;
  final int? workedMinutes;
  final int? spanMinutes;
  final String status;
  final ArizaInfoEntity? ariza;
  final List<AttendanceSessionEntity> sessions;
  final List<AttendanceEventEntity> events;
  final AttendanceCountsEntity counts;

  const AttendanceReportEntity({
    required this.date,
    this.weekday,
    this.checkIn,
    this.checkOut,
    this.delay,
    this.lateMinutes,
    this.workedMinutes,
    this.spanMinutes,
    required this.status,
    this.ariza,
    this.sessions = const [],
    this.events = const [],
    this.counts = const AttendanceCountsEntity(),
  });

  bool get hasRecord =>
      checkIn != null ||
      checkOut != null ||
      sessions.isNotEmpty ||
      events.isNotEmpty;

  @override
  List<Object?> get props => [
    date,
    checkIn,
    checkOut,
    status,
    ariza,
    sessions,
    events,
    counts,
  ];
}

class CheckLocationEntity extends Equatable {
  final String status;
  final String message;
  final String? distance;
  final String? allowed;
  final String? filial;
  final int? filialId;
  final double? distanceM;
  final double? allowedM;
  final String? eventTime;
  final bool duplicate;

  /// Yuz tekshiruvisiz belgilangan davomat so'rovining raqami.
  /// Server `status: "pending_review"` (HTTP 202) qaytarganda keladi —
  /// yozuv darhol davomatga tushmaydi, rahbar tasdig'ini kutadi.
  final int? requestId;

  const CheckLocationEntity({
    required this.status,
    required this.message,
    this.distance,
    this.allowed,
    this.filial,
    this.filialId,
    this.distanceM,
    this.allowedM,
    this.eventTime,
    this.duplicate = false,
    this.requestId,
  });

  /// Davomat rahbar tasdig'ini kutmoqda (yuz tekshirilmagan).
  bool get isPendingReview => status == 'pending_review';

  @override
  List<Object?> get props => [status, message, distance, filialId, requestId];
}
