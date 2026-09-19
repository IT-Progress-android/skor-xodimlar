import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/domain/repositories/ariza_repository.dart';

class GetArizaTypesUseCase {
  final ArizaRepository repository;
  GetArizaTypesUseCase(this.repository);

  Future<Either<Failure, List<ArizaTuriEntity>>> call(
    String phone, {
    int? staffId,
  }) async {
    return await repository.getArizaTurlari(phone, staffId: staffId);
  }
}
