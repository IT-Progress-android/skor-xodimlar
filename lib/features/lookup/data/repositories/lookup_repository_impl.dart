import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/lookup/data/datasources/lookup_remote_datasource.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/metadata_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/tashkilot_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/repositories/lookup_repository.dart';

class LookupRepositoryImpl implements LookupRepository {
  final LookupRemoteDataSource remoteDataSource;
  LookupRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<TashkilotEntity>>> getTashkilotlar() async {
    try {
      final res = await remoteDataSource.getTashkilotlar();
      return Right(res);
    } catch (e) {
      return Left(
        ServerFailure(AppLocalizations.trStatic('err_server_action_failed')),
      );
    }
  }

  @override
  Future<Either<Failure, MetadataEntity>> getMetadata(
    String schoolName,
    String? viloyat,
    String? tuman,
  ) async {
    try {
      final res = await remoteDataSource.getMetadata(
        schoolName,
        viloyat,
        tuman,
      );
      return Right(res);
    } catch (e) {
      return Left(
        ServerFailure(AppLocalizations.trStatic('err_server_action_failed')),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> storeStaff(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await remoteDataSource.storeStaff(body);
      return Right(res);
    } catch (e) {
      return Left(
        ServerFailure(AppLocalizations.trStatic('err_server_action_failed')),
      );
    }
  }
}
