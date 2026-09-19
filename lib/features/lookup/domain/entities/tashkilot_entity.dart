import 'package:equatable/equatable.dart';

class TashkilotEntity extends Equatable {
  final int id;
  final String title;
  const TashkilotEntity({required this.id, required this.title});
  @override
  List<Object?> get props => [id];
}
