import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:skore_hodimlar/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, LoginResult>> loginStaff(
    String phone, {
    int? staffId,
    String? personCode,
  }) async {
    try {
      final result = await remoteDataSource.loginStaff(
        phone,
        staffId: staffId,
        personCode: personCode,
      );
      return Right(result);
    } on PhoneAmbiguousException catch (e) {
      return Left(PhoneAmbiguousFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(AppErrorFormatter.sanitizeMessage(e.message)));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(AppErrorFormatter.sanitizeMessage(e.message)));
    } on NotFoundException catch (e) {
      return Left(
        NotFoundFailure(AppErrorFormatter.sanitizeMessage(e.message)),
      );
    } catch (e) {
      return Left(ServerFailure(AppErrorFormatter.toUzbek(e)));
    }
  }
}
