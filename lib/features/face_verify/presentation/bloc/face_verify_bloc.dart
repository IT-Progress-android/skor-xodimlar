import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/face_verify/domain/entities/face_verify_entity.dart';
import 'package:skore_hodimlar/features/face_verify/domain/usecases/face_verify_usecase.dart';

abstract class FaceVerifyEvent extends Equatable {
  const FaceVerifyEvent();
  @override
  List<Object?> get props => [];
}

class VerifyFace extends FaceVerifyEvent {
  final String phone;
  final Uint8List imageBytes;
  final String? staffId;

  const VerifyFace({
    required this.phone,
    required this.imageBytes,
    this.staffId,
  });

  @override
  List<Object?> get props => [phone, imageBytes, staffId];
}

abstract class FaceVerifyState extends Equatable {
  const FaceVerifyState();
  @override
  List<Object?> get props => [];
}

class FaceVerifyInitial extends FaceVerifyState {}

class FaceVerifying extends FaceVerifyState {}

class FaceVerifyMatched extends FaceVerifyState {
  final FaceVerifyEntity entity;
  const FaceVerifyMatched(this.entity);
  @override
  List<Object> get props => [entity];
}

class FaceVerifyNotMatched extends FaceVerifyState {
  final String message;
  final bool retryable;
  final FaceVerifyEntity? entity;
  const FaceVerifyNotMatched(
    this.message, {
    this.retryable = true,
    this.entity,
  });
  @override
  List<Object?> get props => [message, retryable, entity];
}

class FaceVerifyError extends FaceVerifyState {
  final String message;
  const FaceVerifyError(this.message);
  @override
  List<Object> get props => [message];
}

class FaceVerifyEngineDown extends FaceVerifyState {
  final String message;
  final FaceVerifyEntity? entity;
  const FaceVerifyEngineDown(this.message, {this.entity});
  @override
  List<Object?> get props => [message, entity];
}

class FaceVerifyBloc extends Bloc<FaceVerifyEvent, FaceVerifyState> {
  final FaceVerifyUseCase faceVerifyUseCase;

  FaceVerifyBloc({required this.faceVerifyUseCase})
    : super(FaceVerifyInitial()) {
    on<VerifyFace>((event, emit) async {
      emit(FaceVerifying());
      try {
        final result = await faceVerifyUseCase(
          event.phone,
          event.imageBytes,
          staffId: event.staffId,
        );
        if (result.matched) {
          emit(FaceVerifyMatched(result));
        } else if (result.status == 'engine_error') {
          emit(FaceVerifyEngineDown(result.displayMessage, entity: result));
        } else {
          emit(
            FaceVerifyNotMatched(
              result.displayMessage,
              retryable: result.retryable,
              entity: result,
            ),
          );
        }
      } catch (e) {
        emit(FaceVerifyError(AppErrorFormatter.toUzbek(e)));
      }
    });
  }
}
