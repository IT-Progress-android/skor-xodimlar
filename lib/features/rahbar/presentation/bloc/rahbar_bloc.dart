import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/utils/dio_retry_helper.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';

// Events
abstract class RahbarEvent extends Equatable {
  const RahbarEvent();
  @override
  List<Object?> get props => [];
}

class RahbarLoginSubmitted extends RahbarEvent {
  final String login;
  final String password;
  const RahbarLoginSubmitted({required this.login, required this.password});
  @override
  List<Object?> get props => [login, password];
}

class LoadRahbarDashboard extends RahbarEvent {
  final String? date;
  const LoadRahbarDashboard({this.date});
  @override
  List<Object?> get props => [date];
}

class LoadRahbarKundalik extends RahbarEvent {
  final String? date;
  const LoadRahbarKundalik({this.date});
  @override
  List<Object?> get props => [date];
}

class LoadRahbarPayroll extends RahbarEvent {
  final String? month;
  const LoadRahbarPayroll({this.month});
  @override
  List<Object?> get props => [month];
}

class LoadRahbarArizalar extends RahbarEvent {}

class ReviewRahbarAriza extends RahbarEvent {
  final int arizaId;
  final String action; // approve / reject
  final String? comment;
  const ReviewRahbarAriza({
    required this.arizaId,
    required this.action,
    this.comment,
  });
  @override
  List<Object?> get props => [arizaId, action, comment];
}

// States
abstract class RahbarState extends Equatable {
  const RahbarState();
  @override
  List<Object?> get props => [];
}

class RahbarInitial extends RahbarState {}

class RahbarLoading extends RahbarState {}

class RahbarAuthSuccess extends RahbarState {
  final RahbarUserEntity user;
  const RahbarAuthSuccess(this.user);
  @override
  List<Object?> get props => [user];
}

class RahbarDashboardLoaded extends RahbarState {
  final RahbarDashboardEntity dashboard;
  const RahbarDashboardLoaded(this.dashboard);
  @override
  List<Object?> get props => [dashboard];
}

class RahbarKundalikLoaded extends RahbarState {
  final List<RahbarStaffAttendanceEntity> list;
  const RahbarKundalikLoaded(this.list);
  @override
  List<Object?> get props => [list];
}

class RahbarPayrollLoaded extends RahbarState {
  final List<RahbarPayrollItemEntity> list;
  const RahbarPayrollLoaded(this.list);
  @override
  List<Object?> get props => [list];
}

class RahbarArizalarLoaded extends RahbarState {
  final List<RahbarArizaEntity> list;
  const RahbarArizalarLoaded(this.list);
  @override
  List<Object?> get props => [list];
}

class RahbarError extends RahbarState {
  final String message;
  const RahbarError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class RahbarBloc extends Bloc<RahbarEvent, RahbarState> {
  final RahbarRemoteDataSource remoteDataSource;

  RahbarBloc({required this.remoteDataSource}) : super(RahbarInitial()) {
    on<RahbarLoginSubmitted>(_onLogin);
    on<LoadRahbarDashboard>(_onLoadDashboard);
    on<LoadRahbarKundalik>(_onLoadKundalik);
    on<LoadRahbarPayroll>(_onLoadPayroll);
    on<LoadRahbarArizalar>(_onLoadArizalar);
    on<ReviewRahbarAriza>(_onReviewAriza);
  }

  Future<void> _onLogin(
    RahbarLoginSubmitted event,
    Emitter<RahbarState> emit,
  ) async {
    emit(RahbarLoading());
    try {
      final user = await remoteDataSource.login(event.login, event.password);
      emit(RahbarAuthSuccess(user));
    } catch (e) {
      emit(RahbarError(DioRetryHelper.formatErrorMessage(e)));
    }
  }

  Future<void> _onLoadDashboard(
    LoadRahbarDashboard event,
    Emitter<RahbarState> emit,
  ) async {
    emit(RahbarLoading());
    try {
      final dashboard = await remoteDataSource.getDashboard(date: event.date);
      emit(RahbarDashboardLoaded(dashboard));
    } catch (e) {
      emit(RahbarError(DioRetryHelper.formatErrorMessage(e)));
    }
  }

  Future<void> _onLoadKundalik(
    LoadRahbarKundalik event,
    Emitter<RahbarState> emit,
  ) async {
    emit(RahbarLoading());
    try {
      final list = await remoteDataSource.getKundalik(date: event.date);
      emit(RahbarKundalikLoaded(list));
    } catch (e) {
      emit(RahbarError(DioRetryHelper.formatErrorMessage(e)));
    }
  }

  Future<void> _onLoadPayroll(
    LoadRahbarPayroll event,
    Emitter<RahbarState> emit,
  ) async {
    emit(RahbarLoading());
    try {
      final list = await remoteDataSource.getPayroll(month: event.month);
      emit(RahbarPayrollLoaded(list));
    } catch (e) {
      emit(RahbarError(DioRetryHelper.formatErrorMessage(e)));
    }
  }

  Future<void> _onLoadArizalar(
    LoadRahbarArizalar event,
    Emitter<RahbarState> emit,
  ) async {
    emit(RahbarLoading());
    try {
      final list = await remoteDataSource.getArizalar();
      emit(RahbarArizalarLoaded(list));
    } catch (e) {
      emit(RahbarError(DioRetryHelper.formatErrorMessage(e)));
    }
  }

  Future<void> _onReviewAriza(
    ReviewRahbarAriza event,
    Emitter<RahbarState> emit,
  ) async {
    try {
      await remoteDataSource.reviewAriza(
        event.arizaId,
        event.action,
        comment: event.comment,
      );
      add(LoadRahbarArizalar());
    } catch (e) {
      emit(RahbarError(DioRetryHelper.formatErrorMessage(e)));
    }
  }
}
