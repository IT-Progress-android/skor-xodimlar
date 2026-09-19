import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/domain/repositories/ariza_repository.dart';

class SubmitArizaParams {
  final String phone;
  final int? staffId;
  final String fromDate;
  final String toDate;
  final String turi;
  final String? izoh;

  SubmitArizaParams({
    required this.phone,
    this.staffId,
    required this.fromDate,
    required this.toDate,
    required this.turi,
    this.izoh,
  });
}

class SubmitArizaUseCase {
  final ArizaRepository repository;
  SubmitArizaUseCase(this.repository);

  Future<Either<Failure, ArizaEntity>> call(SubmitArizaParams params) async {
    return await repository.submitAriza(
      phone: params.phone,
      staffId: params.staffId,
      fromDate: params.fromDate,
      toDate: params.toDate,
      turi: params.turi,
      izoh: params.izoh,
    );
  }
}
