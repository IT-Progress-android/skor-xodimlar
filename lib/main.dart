import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/security/app_lock_gate.dart';
import 'package:skore_hodimlar/core/security/app_lock_service.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/services/network_connectivity_service.dart';
import 'package:skore_hodimlar/core/services/notification_storage_service.dart';
import 'package:skore_hodimlar/core/theme/app_theme.dart';
import 'package:skore_hodimlar/core/theme/theme_cubit.dart';
import 'package:skore_hodimlar/core/widgets/app_update_gate.dart';
import 'package:skore_hodimlar/core/widgets/global_offline_banner.dart';
import 'package:skore_hodimlar/features/applications/presentation/bloc/ariza_bloc.dart';
import 'package:skore_hodimlar/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:skore_hodimlar/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:skore_hodimlar/features/face_verify/presentation/bloc/face_verify_bloc.dart';
import 'package:skore_hodimlar/features/lookup/presentation/bloc/lookup_bloc.dart';
import 'package:skore_hodimlar/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/firebase_options.dart';
import 'package:skore_hodimlar/router/app_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // UI (selfie camera, slide-to-check-in, bottom nav) is designed for
  // portrait only; landscape on short phones squeezes and overflows it.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM/GPS xizmatlari LanguageCubit qurilishidan OLDIN, widget daraxtisiz
  // ishga tushadi — aks holda ular til bridge'ining standart (uz) holatida
  // ishlab qolar edi. Saqlangan tilni shu yerda qo'lda yuklab qo'yamiz.
  final prefs = await SharedPreferences.getInstance();
  AppLocalizations.setCurrentLanguage(
    AppLanguage.fromCode(prefs.getString(LanguageCubit.prefKey)),
  );

  // FCM ilova ochilishini KUTMAYDI: ruxsat dialogi, token olish va serverga
  // yozish tarmoqqa bog'liq. Firebase ro'yxatdan o'tolmagan telefonda
  // (`FCM Registration failed`) bular uzoq qotib, ilova ruxsatdan keyin
  // ochilmay qolardi. Token keyinroq `onTokenRefresh` va bosh sahifada
  // qayta yoziladi.
  unawaited(FcmService.init());
  await NotificationStorageService.initialize();
  // Saqlangan xodim tokenini xotiraga yuklaymiz — DioClient'dagi
  // interceptor uni sinxron o'qiydi, shuning uchun DI'dan oldin.
  await AuthTokenStore.instance.load();
  await initDependencies();
  // Ilova qulfi (PIN / barmoq izi): saqlangan holat ilova chizilishidan
  // oldin o'qiladi — birinchi kadrdayoq qulf ko'rinsin.
  await AppLockService.instance.init(prefs);
  // Majburiy yangilanish talabi saqlangan bo'lsa — birinchi kadrdayoq
  // yangilash sahifasi (internetsiz ochilganda ham).
  await AppUpdateService.restoreForcedUpdate(prefs);
  // Use Texture Layer Hybrid Composition (AndroidView) instead of initExpensiveAndroidView
  // to avoid SurfaceFlinger + Flutter raster thread synchronization stalls during map panning.
  AndroidYandexMap.useAndroidViewSurface = false;

  // Internet aloqasini kuzatish xizmatini ishga tushiramiz
  NetworkConnectivityService.instance.init();

  // Initialize foreground task (must be called before startTracking)
  GpsLiveTrackerService.initForegroundTask();

  runApp(const SkoreHodimlarApp());
}

class SkoreHodimlarApp extends StatelessWidget {
  const SkoreHodimlarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<LanguageCubit>()),
        BlocProvider(create: (_) => sl<ThemeCubit>()),
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(create: (_) => sl<AttendanceBloc>()),
        BlocProvider(create: (_) => sl<FaceVerifyBloc>()),
        BlocProvider(create: (_) => sl<ArizaBloc>()),
        BlocProvider(create: (_) => sl<ProfileBloc>()),
        BlocProvider(create: (_) => sl<LookupBloc>()),
        BlocProvider(create: (_) => sl<RahbarBloc>()),
      ],
      child: Builder(
        builder: (context) {
          final langState = context.watch<LanguageCubit>().state;
          final themeMode = context.watch<ThemeCubit>().state;
          return MaterialApp.router(
            title: 'Skor Xodimlar',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
            locale: langState.locale,
            supportedLocales: AppLanguage.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final mediaQuery = MediaQuery.of(context);
                  // Screens without an AppBar still need status-bar icons
                  // that are readable on the current background.
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: AppTheme.overlayStyleFor(
                      Theme.of(context).brightness,
                    ),
                    child: MediaQuery(
                      data: mediaQuery.copyWith(
                        textScaler: mediaQuery.textScaler.clamp(
                          minScaleFactor: 0.85,
                          maxScaleFactor: 1.15,
                        ),
                      ),
                      // WithForegroundTask wraps the app to keep foreground service alive
                      // Majburiy yangilanishda ilova o'rniga yangilash sahifasi.
                      child: AppUpdateGate(
                        child: WithForegroundTask(
                          child: AppLockGate(
                            child: GlobalOfflineBanner(
                              child: _PhoneWidthFrame(
                                child: child ?? const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Screens are designed for phones. On tablets / unfolded foldables the
/// content is centered at a phone-like max width instead of stretching.
class _PhoneWidthFrame extends StatelessWidget {
  const _PhoneWidthFrame({required this.child});

  static const double _maxWidth = 600;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.size.width <= _maxWidth) return child;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: _maxWidth,
          // Descendants reading MediaQuery.size must see the framed width,
          // otherwise size-based layouts (sheets, camera circle) misjudge.
          child: MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(_maxWidth, mediaQuery.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
