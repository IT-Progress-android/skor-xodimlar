import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/auth/data/datasources/auth_remote_datasource.dart';

abstract class AuthRepository {
  /// [staffId] — bir nechta tashkilotdan biri tanlangan holat.
  /// [personCode] — tizim (badge) raqami, PHONE_AMBIGUOUS holatini hal qilish uchun.
  Future<Either<Failure, LoginResult>> loginStaff(
    String phone, {
    int? staffId,
    String? personCode,
  });
}
