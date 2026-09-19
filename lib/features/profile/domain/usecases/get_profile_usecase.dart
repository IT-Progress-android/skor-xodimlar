import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/profile/domain/entities/profile_entity.dart';
import 'package:skore_hodimlar/features/profile/domain/repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository repository;
  GetProfileUseCase(this.repository);
  Future<Either<Failure, ProfileEntity>> call(
    String phone, {
    int? staffId,
  }) async {
    return await repository.getProfile(phone, staffId: staffId);
  }
}
