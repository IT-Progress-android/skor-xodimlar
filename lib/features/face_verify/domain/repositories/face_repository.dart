import 'dart:typed_data';
import 'package:skore_hodimlar/features/face_verify/domain/entities/face_verify_entity.dart';

abstract class FaceRepository {
  Future<FaceVerifyEntity> verifyFace(
    String phone,
    Uint8List imageBytes, {
    String? staffId,
  });
}
