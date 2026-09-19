import 'package:skore_hodimlar/features/lookup/domain/entities/metadata_entity.dart';

class MetadataModel extends MetadataEntity {
  const MetadataModel({
    required super.bolimlar,
    required super.lavozimlar,
    required super.smenalar,
  });

  factory MetadataModel.fromJson(Map<String, dynamic> json) {
    return MetadataModel(
      bolimlar: List<String>.from(json['bolim'] as List? ?? const []),
      lavozimlar: List<String>.from(json['lavozim'] as List? ?? const []),
      smenalar: List<String>.from(json['smena'] as List? ?? const []),
    );
  }
}
