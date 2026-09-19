import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';
import 'package:skore_hodimlar/features/attendance/domain/repositories/attendance_repository.dart';

class GetTodayAttendanceUseCase {
  final AttendanceRepository repository;

  GetTodayAttendanceUseCase(this.repository);

  Future<TodayAttendanceEntity> call(String phone) async {
    return await repository.getTodayAttendance(phone);
  }
}
