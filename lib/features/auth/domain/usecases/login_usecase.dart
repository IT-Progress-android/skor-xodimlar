import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:skore_hodimlar/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, LoginResult>> call(
    String phone, {
    int? staffId,
    String? personCode,
  }) {
    return repository.loginStaff(
      phone,
      staffId: staffId,
      personCode: personCode,
    );
  }
}
