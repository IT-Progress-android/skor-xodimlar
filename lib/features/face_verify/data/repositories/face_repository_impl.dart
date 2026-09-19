import 'dart:typed_data';
import 'package:skore_hodimlar/features/face_verify/data/datasources/face_remote_datasource.dart';
import 'package:skore_hodimlar/features/face_verify/domain/entities/face_verify_entity.dart';
import 'package:skore_hodimlar/features/face_verify/domain/repositories/face_repository.dart';

class FaceRepositoryImpl implements FaceRepository {
  final FaceRemoteDataSource remoteDataSource;

  FaceRepositoryImpl(this.remoteDataSource);

  @override
  Future<FaceVerifyEntity> verifyFace(
    String phone,
    Uint8List imageBytes, {
    String? staffId,
  }) async {
    return await remoteDataSource.verifyFace(
      phone,
      imageBytes,
      staffId: staffId,
    );
  }
}
