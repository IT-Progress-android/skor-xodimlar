import 'package:skore_hodimlar/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';
import 'package:skore_hodimlar/features/attendance/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource remoteDataSource;

  AttendanceRepositoryImpl(this.remoteDataSource);

  @override
  Future<TodayAttendanceEntity> getTodayAttendance(String phone) async {
    return await remoteDataSource.getTodayAttendance(phone);
  }

  @override
  Future<List<AttendanceReportEntity>> getPeriodAttendance(
    String phone,
    String period,
  ) async {
    return await remoteDataSource.getPeriodAttendance(phone, period);
  }

  @override
  Future<CheckLocationEntity> checkLocation(
    String phone,
    double lat,
    double lng,
    String status, {
    String? verifyToken,
    bool isMock = false,
  }) async {
    return await remoteDataSource.checkLocation(
      phone,
      lat,
      lng,
      status,
      verifyToken: verifyToken,
      isMock: isMock,
    );
  }
}
