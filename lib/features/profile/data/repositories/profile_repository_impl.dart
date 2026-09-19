import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:skore_hodimlar/features/profile/domain/entities/profile_entity.dart';
import 'package:skore_hodimlar/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
  });

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(
    String phone, {
    int? staffId,
  }) async {
    try {
      final profile = await remoteDataSource.getProfile(
        phone,
        staffId: staffId,
      );
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(
        ServerFailure(AppLocalizations.trStatic('err_profile_load_could_not')),
      );
    }
  }

  @override
  Future<Either<Failure, PhotoUploadResult>> uploadPhoto(
    String phone,
    int staffId,
    File photoFile,
  ) async {
    try {
      final result = await remoteDataSource.uploadPhoto(
        phone,
        staffId,
        photoFile,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(
        ServerFailure(AppLocalizations.trStatic('err_photo_upload_failed')),
      );
    }
  }

  @override
  Future<Either<Failure, PhoneChangeResult>> changePhone(
    String currentPhone,
    int staffId,
    String newPhone9Digits,
  ) async {
    try {
      final result = await remoteDataSource.changePhone(
        currentPhone,
        staffId,
        newPhone9Digits,
      );
      // Save new phone to SharedPreferences per PDF spec page 21
      await sharedPreferences.setString('phone', result.newPhone);
      await sharedPreferences.setString('staff_phone', result.newPhone);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(
        ServerFailure(AppLocalizations.trStatic('err_phone_change_failed')),
      );
    }
  }

  @override
  Future<void> logout() async {
    await sharedPreferences.clear();
  }
}
