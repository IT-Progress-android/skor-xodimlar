import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';

abstract class AttendanceRepository {
  Future<TodayAttendanceEntity> getTodayAttendance(String phone);
  Future<List<AttendanceReportEntity>> getPeriodAttendance(
    String phone,
    String period,
  );
  Future<CheckLocationEntity> checkLocation(
    String phone,
    double lat,
    double lng,
    String status, {
    String? verifyToken,
    bool isMock = false,
  });
}
