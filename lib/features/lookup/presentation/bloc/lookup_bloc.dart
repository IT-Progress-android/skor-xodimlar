import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/metadata_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/tashkilot_entity.dart';
import 'package:skore_hodimlar/features/lookup/domain/repositories/lookup_repository.dart';
import 'package:skore_hodimlar/features/lookup/domain/usecases/get_metadata_usecase.dart';
import 'package:skore_hodimlar/features/lookup/domain/usecases/get_tashkilotlar_usecase.dart';

abstract class LookupEvent extends Equatable {
  const LookupEvent();
  @override
  List<Object?> get props => [];
}

class LoadTashkilotlar extends LookupEvent {}

class LoadMetadata extends LookupEvent {
  final String schoolName;
  final String? viloyat;
  final String? tuman;
  const LoadMetadata({required this.schoolName, this.viloyat, this.tuman});
  @override
  List<Object?> get props => [schoolName, viloyat, tuman];
}

class StoreStaff extends LookupEvent {
  final Map<String, dynamic> body;
  const StoreStaff(this.body);
  @override
  List<Object?> get props => [body];
}

abstract class LookupState extends Equatable {
  const LookupState();
  @override
  List<Object?> get props => [];
}

class LookupInitial extends LookupState {}

class LookupLoading extends LookupState {}

class TashkilotlarLoaded extends LookupState {
  final List<TashkilotEntity> list;
  const TashkilotlarLoaded(this.list);
  @override
  List<Object?> get props => [list];
}

class MetadataLoaded extends LookupState {
  final MetadataEntity entity;
  const MetadataLoaded(this.entity);
  @override
  List<Object?> get props => [entity];
}

class StaffStored extends LookupState {
  final String personCode;
  final String fullName;
  const StaffStored(this.personCode, this.fullName);
  @override
  List<Object?> get props => [personCode, fullName];
}

class LookupError extends LookupState {
  final String message;
  const LookupError(this.message);
  @override
  List<Object?> get props => [message];
}

class LookupBloc extends Bloc<LookupEvent, LookupState> {
  final GetTashkilotlarUseCase getTashkilotlar;
  final GetMetadataUseCase getMetadata;
  final LookupRepository repository;

  LookupBloc({
    required this.getTashkilotlar,
    required this.getMetadata,
    required this.repository,
  }) : super(LookupInitial()) {
    on<LoadTashkilotlar>((event, emit) async {
      emit(LookupLoading());
      final res = await getTashkilotlar();
      res.fold(
        (l) => emit(LookupError(AppLocalizations.trStatic('err_generic'))),
        (r) => emit(TashkilotlarLoaded(r)),
      );
    });

    on<LoadMetadata>((event, emit) async {
      emit(LookupLoading());
      final res = await getMetadata(
        GetMetadataParams(
          schoolName: event.schoolName,
          viloyat: event.viloyat,
          tuman: event.tuman,
        ),
      );
      res.fold(
        (l) => emit(LookupError(AppLocalizations.trStatic('err_generic'))),
        (r) => emit(MetadataLoaded(r)),
      );
    });

    on<StoreStaff>((event, emit) async {
      emit(LookupLoading());
      final res = await repository.storeStaff(event.body);
      res.fold(
        (l) => emit(LookupError(AppLocalizations.trStatic('err_generic'))),
        (r) {
          emit(
            StaffStored(
              r['person_code']?.toString() ?? '',
              r['full_name']?.toString() ?? '',
            ),
          );
        },
      );
    });
  }
}
