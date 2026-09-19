import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/applications/domain/repositories/ariza_repository.dart';

class CancelArizaUseCase {
  final ArizaRepository repository;
  CancelArizaUseCase(this.repository);

  Future<Either<Failure, String>> call(
    String phone,
    int arizaId, {
    int? staffId,
  }) async {
    return await repository.cancelAriza(phone, arizaId, staffId: staffId);
  }
}
