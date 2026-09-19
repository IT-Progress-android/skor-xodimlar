import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';
import 'package:skore_hodimlar/features/attendance/domain/repositories/attendance_repository.dart';

class GetPeriodAttendanceUseCase {
  final AttendanceRepository repository;

  GetPeriodAttendanceUseCase(this.repository);

  Future<List<AttendanceReportEntity>> call(String phone, String period) async {
    return await repository.getPeriodAttendance(phone, period);
  }
}
