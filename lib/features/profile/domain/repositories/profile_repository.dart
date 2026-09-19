import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:skore_hodimlar/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile(
    String phone, {
    int? staffId,
  });
  Future<Either<Failure, PhotoUploadResult>> uploadPhoto(
    String phone,
    int staffId,
    File photoFile,
  );
  Future<Either<Failure, PhoneChangeResult>> changePhone(
    String currentPhone,
    int staffId,
    String newPhone9Digits,
  );
  Future<void> logout();
}
