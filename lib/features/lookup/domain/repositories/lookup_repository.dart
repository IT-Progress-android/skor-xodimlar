import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/metadata_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/tashkilot_entity.dart';

abstract class LookupRepository {
  Future<Either<Failure, List<TashkilotEntity>>> getTashkilotlar();
  Future<Either<Failure, MetadataEntity>> getMetadata(
    String schoolName,
    String? viloyat,
    String? tuman,
  );
  Future<Either<Failure, Map<String, dynamic>>> storeStaff(
    Map<String, dynamic> body,
  );
}
