import 'package:skore_hodimlar/features/lookup/domain/entities/tashkilot_entity.dart';

class TashkilotModel extends TashkilotEntity {
  const TashkilotModel({required super.id, required super.title});

  factory TashkilotModel.fromJson(Map<String, dynamic> json) {
    return TashkilotModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
    );
  }
}
