import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/metadata_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/repositories/lookup_repository.dart';

class GetMetadataParams {
  final String schoolName;
  final String? viloyat;
  final String? tuman;
  GetMetadataParams({required this.schoolName, this.viloyat, this.tuman});
}

class GetMetadataUseCase {
  final LookupRepository repository;
  GetMetadataUseCase(this.repository);
  Future<Either<Failure, MetadataEntity>> call(GetMetadataParams params) async {
    return await repository.getMetadata(
      params.schoolName,
      params.viloyat,
      params.tuman,
    );
  }
}
