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

  /// Ish boshlanish vaqti (`smena`, masalan `"09:00"`).
  final String? smena;

  /// Shu kunga bog'langan ariza (`ariza`): turi, sababi, holati.
  final Map<String, dynamic>? ariza;

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
    this.smena,
    this.ariza,
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

  /// Tanlangan davr uchun to'lanadigan summa (hisoblangan − jarima).
  final double maosh;

  /// `soatbay` | `kunbay` | `oylik`.
  final String tolovTuri;
  final int kelganKun;

  /// Asosiy + qo'shimcha ish soatlari.
  final double jamiIshlanganSoat;

  /// Bir soat / bir kun / bir oy uchun stavka ([tolovTuri] ga qarab).
  final double stavka;
  final double qoshimchaSoat;
  final int kechikishSoni;
  final int kechikishDaqiqa;

  /// Jarima hisoblanadimi (rahbar har bir xodim uchun yoqadi/o'chiradi).
  final bool jarimaYoqilgan;

  /// Shu xodim uchun alohida jarima summasi. `null` — tashkilotning umumiy
  /// summasi ([PayrollSettings.jarimaSumma]) ishlatiladi.
  final double? jarimaSummaShaxsiy;

  /// Qo'shimcha ish (smenadan keyin 00:00 gacha) uchun haq to'lanadimi —
  /// rahbar har bir xodim uchun belgilaydi.
  final bool qoshimchaTolanadi;

  /// Qo'shimcha ishning 1 soati uchun summa.
  final double qoshimchaStavka;

  /// Davr bo'yicha qo'shimcha ish haqi ([hisoblangan] ichida).
  final double qoshimchaSumma;
  final double hisoblangan;
  final double jarima;

  /// Davr ichidagi tasdiqlangan ariza kunlari.
  final int arizaKun;

  /// Xodim biriktirilgan filial (`null` — biriktirilmagan).
  final int? filialId;
  final String? filialName;

  const RahbarPayrollItemEntity({
    required this.id,
    required this.name,
    required this.bolim,
    required this.lavozim,
    required this.maosh,
    required this.tolovTuri,
    required this.kelganKun,
    required this.jamiIshlanganSoat,
    this.stavka = 0,
    this.qoshimchaSoat = 0,
    this.kechikishSoni = 0,
    this.kechikishDaqiqa = 0,
    this.jarimaYoqilgan = true,
    this.jarimaSummaShaxsiy,
    this.qoshimchaTolanadi = false,
    this.qoshimchaStavka = 0,
    this.qoshimchaSumma = 0,
    this.hisoblangan = 0,
    this.jarima = 0,
    this.arizaKun = 0,
    this.filialId,
    this.filialName,
  });

  /// Kechikish jarimasini tashkilotning joriy [settings] i bo'yicha
  /// qayta hisoblaydi: xodimda alohida summa bo'lsa — o'sha, aks holda
  /// umumiy summa; "har kechikish" — kunlar soniga, "har daqiqa" —
  /// daqiqalarga. Umumiy yoki xodimdagi kalit o'chiq bo'lsa — 0.
  RahbarPayrollItemEntity withFineFrom(PayrollSettings settings) {
    final rate = (jarimaSummaShaxsiy ?? 0) > 0
        ? jarimaSummaShaxsiy!
        : settings.jarimaSumma;
    final units = settings.jarimaRejimi == 'har_daqiqa'
        ? kechikishDaqiqa
        : kechikishSoni;
    final fine = settings.jarimaYoqilgan && jarimaYoqilgan ? units * rate : 0.0;
    // Eski hisobotda `hisoblangan` yo'q — jarimagacha bo'lgan summa tiklanadi.
    final gross = hisoblangan > 0 ? hisoblangan : maosh + jarima;
    return RahbarPayrollItemEntity(
      id: id,
      name: name,
      bolim: bolim,
      lavozim: lavozim,
      maosh: (gross - fine).clamp(0, double.infinity).toDouble(),
      tolovTuri: tolovTuri,
      kelganKun: kelganKun,
      jamiIshlanganSoat: jamiIshlanganSoat,
      stavka: stavka,
      qoshimchaSoat: qoshimchaSoat,
      kechikishSoni: kechikishSoni,
      kechikishDaqiqa: kechikishDaqiqa,
      jarimaYoqilgan: jarimaYoqilgan,
      jarimaSummaShaxsiy: jarimaSummaShaxsiy,
      qoshimchaTolanadi: qoshimchaTolanadi,
      qoshimchaStavka: qoshimchaStavka,
      qoshimchaSumma: qoshimchaSumma,
      hisoblangan: hisoblangan,
      jarima: fine,
      arizaKun: arizaKun,
      filialId: filialId,
      filialName: filialName,
    );
  }

  /// Filial bir xil kalit: avval ID, bo'lmasa nom.
  String? get filialKey {
    if (filialId != null && filialId! > 0) return 'id:$filialId';
    final n = filialName?.trim();
    return (n == null || n.isEmpty) ? null : 'nom:${n.toLowerCase()}';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    filialId,
    filialName,
    maosh,
    tolovTuri,
    stavka,
    kelganKun,
    jamiIshlanganSoat,
    qoshimchaSoat,
    kechikishSoni,
    jarimaYoqilgan,
    jarimaSummaShaxsiy,
    qoshimchaTolanadi,
    qoshimchaStavka,
    qoshimchaSumma,
    jarima,
    arizaKun,
  ];
}

