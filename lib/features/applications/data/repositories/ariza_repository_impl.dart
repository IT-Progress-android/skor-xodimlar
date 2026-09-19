import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/applications/data/datasources/ariza_remote_datasource.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/domain/repositories/ariza_repository.dart';

class ArizaRepositoryImpl implements ArizaRepository {
  final ArizaRemoteDataSource remoteDataSource;
  ArizaRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, GetArizalarResponse>> getArizalar(
    String phone, {
    int? staffId,
    String? status,
  }) async {
    try {
      final result = await remoteDataSource.getArizalar(
        phone,
        staffId: staffId,
        status: status,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(AppErrorFormatter.sanitizeMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(AppErrorFormatter.toUzbek(e)));
    }
  }

  @override
  Future<Either<Failure, List<ArizaTuriEntity>>> getArizaTurlari(
    String phone, {
    int? staffId,
  }) async {
    try {
      final result = await remoteDataSource.getArizaTurlari(
        phone,
        staffId: staffId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(AppErrorFormatter.sanitizeMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(AppErrorFormatter.toUzbek(e)));
    }
  }

  @override
  Future<Either<Failure, ArizaEntity>> submitAriza({
    required String phone,
    int? staffId,
    required String fromDate,
    required String toDate,
    required String turi,
    String? izoh,
  }) async {
    try {
      final body = {
        'phone': phone,
        'id': ?staffId,
        'turi': turi,
        'from_date': fromDate,
        'to_date': toDate,
        if (izoh != null && izoh.isNotEmpty) 'izoh': izoh,
      };

      final result = await remoteDataSource.submitAriza(body);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(AppErrorFormatter.sanitizeMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(AppErrorFormatter.toUzbek(e)));
    }
  }

  @override
  Future<Either<Failure, String>> cancelAriza(
    String phone,
    int arizaId, {
    int? staffId,
  }) async {
    try {
      final result = await remoteDataSource.cancelAriza(
        phone,
        arizaId,
        staffId: staffId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(AppErrorFormatter.sanitizeMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(AppErrorFormatter.toUzbek(e)));
    }
  }
}
