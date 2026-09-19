import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/errors/failures.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/auth/domain/entities/staff_entity.dart';
import 'package:skore_hodimlar/features/auth/domain/usecases/login_usecase.dart';

// Events
abstract class AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String phone;

  /// Tizim (badge) raqami — bitta telefonga bir nechta xodim mos kelganda
  /// (PHONE_AMBIGUOUS) kimligini aniqlash uchun.
  final String? personCode;

  LoginSubmitted(this.phone, {this.personCode});
}

class StaffSelected extends AuthEvent {
  final StaffEntity staff;
  StaffSelected(this.staff);
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final StaffEntity staff;
  final String phone;
  AuthSuccess(this.staff, this.phone);
}

class AuthMultiple extends AuthState {
  final List<StaffEntity> staffList;
  final String phone;
  AuthMultiple(this.staffList, this.phone);
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

/// Bitta raqamga bir nechta xodim mos keldi — server tizim (badge) raqamini
/// so'rayapti. UI raqam so'raydigan oyna ko'rsatib, `LoginSubmitted` ni
/// `personCode` bilan qayta yuboradi.
class AuthNeedsPersonCode extends AuthState {
  final String phone;
  final String message;
  AuthNeedsPersonCode(this.phone, this.message);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;

  AuthBloc(this.loginUseCase) : super(AuthInitial()) {
    on<LoginSubmitted>((event, emit) async {
      debugPrint(
        '🔐 [AUTH BLOC] LoginSubmitted -> phone: ${event.phone} | '
        'personCode: ${event.personCode}',
      );
      emit(AuthLoading());

      // Eski token boshqa xodimga tegishli bo'lishi mumkin — tozalab olamiz.
      await AuthTokenStore.instance.clear();

      final result = await loginUseCase(
        event.phone,
        personCode: event.personCode,
      );

      await result.fold(
        (failure) async {
          if (failure is PhoneAmbiguousFailure) {
            debugPrint(
              '⚠️ [AUTH BLOC] AuthNeedsPersonCode -> ${failure.message}',
            );
            emit(AuthNeedsPersonCode(event.phone, failure.message));
            return;
          }
          debugPrint('❌ [AUTH BLOC] AuthFailure -> ${failure.message}');
          emit(AuthFailure(AppErrorFormatter.sanitizeMessage(failure.message)));
        },
        (login) async {
          debugPrint(
            '🔐 [AUTH BLOC] loginUseCase natijasi -> staff soni: '
            '${login.staff.length} | selectRequired: ${login.selectRequired} '
            '| token: ${login.token != null && login.token!.isNotEmpty ? "bor" : "yoq"}',
          );
          if (login.staff.isEmpty) {
            debugPrint('❌ [AUTH BLOC] staff ro\'yxati bo\'sh keldi');
            emit(
              AuthFailure(
                AppLocalizations.trStatic('err_phone_not_registered'),
              ),
            );
            return;
          }

          // Bitta xodim: server tokenni darhol beradi (yangi backend'da).
          if (login.staff.length == 1 && !login.selectRequired) {
            final staff = login.staff.first;
            await _saveSession(event.phone, staff, login.token);
            debugPrint(
              '✅ [AUTH BLOC] AuthSuccess -> staffId: ${staff.id} | '
              'phone: ${event.phone}',
            );
            emit(AuthSuccess(staff, event.phone));
            return;
          }

          // Bir nechta tashkilot: tanlash kerak, token keyin olinadi.
          await _savePhoneOnly(event.phone);
          debugPrint(
            '🔐 [AUTH BLOC] AuthMultiple -> ${login.staff.length} ta xodim '
            'tanlash kerak',
          );
          emit(AuthMultiple(login.staff, event.phone));
        },
      );
    });

    on<StaffSelected>((event, emit) async {
      final currentState = state;
      if (currentState is! AuthMultiple) return;

      final phone = currentState.phone;
      debugPrint(
        '🔐 [AUTH BLOC] StaffSelected -> staffId: ${event.staff.id} | '
        'phone: $phone',
      );
      emit(AuthLoading());

      // Tanlangan xodim uchun token so'raymiz. Backend hali tokenni joriy
      // qilmagan bo'lsa, javob eskicha keladi — token null bo'ladi va oqim
      // avvalgidek davom etadi.
      final result = await loginUseCase(phone, staffId: event.staff.id);

      final token = result.fold((_) => null, (login) => login.token);
      await _saveSession(phone, event.staff, token);
      debugPrint(
        '✅ [AUTH BLOC] AuthSuccess (StaffSelected) -> staffId: '
        '${event.staff.id}',
      );
      emit(AuthSuccess(event.staff, phone));
    });
  }

  Future<void> _saveSession(
    String phone,
    StaffEntity staff,
    String? token,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
    await prefs.setString('staff_phone', phone);
    await prefs.setInt('staff_id', staff.id);
    await prefs.setString('person_code', staff.personCode ?? '');
    if (token != null && token.isNotEmpty) {
      await AuthTokenStore.instance.save(token);
    }
  }

  Future<void> _savePhoneOnly(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
    await prefs.setString('staff_phone', phone);
  }
}