/// Bugalteriya hisoboti: tanlangan davr (hafta/oy/yil) va xodimlar.
class RahbarPayrollReport extends Equatable {
  final String davr;
  final String? from;
  final String? to;
  final List<RahbarPayrollItemEntity> items;

  const RahbarPayrollReport({
    required this.davr,
    this.from,
    this.to,
    required this.items,
  });

  double get jamiTolanadi => items.fold(0, (sum, e) => sum + e.maosh);
  double get jamiJarima => items.fold(0, (sum, e) => sum + e.jarima);

  @override
  List<Object?> get props => [davr, from, to, items];
}

/// Xodimning bir kunlik qo'shimcha ishi (smena tugagandan keyingi sessiyalar).
class OvertimeDay extends Equatable {
  final String sana;
  final String? from;
  final String? to;
  final double soat;

  const OvertimeDay({
    required this.sana,
    this.from,
    this.to,
    required this.soat,
  });

  factory OvertimeDay.fromJson(Map<String, dynamic> json) => OvertimeDay(
    sana: (json['sana'] ?? '').toString(),
    from: json['from']?.toString(),
    to: json['to']?.toString(),
    soat: (num.tryParse('${json['soat'] ?? 0}') ?? 0).toDouble(),
  );

  @override
  List<Object?> get props => [sana, from, to, soat];
}

/// Tashkilot bo'yicha kechikish jarimasi sozlamalari. Imtiyozli vaqt yo'q:
/// smena boshlanishidan 1 daqiqa kechikish ham hisoblanadi.
class PayrollSettings extends Equatable {
  /// `har_kechikish` — har kech qolgan kun uchun [jarimaSumma];
  /// `har_daqiqa` — har kechikkan daqiqa uchun [jarimaSumma].
  final String jarimaRejimi;
  final double jarimaSumma;

  /// Kechikish jarimasi umuman yoqilganmi (o'chirilsa — hech kimga yozilmaydi).
  final bool jarimaYoqilgan;

  /// Tasdiqlangan ariza kunlari uchun haq to'lanadimi — har bir tur uchun.
  final List<ArizaTurPay> arizaTurlari;

  const PayrollSettings({
    this.jarimaRejimi = 'har_kechikish',
    this.jarimaSumma = 0,
    this.jarimaYoqilgan = true,
    this.arizaTurlari = const [],
  });

  factory PayrollSettings.fromJson(Map<String, dynamic> json) {
    final rejim = json['jarima_rejimi']?.toString();
    final turlar = json['ariza_turlari'];
    return PayrollSettings(
      jarimaRejimi: rejim == 'har_daqiqa' ? 'har_daqiqa' : 'har_kechikish',
      jarimaSumma: (num.tryParse('${json['jarima_summa'] ?? 0}') ?? 0)
          .toDouble(),
      jarimaYoqilgan: json['jarima_yoqilgan'] != false,
      arizaTurlari: turlar is List
          ? turlar
                .whereType<Map<dynamic, dynamic>>()
                .map((e) => ArizaTurPay.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  PayrollSettings copyWith({
    String? jarimaRejimi,
    double? jarimaSumma,
    bool? jarimaYoqilgan,
    List<ArizaTurPay>? arizaTurlari,
  }) => PayrollSettings(
    jarimaRejimi: jarimaRejimi ?? this.jarimaRejimi,
    jarimaSumma: jarimaSumma ?? this.jarimaSumma,
    jarimaYoqilgan: jarimaYoqilgan ?? this.jarimaYoqilgan,
    arizaTurlari: arizaTurlari ?? this.arizaTurlari,
  );

  Map<String, dynamic> toJson() => {
    'jarima_rejimi': jarimaRejimi,
    'jarima_summa': jarimaSumma,
    'jarima_yoqilgan': jarimaYoqilgan,
    'ariza_turlari': [
      for (final t in arizaTurlari)
        {'kalit': t.kalit, 'haq_tolanadi': t.haqTolanadi},
    ],
  };

  @override
  List<Object?> get props => [
    jarimaRejimi,
    jarimaSumma,
    jarimaYoqilgan,
    arizaTurlari,
  ];
}

/// Ariza turi (ta'til, kasallik, ...) va u uchun haq to'lanishi.
class ArizaTurPay extends Equatable {
  /// Ariza turining matnli kaliti (`/bot/staff/ariza/turlari` dagi kabi).
  final String kalit;
  final String nomi;
  final bool haqTolanadi;

  const ArizaTurPay({
    required this.kalit,
    required this.nomi,
    required this.haqTolanadi,
  });

  factory ArizaTurPay.fromJson(Map<String, dynamic> json) => ArizaTurPay(
    kalit: (json['kalit'] ?? json['id'] ?? '').toString(),
    nomi: (json['nomi'] ?? json['name'] ?? '').toString(),
    haqTolanadi: json['haq_tolanadi'] == true,
  );

  ArizaTurPay copyWith({bool? haqTolanadi}) => ArizaTurPay(
    kalit: kalit,
    nomi: nomi,
    haqTolanadi: haqTolanadi ?? this.haqTolanadi,
  );

  @override
  List<Object?> get props => [kalit, nomi, haqTolanadi];
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
