import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/applications/data/datasources/ariza_remote_datasource.dart';
import 'package:skore_hodimlar/features/applications/domain/repositories/ariza_repository.dart';

class GetArizalarUseCase {
  final ArizaRepository repository;
  GetArizalarUseCase(this.repository);

  Future<Either<Failure, GetArizalarResponse>> call(
    String phone, {
    int? staffId,
    String? status,
  }) async {
    return await repository.getArizalar(
      phone,
      staffId: staffId,
      status: status,
    );
  }
}
