import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/features/profile/domain/entities/profile_entity.dart';
import 'package:skore_hodimlar/features/profile/domain/repositories/profile_repository.dart';
import 'package:skore_hodimlar/features/profile/domain/usecases/get_profile_usecase.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {
  final String phone;
  final int? staffId;
  const LoadProfile(this.phone, {this.staffId});
  @override
  List<Object?> get props => [phone, staffId];
}

class UploadPhotoSubmitted extends ProfileEvent {
  final String phone;
  final int staffId;
  final File photoFile;
  const UploadPhotoSubmitted({
    required this.phone,
    required this.staffId,
    required this.photoFile,
  });
  @override
  List<Object?> get props => [phone, staffId, photoFile];
}

class ChangePhoneSubmitted extends ProfileEvent {
  final String currentPhone;
  final int staffId;
  final String newPhone9Digits;
  const ChangePhoneSubmitted({
    required this.currentPhone,
    required this.staffId,
    required this.newPhone9Digits,
  });
  @override
  List<Object?> get props => [currentPhone, staffId, newPhone9Digits];
}

class LogoutProfile extends ProfileEvent {}

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfilePhotoUploading extends ProfileState {}

class ProfilePhoneChanging extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileEntity entity;
  final String photoUrl;
  final String? hikNote;
  final String? successMessage;
  const ProfileLoaded({
    required this.entity,
    required this.photoUrl,
    this.hikNote,
    this.successMessage,
  });
  @override
  List<Object?> get props => [entity, photoUrl, hikNote, successMessage];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfile;
  final ProfileRepository repository;

  ProfileBloc({required this.getProfile, required this.repository})
    : super(ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      emit(ProfileLoading());
      final result = await getProfile(event.phone, staffId: event.staffId);
      if (result.isLeft()) {
        final failure = result.fold((l) => l, (r) => null)!;
        emit(ProfileError(failure.message));
      } else {
        final profile = result.fold((l) => null, (r) => r)!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('staff_name', profile.name);
        await prefs.setString('staff_full_name', profile.name);
        // Davomat ekrani kamerani ochishdan oldin shuni tekshiradi.
        // DIQQAT: `has_face` (yuz vektori) emas, `has_photo` (etalon rasm)
        // muhim — vektor bo'lmasa ham rasm bo'yicha tekshirish ishlaydi.
        await prefs.setBool('has_reference_photo', profile.hasPhoto);
        final photoUrl =
            profile.photoUrl ??
            'https://bot.timepay.uz/bot/staff/photo/raw?person_code=${profile.personCode}';
        emit(ProfileLoaded(entity: profile, photoUrl: photoUrl));
      }
    });

    on<UploadPhotoSubmitted>((event, emit) async {
      emit(ProfilePhotoUploading());

      final result = await repository.uploadPhoto(
        event.phone,
        event.staffId,
        event.photoFile,
      );
      result.fold((failure) => emit(ProfileError(failure.message)), (
        uploadRes,
      ) {
        // Re-fetch profile to get updated entity
        add(LoadProfile(event.phone, staffId: event.staffId));
      });
    });

    on<ChangePhoneSubmitted>((event, emit) async {
      emit(ProfilePhoneChanging());
      final result = await repository.changePhone(
        event.currentPhone,
        event.staffId,
        event.newPhone9Digits,
      );
      result.fold((failure) => emit(ProfileError(failure.message)), (phoneRes) {
        // Re-fetch profile with new phone
        add(LoadProfile(phoneRes.newPhone, staffId: event.staffId));
      });
    });

    on<LogoutProfile>((event, emit) async {
      await repository.logout();
      emit(ProfileInitial());
    });
  }
}
