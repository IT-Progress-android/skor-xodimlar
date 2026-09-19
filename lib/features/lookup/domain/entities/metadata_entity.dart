import 'package:equatable/equatable.dart';

class MetadataEntity extends Equatable {
  final List<String> bolimlar;
  final List<String> lavozimlar;
  final List<String> smenalar;

  const MetadataEntity({
    required this.bolimlar,
    required this.lavozimlar,
    required this.smenalar,
  });

  @override
  List<Object?> get props => [bolimlar, lavozimlar, smenalar];
}
