import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_cubit.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
// Applications
import 'package:skore_hodimlar/features/applications/data/datasources/ariza_remote_datasource.dart';
import 'package:skore_hodimlar/features/applications/data/repositories/ariza_repository_impl.dart';
import 'package:skore_hodimlar/features/applications/domain/repositories/ariza_repository.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/cancel_ariza_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/get_ariza_types_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/get_arizalar_usecase.dart';
import 'package:skore_hodimlar/features/applications/domain/usecases/submit_ariza_usecase.dart';
import 'package:skore_hodimlar/features/applications/presentation/bloc/ariza_bloc.dart';
// Attendance
import 'package:skore_hodimlar/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:skore_hodimlar/features/attendance/data/datasources/geofence_remote_datasource.dart';
import 'package:skore_hodimlar/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:skore_hodimlar/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:skore_hodimlar/features/attendance/domain/usecases/check_location_usecase.dart';
import 'package:skore_hodimlar/features/attendance/domain/usecases/get_period_attendance_usecase.dart';
import 'package:skore_hodimlar/features/attendance/domain/usecases/get_today_attendance_usecase.dart';
import 'package:skore_hodimlar/features/attendance/presentation/bloc/attendance_bloc.dart';
// Auth
import 'package:skore_hodimlar/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:skore_hodimlar/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:skore_hodimlar/features/auth/domain/repositories/auth_repository.dart';
import 'package:skore_hodimlar/features/auth/domain/usecases/login_usecase.dart';
import 'package:skore_hodimlar/features/auth/presentation/bloc/auth_bloc.dart';
// Face Verify
import 'package:skore_hodimlar/features/face_verify/data/datasources/face_remote_datasource.dart';
import 'package:skore_hodimlar/features/face_verify/data/repositories/face_repository_impl.dart';
import 'package:skore_hodimlar/features/face_verify/domain/repositories/face_repository.dart';
import 'package:skore_hodimlar/features/face_verify/domain/usecases/face_verify_usecase.dart';
import 'package:skore_hodimlar/features/face_verify/presentation/bloc/face_verify_bloc.dart';
// Lookup
import 'package:skore_hodimlar/features/lookup/data/datasources/lookup_remote_datasource.dart';
import 'package:skore_hodimlar/features/lookup/data/repositories/lookup_repository_impl.dart';
import 'package:skore_hodimlar/features/lookup/domain/repositories/lookup_repository.dart';
import 'package:skore_hodimlar/features/lookup/domain/usecases/get_metadata_usecase.dart';
import 'package:skore_hodimlar/features/lookup/domain/usecases/get_tashkilotlar_usecase.dart';
import 'package:skore_hodimlar/features/lookup/presentation/bloc/lookup_bloc.dart';
// Profile
import 'package:skore_hodimlar/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:skore_hodimlar/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:skore_hodimlar/features/profile/domain/repositories/profile_repository.dart';
import 'package:skore_hodimlar/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:skore_hodimlar/features/profile/presentation/bloc/profile_bloc.dart';
// Rahbar (Admin)
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core
  final dioClient = DioClient();
  sl.registerLazySingleton<DioClient>(() => dioClient);

  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  sl.registerLazySingleton<LanguageCubit>(
    () => LanguageCubit(sl<SharedPreferences>()),
  );

  // --- Auth ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<DioClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => AuthBloc(sl<LoginUseCase>()));

  // --- Attendance & Geofence ---
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<GeofenceRemoteDataSource>(
    () => GeofenceRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(sl<AttendanceRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetTodayAttendanceUseCase(sl<AttendanceRepository>()),
  );
  sl.registerLazySingleton(
    () => GetPeriodAttendanceUseCase(sl<AttendanceRepository>()),
  );
  sl.registerLazySingleton(
    () => CheckLocationUseCase(sl<AttendanceRepository>()),
  );
  sl.registerFactory(
    () => AttendanceBloc(
      getTodayAttendanceUseCase: sl(),
      getPeriodAttendanceUseCase: sl(),
      checkLocationUseCase: sl(),
    ),
  );

  // --- Face Verify ---
  sl.registerLazySingleton<FaceRemoteDataSource>(
    () => FaceRemoteDataSourceImpl(sl<DioClient>().dio),
  );
  sl.registerLazySingleton<FaceRepository>(
    () => FaceRepositoryImpl(sl<FaceRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => FaceVerifyUseCase(sl<FaceRepository>()));
  sl.registerFactory(() => FaceVerifyBloc(faceVerifyUseCase: sl()));

  // --- Applications ---
  sl.registerLazySingleton<ArizaRemoteDataSource>(
    () => ArizaRemoteDataSourceImpl(dioClient: sl<DioClient>()),
  );
  sl.registerLazySingleton<ArizaRepository>(
    () => ArizaRepositoryImpl(remoteDataSource: sl<ArizaRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetArizalarUseCase(sl<ArizaRepository>()));
  sl.registerLazySingleton(() => GetArizaTypesUseCase(sl<ArizaRepository>()));
  sl.registerLazySingleton(() => SubmitArizaUseCase(sl<ArizaRepository>()));
  sl.registerLazySingleton(() => CancelArizaUseCase(sl<ArizaRepository>()));
  sl.registerFactory(
    () => ArizaBloc(
      getArizalar: sl(),
      getArizaTypes: sl(),
      submitAriza: sl(),
      cancelAriza: sl(),
    ),
  );

  // --- Profile ---
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(dioClient: sl<DioClient>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () =>
        ProfileRepositoryImpl(remoteDataSource: sl(), sharedPreferences: sl()),
  );
  sl.registerLazySingleton(() => GetProfileUseCase(sl<ProfileRepository>()));
  sl.registerFactory(() => ProfileBloc(getProfile: sl(), repository: sl()));

  // --- Lookup ---
  sl.registerLazySingleton<LookupRemoteDataSource>(
    () => LookupRemoteDataSourceImpl(dioClient: sl<DioClient>()),
  );
  sl.registerLazySingleton<LookupRepository>(
    () => LookupRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => GetTashkilotlarUseCase(sl<LookupRepository>()),
  );
  sl.registerLazySingleton(() => GetMetadataUseCase(sl<LookupRepository>()));
  sl.registerFactory(
    () =>
        LookupBloc(getTashkilotlar: sl(), getMetadata: sl(), repository: sl()),
  );

  // --- Rahbar (Admin) ---
  sl.registerLazySingleton<RahbarRemoteDataSource>(
    () => RahbarRemoteDataSourceImpl(
      dioClient: sl<DioClient>(),
      sharedPreferences: sl<SharedPreferences>(),
    ),
  );
  sl.registerFactory(
    () => RahbarBloc(remoteDataSource: sl<RahbarRemoteDataSource>()),
  );
}
