import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_state.dart';
import 'package:skore_hodimlar/core/services/auth_token_store.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/services/gps_live_tracker_service.dart';
import 'package:skore_hodimlar/core/services/network_connectivity_service.dart';
import 'package:skore_hodimlar/core/services/notification_storage_service.dart';
import 'package:skore_hodimlar/core/theme/app_theme.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM/GPS xizmatlari LanguageCubit qurilishidan OLDIN, widget daraxtisiz
  // ishga tushadi — aks holda ular til bridge'ining standart (uz) holatida
  // ishlab qolar edi. Saqlangan tilni shu yerda qo'lda yuklab qo'yamiz.
  final prefs = await SharedPreferences.getInstance();
  AppLocalizations.setCurrentLanguage(
    AppLanguage.fromCode(prefs.getString(LanguageCubit.prefKey)),
  );

  await FcmService.init();
  await NotificationStorageService.initialize();
  // Saqlangan xodim tokenini xotiraga yuklaymiz — DioClient'dagi
  // interceptor uni sinxron o'qiydi, shuning uchun DI'dan oldin.
  await AuthTokenStore.instance.load();
  await initDependencies();
  AndroidYandexMap.useAndroidViewSurface = true;

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
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(create: (_) => sl<AttendanceBloc>()),
        BlocProvider(create: (_) => sl<FaceVerifyBloc>()),
        BlocProvider(create: (_) => sl<ArizaBloc>()),
        BlocProvider(create: (_) => sl<ProfileBloc>()),
        BlocProvider(create: (_) => sl<LookupBloc>()),
        BlocProvider(create: (_) => sl<RahbarBloc>()),
      ],
      child: BlocBuilder<LanguageCubit, LanguageState>(
        builder: (context, langState) {
          return MaterialApp.router(
            title: 'Skor Xodimlar',
            theme: AppTheme.lightTheme,
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
                  return MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: mediaQuery.textScaler.clamp(
                        minScaleFactor: 0.85,
                        maxScaleFactor: 1.15,
                      ),
                    ),
                    // WithForegroundTask wraps the app to keep foreground service alive
                    child: WithForegroundTask(
                      child: GlobalOfflineBanner(
                        child: child ?? const SizedBox.shrink(),
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
