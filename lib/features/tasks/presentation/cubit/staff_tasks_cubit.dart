import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/utils/app_error_formatter.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';

enum LoadStatus { initial, loading, loaded, error }

String taskErrorText(Object e) =>
    e is TaskApiException ? e.message : AppErrorFormatter.toUzbek(e);

// ------------------------------------------------------------ Ro'yxat

class StaffTasksState extends Equatable {
  /// `faol` yoki `bajarilgan` (TZ, xodim API).
  final String tab;
  final LoadStatus status;
  final List<StaffTask> items;
  final PageMeta meta;
  final bool loadingMore;
  final String? error;

  const StaffTasksState({
    this.tab = 'faol',
    this.status = LoadStatus.initial,
    this.items = const [],
    this.meta = const PageMeta(),
    this.loadingMore = false,
    this.error,
  });

  StaffTasksState copyWith({
    String? tab,
    LoadStatus? status,
    List<StaffTask>? items,
    PageMeta? meta,
    bool? loadingMore,
    String? error,
  }) {
    return StaffTasksState(
      tab: tab ?? this.tab,
      status: status ?? this.status,
      items: items ?? this.items,
      meta: meta ?? this.meta,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [tab, status, items, meta, loadingMore, error];
}

class StaffTasksCubit extends Cubit<StaffTasksState> {
  final TaskRemoteDataSource ds;
  StaffTasksCubit(this.ds) : super(const StaffTasksState());

  Future<void> load({String? tab}) async {
    final t = tab ?? state.tab;
    emit(
      state.copyWith(
        tab: t,
        status: state.items.isEmpty || t != state.tab
            ? LoadStatus.loading
            : state.status,
        items: t != state.tab ? const [] : null,
      ),
    );
    try {
      final res = await ds.getMyTasks(holat: t);
      if (isClosed || t != state.tab) return;
      emit(
        state.copyWith(
          status: LoadStatus.loaded,
          items: res.items,
          meta: res.meta,
        ),
      );
    } catch (e) {
      if (isClosed || t != state.tab) return;
      emit(state.copyWith(status: LoadStatus.error, error: taskErrorText(e)));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.meta.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final res = await ds.getMyTasks(
        holat: state.tab,
        page: state.meta.page + 1,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          items: [...state.items, ...res.items],
          meta: res.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }
}

// ------------------------------------------------------------ Batafsil

class StaffTaskDetailState extends Equatable {
  final LoadStatus status;
  final StaffTask? task;
  final bool submitting;
  final String? error;

  /// "Bajardim" muvaffaqiyatli bo'lgach bir marta `true` bo'ladi.
  final bool justCompleted;

  /// 404/410: topshiriq bekor qilingan yoki boshqaga o'tkazilgan.
  final bool gone;

  const StaffTaskDetailState({
    this.status = LoadStatus.initial,
    this.task,
    this.submitting = false,
    this.error,
    this.justCompleted = false,
    this.gone = false,
  });

  StaffTaskDetailState copyWith({
    LoadStatus? status,
    StaffTask? task,
    bool? submitting,
    String? error,
    bool? justCompleted,
    bool? gone,
  }) {
    return StaffTaskDetailState(
      status: status ?? this.status,
      task: task ?? this.task,
      submitting: submitting ?? this.submitting,
      error: error,
      justCompleted: justCompleted ?? false,
      gone: gone ?? this.gone,
    );
  }

  @override
  List<Object?> get props => [
    status,
    task,
    submitting,
    error,
    justCompleted,
    gone,
  ];
}

class StaffTaskDetailCubit extends Cubit<StaffTaskDetailState> {
  final TaskRemoteDataSource ds;
  final int taskId;
  StaffTaskDetailCubit(this.ds, this.taskId)
    : super(const StaffTaskDetailState());

  Future<void> load() async {
    if (state.task == null) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final t = await ds.getMyTask(taskId);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.loaded, task: t));
    } catch (e) {
      if (isClosed) return;
      final gone =
          e is TaskApiException && (e.statusCode == 404 || e.statusCode == 410);
      emit(
        state.copyWith(
          status: LoadStatus.error,
          error: taskErrorText(e),
          gone: gone,
        ),
      );
    }
  }

  Future<void> markDone(String? comment) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    try {
      final t = await ds.markDone(taskId, comment: comment);
      if (!isClosed) {
        emit(
          state.copyWith(
            submitting: false,
            task: t,
            status: LoadStatus.loaded,
            justCompleted: true,
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      final code = e is TaskApiException ? e.statusCode : null;
      emit(
        state.copyWith(
          submitting: false,
          error: taskErrorText(e),
          gone: code == 410,
        ),
      );
      // 409: allaqachon bajarilgan — haqiqiy holatni qayta yuklaymiz.
      if (code == 409) await load();
    }
  }
}
