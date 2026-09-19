import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/applications/data/datasources/ariza_remote_datasource.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';

abstract class ArizaRepository {
  Future<Either<Failure, GetArizalarResponse>> getArizalar(
    String phone, {
    int? staffId,
    String? status,
  });
  Future<Either<Failure, List<ArizaTuriEntity>>> getArizaTurlari(
    String phone, {
    int? staffId,
  });
  Future<Either<Failure, ArizaEntity>> submitAriza({
    required String phone,
    int? staffId,
    required String fromDate,
    required String toDate,
    required String turi,
    String? izoh,
  });
  Future<Either<Failure, String>> cancelAriza(
    String phone,
    int arizaId, {
    int? staffId,
  });
}
