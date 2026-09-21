import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';

class ArizaTuriModel extends ArizaTuriEntity {
  const ArizaTuriModel({required super.kalit, required super.nomi});

  factory ArizaTuriModel.fromJson(Map<String, dynamic> json) {
    return ArizaTuriModel(
      kalit: json['kalit']?.toString() ?? '',
      nomi: json['nomi']?.toString() ?? '',
    );
  }
}

class ArizaSummaryModel extends ArizaSummaryEntity {
  const ArizaSummaryModel({
    super.kutilmoqda,
    super.tasdiqlandi,
    super.radEtildi,
    super.jami,
  });

  factory ArizaSummaryModel.fromJson(Map<String, dynamic> json) {
    return ArizaSummaryModel(
      kutilmoqda: (json['kutilmoqda'] as num?)?.toInt() ?? 0,
      tasdiqlandi: (json['tasdiqlandi'] as num?)?.toInt() ?? 0,
      radEtildi: (json['rad_etildi'] as num?)?.toInt() ?? 0,
      jami: (json['jami'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArizaModel extends ArizaEntity {
  const ArizaModel({
    required super.id,
    required super.turi,
    required super.turiNomi,
    required super.fromDate,
    required super.toDate,
    required super.kunlar,
    super.izoh,
    required super.status,
    required super.statusNomi,
    super.reviewIzoh,
    required super.yuborilgan,
  });

  factory ArizaModel.fromJson(Map<String, dynamic> json) {
    return ArizaModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      turi: json['turi']?.toString() ?? '',
      turiNomi:
          json['turi_nomi']?.toString() ?? (json['turi']?.toString() ?? ''),
      fromDate: json['from_date']?.toString() ?? '',
      toDate:
          json['to_date']?.toString() ?? (json['from_date']?.toString() ?? ''),
      kunlar: (json['kunlar'] as num?)?.toInt() ?? 1,
      izoh: json['izoh']?.toString(),
      status: json['status']?.toString() ?? 'kutilmoqda',
      statusNomi: BackendTextMapper.translateArizaStatus(
        json['status_nomi']?.toString() ??
        json['status']?.toString() ??
        AppLocalizations.trStatic('status_kutilmoqda'),
      ),
      reviewIzoh: json['review_izoh']?.toString(),
      yuborilgan: json['yuborilgan']?.toString() ?? '',
    );
  }
}
