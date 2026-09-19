import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';
import 'package:skore_hodimlar/features/attendance/domain/repositories/attendance_repository.dart';

class CheckLocationUseCase {
  final AttendanceRepository repository;

  CheckLocationUseCase(this.repository);

  Future<CheckLocationEntity> call(
    String phone,
    double lat,
    double lng,
    String status, {
    String? verifyToken,
    bool isMock = false,
  }) async {
    return await repository.checkLocation(
      phone,
      lat,
      lng,
      status,
      verifyToken: verifyToken,
      isMock: isMock,
    );
  }
}
