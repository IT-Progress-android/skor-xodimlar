import 'package:equatable/equatable.dart';

/// Ijrochining hisoblangan holati (TZ, "Topshiriq va uning holatlari").
enum TaskHolat {
  jarayonda,
  bajarilmadi,
  ozvaqtida,
  kechikib,
  bekor,
  otkazildi;

  static TaskHolat fromString(String? raw) {
    switch (raw) {
      case 'bajarilmadi':
        return TaskHolat.bajarilmadi;
      case 'ozvaqtida':
        return TaskHolat.ozvaqtida;
      case 'kechikib':
        return TaskHolat.kechikib;
      case 'bekor':
        return TaskHolat.bekor;
      case 'otkazildi':
        return TaskHolat.otkazildi;
      default:
        return TaskHolat.jarayonda;
    }
  }

  bool get isDone => this == ozvaqtida || this == kechikib;
  bool get isOpen => this == jarayonda || this == bajarilmadi;

  String get translationKey => 'task_holat_$name';
}

/// Statistika davri.
enum TaskPeriod {
  kun,
  hafta,
  oy,
  yil;

  String get translationKey => 'task_period_$name';
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double? _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s == 'null' ? null : s;
}

DateTime? _date(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

class PageMeta extends Equatable {
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  const PageMeta({
    this.page = 1,
    this.perPage = 30,
    this.total = 0,
    this.lastPage = 1,
  });

  factory PageMeta.fromJson(dynamic json) {
    if (json is! Map) return const PageMeta();
    return PageMeta(
      page: _int(json['page']).clamp(1, 1 << 30),
      perPage: _int(json['per_page']),
      total: _int(json['total']),
      lastPage: _int(json['last_page']).clamp(1, 1 << 30),
    );
  }

  bool get hasMore => page < lastPage;

  @override
  List<Object?> get props => [page, perPage, total, lastPage];
}

class Paged<T> {
  final List<T> items;
  final PageMeta meta;
  const Paged(this.items, this.meta);
}

/// Xodim ko'radigan topshiriq (`/bot/staff/topshiriq`).
class StaffTask extends Equatable {
  final int id;
  final String title;
  final String? description;
  final TaskHolat holat;
  final DateTime? muddat;
  final String? berdi;
  final DateTime? berilganVaqt;
  final DateTime? seenAt;
  final DateTime? completedAt;
  final String? comment;
  final String? returnComment;
  final DateTime? returnedAt;

  const StaffTask({
    required this.id,
    required this.title,
    this.description,
    required this.holat,
    this.muddat,
    this.berdi,
    this.berilganVaqt,
    this.seenAt,
    this.completedAt,
    this.comment,
    this.returnComment,
    this.returnedAt,
  });

  factory StaffTask.fromJson(Map<String, dynamic> json) {
    return StaffTask(
      id: _int(json['id']),
      title: _str(json['title']) ?? '',
      description: _str(json['description']),
      holat: TaskHolat.fromString(_str(json['holat'])),
      muddat: _date(json['muddat'] ?? json['deadline']),
      berdi: _str(json['berdi']),
      berilganVaqt: _date(json['berilgan_vaqt'] ?? json['created_at']),
      seenAt: _date(json['seen_at']),
      completedAt: _date(json['completed_at']),
      comment: _str(json['comment']),
      returnComment: _str(json['return_comment']),
      returnedAt: _date(json['returned_at']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    holat,
    muddat,
    berdi,
    berilganVaqt,
    seenAt,
    completedAt,
    comment,
    returnComment,
    returnedAt,
  ];
}

/// Rahbar ro'yxatidagi topshiriq (`GET /rahbar/topshiriq`).
class RahbarTaskSummary extends Equatable {
  final int id;
  final String title;
  final DateTime? deadline;
  final DateTime? createdAt;
  final bool bekorQilingan;
  final int jami;
  final int ozvaqtida;
  final int kechikib;
  final int jarayonda;
  final int bajarilmadi;
  final int otkazildi;

  const RahbarTaskSummary({
    required this.id,
    required this.title,
    this.deadline,
    this.createdAt,
    this.bekorQilingan = false,
    this.jami = 0,
    this.ozvaqtida = 0,
    this.kechikib = 0,
    this.jarayonda = 0,
    this.bajarilmadi = 0,
    this.otkazildi = 0,
  });

  factory RahbarTaskSummary.fromJson(Map<String, dynamic> json) {
    return RahbarTaskSummary(
      id: _int(json['id']),
      title: _str(json['title']) ?? '',
      deadline: _date(json['deadline']),
      createdAt: _date(json['created_at']),
      bekorQilingan:
          json['bekor_qilingan'] == true || _str(json['cancelled_at']) != null,
      jami: _int(json['jami']),
      ozvaqtida: _int(json['ozvaqtida']),
      kechikib: _int(json['kechikib']),
      jarayonda: _int(json['jarayonda']),
      bajarilmadi: _int(json['bajarilmadi']),
      otkazildi: _int(json['otkazildi']),
    );
  }

  int get bajarildi => ozvaqtida + kechikib;

  @override
  List<Object?> get props => [
    id,
    title,
    deadline,
    createdAt,
    bekorQilingan,
    jami,
    ozvaqtida,
    kechikib,
    jarayonda,
    bajarilmadi,
    otkazildi,
  ];
}

class TaskStaffRef extends Equatable {
  final int staffId;
  final String ism;
  const TaskStaffRef(this.staffId, this.ism);

  static TaskStaffRef? fromJson(dynamic json) {
    if (json is! Map) return null;
    return TaskStaffRef(_int(json['staff_id']), _str(json['ism']) ?? '');
  }

  @override
  List<Object?> get props => [staffId, ism];
}

/// Topshiriq ijrochisi (`GET /rahbar/topshiriq/{id}` → `xodimlar`).
class TaskAssignee extends Equatable {
  final int assigneeId;
  final int staffId;
  final String ism;
  final String? filial;
  final TaskHolat holat;
  final DateTime? muddat;
  final String? assignedVia;
  final DateTime? seenAt;
  final DateTime? completedAt;
  final String? comment;
  final int returnedCount;
  final String? returnComment;
  final DateTime? returnedAt;
  final TaskStaffRef? otkazildiKimga;
  final String? transferComment;

  const TaskAssignee({
    required this.assigneeId,
    required this.staffId,
    required this.ism,
    this.filial,
    required this.holat,
    this.muddat,
    this.assignedVia,
    this.seenAt,
    this.completedAt,
    this.comment,
    this.returnedCount = 0,
    this.returnComment,
    this.returnedAt,
    this.otkazildiKimga,
    this.transferComment,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      assigneeId: _int(json['assignee_id']),
      staffId: _int(json['staff_id']),
      ism: _str(json['ism']) ?? '',
      filial: _str(json['filial']),
      holat: TaskHolat.fromString(_str(json['holat'])),
      muddat: _date(json['muddat']),
      assignedVia: _str(json['assigned_via']),
      seenAt: _date(json['seen_at']),
      completedAt: _date(json['completed_at']),
      comment: _str(json['comment']),
      returnedCount: _int(json['returned_count']),
      returnComment: _str(json['return_comment']),
      returnedAt: _date(json['returned_at']),
      otkazildiKimga: TaskStaffRef.fromJson(json['otkazildi_kimga']),
      transferComment: _str(json['transfer_comment']),
    );
  }

  @override
  List<Object?> get props => [
    assigneeId,
    staffId,
    ism,
    filial,
    holat,
    muddat,
    assignedVia,
    seenAt,
    completedAt,
    comment,
    returnedCount,
    returnComment,
    returnedAt,
    otkazildiKimga,
    transferComment,
  ];
}

class RahbarTaskDetail extends Equatable {
  final int id;
  final String title;
  final String? description;
  final DateTime? deadline;
  final bool bekorQilingan;
  final DateTime? createdAt;
  final List<TaskAssignee> xodimlar;

  const RahbarTaskDetail({
    required this.id,
    required this.title,
    this.description,
    this.deadline,
    this.bekorQilingan = false,
    this.createdAt,
    this.xodimlar = const [],
  });

  factory RahbarTaskDetail.fromJson(Map<String, dynamic> json) {
    final raw = json['topshiriq'] is Map
        ? Map<String, dynamic>.from(json['topshiriq'] as Map)
        : json;
    final list = (raw['xodimlar'] ?? json['xodimlar']) as List? ?? const [];
    return RahbarTaskDetail(
      id: _int(raw['id']),
      title: _str(raw['title']) ?? '',
      description: _str(raw['description']),
      deadline: _date(raw['deadline']),
      bekorQilingan:
          raw['bekor_qilingan'] == true || _str(raw['cancelled_at']) != null,
      createdAt: _date(raw['created_at']),
      xodimlar: list
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => TaskAssignee.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    deadline,
    bekorQilingan,
    createdAt,
    xodimlar,
  ];
}

/// Statistika ko'rsatkichlari (TZ, "Statistika va tarix").
class TaskCounters extends Equatable {
  final int berilgan;
  final int ozvaqtida;
  final int kechikib;
  final int bajarilmadi;
  final int otkazilgan;
  final int jarayonda;
  final int qaytarilgan;
  final double? bajarishFoizi;
  final double? ozvaqtidaFoizi;
  final double? uddalamadiFoizi;

  const TaskCounters({
    this.berilgan = 0,
    this.ozvaqtida = 0,
    this.kechikib = 0,
    this.bajarilmadi = 0,
    this.otkazilgan = 0,
    this.jarayonda = 0,
    this.qaytarilgan = 0,
    this.bajarishFoizi,
    this.ozvaqtidaFoizi,
    this.uddalamadiFoizi,
  });

  /// Bir nechta xodim hisobini qo'shadi (masalan, bitta filial bo'yicha).
  /// Foizlar har bir xodimning server hisoblagan foizidan berilgan
  /// topshiriqlar soniga qarab tortilgan o'rtacha sifatida olinadi.
  factory TaskCounters.combine(Iterable<TaskCounters> list) {
    var berilgan = 0, ozvaqtida = 0, kechikib = 0, bajarilmadi = 0;
    var otkazilgan = 0, jarayonda = 0, qaytarilgan = 0;
    final pctSum = [0.0, 0.0, 0.0];
    final pctWeight = [0, 0, 0];
    for (final c in list) {
      berilgan += c.berilgan;
      ozvaqtida += c.ozvaqtida;
      kechikib += c.kechikib;
      bajarilmadi += c.bajarilmadi;
      otkazilgan += c.otkazilgan;
      jarayonda += c.jarayonda;
      qaytarilgan += c.qaytarilgan;
      final pcts = [c.bajarishFoizi, c.ozvaqtidaFoizi, c.uddalamadiFoizi];
      for (var i = 0; i < 3; i++) {
        final p = pcts[i];
        if (p != null && c.berilgan > 0) {
          pctSum[i] += p * c.berilgan;
          pctWeight[i] += c.berilgan;
        }
      }
    }
    double? pct(int i) =>
        pctWeight[i] == 0 ? null : (pctSum[i] / pctWeight[i] * 10).round() / 10;
    return TaskCounters(
      berilgan: berilgan,
      ozvaqtida: ozvaqtida,
      kechikib: kechikib,
      bajarilmadi: bajarilmadi,
      otkazilgan: otkazilgan,
      jarayonda: jarayonda,
      qaytarilgan: qaytarilgan,
      bajarishFoizi: pct(0),
      ozvaqtidaFoizi: pct(1),
      uddalamadiFoizi: pct(2),
    );
  }

  factory TaskCounters.fromJson(dynamic json) {
    if (json is! Map) return const TaskCounters();
    return TaskCounters(
      berilgan: _int(json['berilgan']),
      ozvaqtida: _int(json['ozvaqtida']),
      kechikib: _int(json['kechikib']),
      bajarilmadi: _int(json['bajarilmadi']),
      otkazilgan: _int(json['otkazilgan']),
      jarayonda: _int(json['jarayonda']),
      qaytarilgan: _int(json['qaytarilgan']),
      bajarishFoizi: _double(json['bajarish_foizi']),
      ozvaqtidaFoizi: _double(json['ozvaqtida_foizi']),
      uddalamadiFoizi: _double(json['uddalamadi_foizi']),
    );
  }

  @override
  List<Object?> get props => [
    berilgan,
    ozvaqtida,
    kechikib,
    bajarilmadi,
    otkazilgan,
    jarayonda,
    qaytarilgan,
    bajarishFoizi,
    ozvaqtidaFoizi,
    uddalamadiFoizi,
  ];
}

class TaskStaffStat extends Equatable {
  final int staffId;
  final String ism;
  final String? filial;
  final TaskCounters counters;

  const TaskStaffStat({
    required this.staffId,
    required this.ism,
    this.filial,
    required this.counters,
  });

  factory TaskStaffStat.fromJson(Map<String, dynamic> json) {
    return TaskStaffStat(
      staffId: _int(json['staff_id']),
      ism: _str(json['ism']) ?? '',
      filial: _str(json['filial']),
      counters: TaskCounters.fromJson(json),
    );
  }

  @override
  List<Object?> get props => [staffId, ism, filial, counters];
}

class TaskPeriodRange extends Equatable {
  final String? turi;
  final DateTime? dan;
  final DateTime? gacha;
  const TaskPeriodRange({this.turi, this.dan, this.gacha});

  factory TaskPeriodRange.fromJson(dynamic json) {
    if (json is! Map) return const TaskPeriodRange();
    return TaskPeriodRange(
      turi: _str(json['turi']),
      dan: DateTime.tryParse(_str(json['dan']) ?? ''),
      gacha: DateTime.tryParse(_str(json['gacha']) ?? ''),
    );
  }

  @override
  List<Object?> get props => [turi, dan, gacha];
}

class TaskStatsResult extends Equatable {
  final TaskPeriodRange davr;
  final TaskCounters jami;
  final List<TaskStaffStat> xodimlar;
  final PageMeta meta;

  const TaskStatsResult({
    required this.davr,
    required this.jami,
    required this.xodimlar,
    required this.meta,
  });

  @override
  List<Object?> get props => [davr, jami, xodimlar, meta];
}

class TaskDynamicsPoint extends Equatable {
  final String sana;
  final int berilgan;
  final int ozvaqtida;
  final int kechikib;
  final int bajarilmadi;
  final int otkazilgan;

  const TaskDynamicsPoint({
    required this.sana,
    this.berilgan = 0,
    this.ozvaqtida = 0,
    this.kechikib = 0,
    this.bajarilmadi = 0,
    this.otkazilgan = 0,
  });

  factory TaskDynamicsPoint.fromJson(Map<String, dynamic> json) {
    return TaskDynamicsPoint(
      sana: _str(json['sana']) ?? '',
      berilgan: _int(json['berilgan']),
      ozvaqtida: _int(json['ozvaqtida']),
      kechikib: _int(json['kechikib']),
      bajarilmadi: _int(json['bajarilmadi']),
      otkazilgan: _int(json['otkazilgan']),
    );
  }

  @override
  List<Object?> get props => [
    sana,
    berilgan,
    ozvaqtida,
    kechikib,
    bajarilmadi,
    otkazilgan,
  ];
}

/// Bitta xodimning topshiriqlari (`GET /rahbar/topshiriq/xodim/{staff_id}`).
class StaffTaskHistoryItem extends Equatable {
  final int taskId;
  final String title;
  final DateTime? muddat;
  final TaskHolat holat;
  final String? assignedVia;
  final DateTime? completedAt;
  final String? comment;
  final int returnedCount;
  final String? returnComment;
  final TaskStaffRef? otkazildiKimga;
  final String? transferComment;

  const StaffTaskHistoryItem({
    required this.taskId,
    required this.title,
    this.muddat,
    required this.holat,
    this.assignedVia,
    this.completedAt,
    this.comment,
    this.returnedCount = 0,
    this.returnComment,
    this.otkazildiKimga,
    this.transferComment,
  });

  factory StaffTaskHistoryItem.fromJson(Map<String, dynamic> json) {
    return StaffTaskHistoryItem(
      taskId: _int(json['task_id'] ?? json['id']),
      title: _str(json['title']) ?? '',
      muddat: _date(json['muddat']),
      holat: TaskHolat.fromString(_str(json['holat'])),
      assignedVia: _str(json['assigned_via']),
      completedAt: _date(json['completed_at']),
      comment: _str(json['comment']),
      returnedCount: _int(json['returned_count']),
      returnComment: _str(json['return_comment']),
      otkazildiKimga: TaskStaffRef.fromJson(json['otkazildi_kimga']),
      transferComment: _str(json['transfer_comment']),
    );
  }

  @override
  List<Object?> get props => [
    taskId,
    title,
    muddat,
    holat,
    assignedVia,
    completedAt,
    comment,
    returnedCount,
    returnComment,
    otkazildiKimga,
    transferComment,
  ];
}

class StaffTaskHistory {
  final TaskCounters counters;
  final List<StaffTaskHistoryItem> items;
  final PageMeta meta;
  const StaffTaskHistory(this.counters, this.items, this.meta);
}

/// Topshiriq berish uchun tanlanadigan xodim.
class PickableStaff extends Equatable {
  final int id;
  final String name;
  final String? subtitle;
  final String? photo;

  /// Xodim biriktirilgan filial nomi — tanlash oynasida filtr uchun.
  final String? filial;

  const PickableStaff({
    required this.id,
    required this.name,
    this.subtitle,
    this.photo,
    this.filial,
  });

  @override
  List<Object?> get props => [id, name, subtitle, photo, filial];
}

/// Tashkilot filiallari va xodimlarning qaysi filialga biriktirilgani
/// (`GET /rahbar/hisobot/filial`). Filial tablari va filtrlarining yagona
/// manbasi.
class FilialDirectory {
  /// Filial nomlari, alifbo tartibida ("biriktirilmagan" guruhisiz).
  final List<String> names;

  /// Xodim id → filial nomi.
  final Map<int, String> staffFilial;

  const FilialDirectory({this.names = const [], this.staffFilial = const {}});

  factory FilialDirectory.fromJson(Map<String, dynamic> json) {
    final names = <String>[];
    final staff = <int, String>{};
    final list = json['filiallar'];
    if (list is List) {
      for (final f in list) {
        if (f is! Map) continue;
        if (f['is_unassigned'] == true) continue;
        final nom = (f['nom'] ?? f['name'])?.toString().trim() ?? '';
        if (nom.isEmpty) continue;
        names.add(nom);
        final xodimlar = f['xodimlar'];
        if (xodimlar is List) {
          for (final x in xodimlar) {
            if (x is! Map) continue;
            final id = _int(x['id'] ?? x['staff_id']);
            if (id > 0) staff[id] = nom;
          }
        }
      }
    }
    return FilialDirectory(names: distinctFilials(names), staffFilial: staff);
  }
}

/// Ro'yxatdagi bo'sh bo'lmagan filial nomlari, alifbo tartibida.
List<String> distinctFilials(Iterable<String?> names) {
  final set = <String>{
    for (final n in names)
      if (n != null && n.trim().isNotEmpty) n.trim(),
  };
  return set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
