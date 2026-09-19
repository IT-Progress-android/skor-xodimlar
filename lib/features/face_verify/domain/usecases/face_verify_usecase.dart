import 'dart:typed_data';
import 'package:skore_hodimlar/features/face_verify/domain/entities/face_verify_entity.dart';
import 'package:skore_hodimlar/features/face_verify/domain/repositories/face_repository.dart';

class FaceVerifyUseCase {
  final FaceRepository repository;

  FaceVerifyUseCase(this.repository);

  Future<FaceVerifyEntity> call(
    String phone,
    Uint8List imageBytes, {
    String? staffId,
  }) async {
    return await repository.verifyFace(phone, imageBytes, staffId: staffId);
  }
}
