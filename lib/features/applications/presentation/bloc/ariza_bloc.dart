import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/cancel_ariza_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/get_ariza_types_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/get_arizalar_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/submit_ariza_usecase.dart';

abstract class ArizaEvent extends Equatable {
  const ArizaEvent();
  @override
  List<Object?> get props => [];
}

class LoadArizalar extends ArizaEvent {
  final String phone;
  final int? staffId;
  final String? status;

  const LoadArizalar(this.phone, {this.staffId, this.status});

  @override
  List<Object?> get props => [phone, staffId, status];
}

class LoadArizaTurlari extends ArizaEvent {
  final String phone;
  final int? staffId;

  const LoadArizaTurlari(this.phone, {this.staffId});

  @override
  List<Object?> get props => [phone, staffId];
}

class SubmitAriza extends ArizaEvent {
  final String phone;
  final int? staffId;
  final String fromDate;
  final String toDate;
  final String turi;
  final String? izoh;

  const SubmitAriza({
    required this.phone,
    this.staffId,
    required this.fromDate,
    required this.toDate,
    required this.turi,
    this.izoh,
  });

  @override
  List<Object?> get props => [phone, staffId, fromDate, toDate, turi, izoh];
}

class CancelAriza extends ArizaEvent {
  final String phone;
  final int? staffId;
  final int arizaId;

  const CancelAriza({required this.phone, this.staffId, required this.arizaId});

  @override
  List<Object?> get props => [phone, staffId, arizaId];
}

abstract class ArizaState extends Equatable {
  const ArizaState();
  @override
  List<Object?> get props => [];
}

class ArizaInitial extends ArizaState {}

class ArizaLoading extends ArizaState {}

class ArizalarLoaded extends ArizaState {
  final List<ArizaEntity> list;
  final ArizaSummaryEntity summary;

  const ArizalarLoaded(this.list, this.summary);

  @override
  List<Object?> get props => [list, summary];
}

class ArizaTurlariLoaded extends ArizaState {
  final List<ArizaTuriEntity> list;

  const ArizaTurlariLoaded(this.list);

  @override
  List<Object?> get props => [list];
}

class ArizaSubmitted extends ArizaState {
  final ArizaEntity ariza;

  const ArizaSubmitted(this.ariza);

  @override
  List<Object?> get props => [ariza];
}

class ArizaCancelled extends ArizaState {
  final String message;

  const ArizaCancelled(this.message);

  @override
  List<Object?> get props => [message];
}

class ArizaError extends ArizaState {
  final String message;

  const ArizaError(this.message);

  @override
  List<Object?> get props => [message];
}

class ArizaBloc extends Bloc<ArizaEvent, ArizaState> {
  final GetArizalarUseCase getArizalar;
  final GetArizaTypesUseCase getArizaTypes;
  final SubmitArizaUseCase submitAriza;
  final CancelArizaUseCase cancelAriza;

  ArizaBloc({
    required this.getArizalar,
    required this.getArizaTypes,
    required this.submitAriza,
    required this.cancelAriza,
  }) : super(ArizaInitial()) {
    on<LoadArizalar>((event, emit) async {
      emit(ArizaLoading());
      final result = await getArizalar(
        event.phone,
        staffId: event.staffId,
        status: event.status,
      );
      result.fold(
        (failure) => emit(ArizaError(failure.message)),
        (res) => emit(ArizalarLoaded(res.arizalar, res.summary)),
      );
    });

    on<LoadArizaTurlari>((event, emit) async {
      emit(ArizaLoading());
      final result = await getArizaTypes(event.phone, staffId: event.staffId);
      result.fold(
        (failure) => emit(ArizaError(failure.message)),
        (list) => emit(ArizaTurlariLoaded(list)),
      );
    });

    on<SubmitAriza>((event, emit) async {
      emit(ArizaLoading());
      final result = await submitAriza(
        SubmitArizaParams(
          phone: event.phone,
          staffId: event.staffId,
          fromDate: event.fromDate,
          toDate: event.toDate,
          turi: event.turi,
          izoh: event.izoh,
        ),
      );
      result.fold(
        (failure) => emit(ArizaError(failure.message)),
        (ariza) => emit(ArizaSubmitted(ariza)),
      );
    });

    on<CancelAriza>((event, emit) async {
      emit(ArizaLoading());
      final result = await cancelAriza(
        event.phone,
        event.arizaId,
        staffId: event.staffId,
      );
      result.fold(
        (failure) => emit(ArizaError(failure.message)),
        (msg) => emit(ArizaCancelled(msg)),
      );
    });
  }
}
