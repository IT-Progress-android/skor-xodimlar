import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/attendance/domain/entities/attendance_entity.dart';
import 'package:skore_hodimlar/features/attendance/domain/usecases/check_location_usecase.dart';
import 'package:skore_hodimlar/features/attendance/domain/usecases/get_period_attendance_usecase.dart';
import 'package:skore_hodimlar/features/attendance/domain/usecases/get_today_attendance_usecase.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();
  @override
  List<Object?> get props => [];
}

class LoadTodayAttendance extends AttendanceEvent {
  final String phone;
  const LoadTodayAttendance(this.phone);
  @override
  List<Object> get props => [phone];
}

class LoadPeriodAttendance extends AttendanceEvent {
  final String phone;
  final String period;
  const LoadPeriodAttendance(this.phone, this.period);
  @override
  List<Object> get props => [phone, period];
}

class CheckInSubmit extends AttendanceEvent {
  final String phone;
  final double lat;
  final double lng;
  final String? verifyToken;
  final bool isMock;
  const CheckInSubmit(
    this.phone,
    this.lat,
    this.lng, {
    this.verifyToken,
    this.isMock = false,
  });
  @override
  List<Object?> get props => [phone, lat, lng, verifyToken, isMock];
}

class CheckOutSubmit extends AttendanceEvent {
  final String phone;
  final double lat;
  final double lng;
  final String? verifyToken;
  final bool isMock;
  const CheckOutSubmit(
    this.phone,
    this.lat,
    this.lng, {
    this.verifyToken,
    this.isMock = false,
  });
  @override
  List<Object?> get props => [phone, lat, lng, verifyToken, isMock];
}

abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class TodayAttendanceLoaded extends AttendanceState {
  final TodayAttendanceEntity entity;
  const TodayAttendanceLoaded(this.entity);
  @override
  List<Object> get props => [entity];
}

class PeriodAttendanceLoaded extends AttendanceState {
  final List<AttendanceReportEntity> reports;
  final String period;
  const PeriodAttendanceLoaded(this.reports, this.period);
  @override
  List<Object> get props => [reports, period];
}

class CheckLocationSuccess extends AttendanceState {
  final CheckLocationEntity entity;
  const CheckLocationSuccess(this.entity);
  @override
  List<Object> get props => [entity];
}

class CheckLocationTooFar extends AttendanceState {
  final CheckLocationEntity entity;
  const CheckLocationTooFar(this.entity);
  @override
  List<Object> get props => [entity];
}

/// Yuz tekshiruvisiz belgilangan davomat — rahbar tasdig'ini kutmoqda
/// (server HTTP 202 + `status: "pending_review"` qaytardi).
class CheckLocationPendingReview extends AttendanceState {
  final CheckLocationEntity entity;
  const CheckLocationPendingReview(this.entity);
  @override
  List<Object> get props => [entity];
}

class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError(this.message);
  @override
  List<Object> get props => [message];
}

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final GetTodayAttendanceUseCase getTodayAttendanceUseCase;
  final GetPeriodAttendanceUseCase getPeriodAttendanceUseCase;
  final CheckLocationUseCase checkLocationUseCase;

  AttendanceBloc({
    required this.getTodayAttendanceUseCase,
    required this.getPeriodAttendanceUseCase,
    required this.checkLocationUseCase,
  }) : super(AttendanceInitial()) {
    on<LoadTodayAttendance>((event, emit) async {
      emit(AttendanceLoading());
      try {
        final entity = await getTodayAttendanceUseCase(event.phone);
        emit(TodayAttendanceLoaded(entity));
      } catch (e) {
        emit(AttendanceError(AppErrorFormatter.toUzbek(e)));
      }
    });

    on<LoadPeriodAttendance>((event, emit) async {
      emit(AttendanceLoading());
      try {
        final reports = await getPeriodAttendanceUseCase(
          event.phone,
          event.period,
        );
        emit(PeriodAttendanceLoaded(reports, event.period));
      } catch (e) {
        emit(AttendanceError(AppErrorFormatter.toUzbek(e)));
      }
    });

    on<CheckInSubmit>((event, emit) async {
      emit(AttendanceLoading());
      try {
        final entity = await checkLocationUseCase(
          event.phone,
          event.lat,
          event.lng,
          'keldim',
          verifyToken: event.verifyToken,
          isMock: event.isMock,
        );
        _emitLocationResult(entity, emit);
      } catch (e) {
        emit(AttendanceError(AppErrorFormatter.toUzbek(e)));
      }
    });

    on<CheckOutSubmit>((event, emit) async {
      emit(AttendanceLoading());
      try {
        final entity = await checkLocationUseCase(
          event.phone,
          event.lat,
          event.lng,
          'ketdim',
          verifyToken: event.verifyToken,
          isMock: event.isMock,
        );
        _emitLocationResult(entity, emit);
      } catch (e) {
        emit(AttendanceError(AppErrorFormatter.toUzbek(e)));
      }
    });
  }

  // Decide the outcome from the server's `status`, not by parsing the distance
  // string (which is unit-bearing, e.g. "45.2 m").
  void _emitLocationResult(
    CheckLocationEntity entity,
    Emitter<AttendanceState> emit,
  ) {
    switch (entity.status) {
      case 'ok':
        emit(CheckLocationSuccess(entity));
        break;
      case 'too_far':
        emit(CheckLocationTooFar(entity));
        break;
      case 'pending_review':
        emit(CheckLocationPendingReview(entity));
        break;
      default:
        // 'error' (org has no location set), 'not_found', or anything unexpected.
        emit(
          AttendanceError(
            entity.message.isNotEmpty
                ? AppErrorFormatter.sanitizeMessage(entity.message)
                : AppLocalizations.trStatic('err_attendance_failed'),
          ),
        );
    }
  }
}
