import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/tashkilot_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/repositories/lookup_repository.dart';

class GetTashkilotlarUseCase {
  final LookupRepository repository;
  GetTashkilotlarUseCase(this.repository);
  Future<Either<Failure, List<TashkilotEntity>>> call() async {
    return await repository.getTashkilotlar();
  }
}
