import 'package:equatable/equatable.dart';

class ArizaTuriEntity extends Equatable {
  final String kalit;
  final String nomi;

  const ArizaTuriEntity({required this.kalit, required this.nomi});

  @override
  List<Object?> get props => [kalit];
}

class ArizaSummaryEntity extends Equatable {
  final int kutilmoqda;
  final int tasdiqlandi;
  final int radEtildi;
  final int jami;

  const ArizaSummaryEntity({
    this.kutilmoqda = 0,
    this.tasdiqlandi = 0,
    this.radEtildi = 0,
    this.jami = 0,
  });

  @override
  List<Object?> get props => [kutilmoqda, tasdiqlandi, radEtildi, jami];
}

class ArizaEntity extends Equatable {
  final int id;
  final String turi;
  final String turiNomi;
  final String fromDate;
  final String toDate;
  final int kunlar;
  final String? izoh;
  final String status;
  final String statusNomi;
  final String? reviewIzoh;
  final String yuborilgan;

  const ArizaEntity({
    required this.id,
    required this.turi,
    required this.turiNomi,
    required this.fromDate,
    required this.toDate,
    required this.kunlar,
    this.izoh,
    required this.status,
    required this.statusNomi,
    this.reviewIzoh,
    required this.yuborilgan,
  });

  bool get isPending => status.toLowerCase() == 'kutilmoqda';

  @override
  List<Object?> get props => [id];
}
