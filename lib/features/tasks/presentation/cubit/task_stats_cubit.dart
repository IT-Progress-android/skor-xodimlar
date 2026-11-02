import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';

/// Davrni oldinga/orqaga surish (kun / hafta / oy / yil).
DateTime shiftPeriod(TaskPeriod p, DateTime d, int step) {
  switch (p) {
    case TaskPeriod.kun:
      return DateTime(d.year, d.month, d.day + step);
    case TaskPeriod.hafta:
      return DateTime(d.year, d.month, d.day + 7 * step);
    case TaskPeriod.oy:
      return DateTime(d.year, d.month + step, 1);
    case TaskPeriod.yil:
      return DateTime(d.year + step, 1, 1);
  }
}

// ------------------------------------------------------------ Umumiy

class TaskStatsState extends Equatable {
  final TaskPeriod period;
  final DateTime sana;

  /// `hammasi`, `uddalamaganlar`, `kechikkanlar`.
  final String filtr;
  final String saralash;

  /// Tanlangan filial (ilovada filtrlanadi); `null` — barcha filiallar.
  final String? filial;
  final LoadStatus status;
  final TaskStatsResult? result;
  final List<TaskDynamicsPoint> dynamics;
  final String? error;

  const TaskStatsState({
    this.period = TaskPeriod.oy,
    required this.sana,
    this.filtr = 'hammasi',
    this.saralash = 'bajarish_foizi',
    this.filial,
    this.status = LoadStatus.initial,
    this.result,
    this.dynamics = const [],
    this.error,
  });

  TaskStatsState copyWith({
    TaskPeriod? period,
    DateTime? sana,
    String? filtr,
    String? saralash,
    Object? filial = _keep,
    LoadStatus? status,
    TaskStatsResult? result,
    List<TaskDynamicsPoint>? dynamics,
    String? error,
  }) {
    return TaskStatsState(
      period: period ?? this.period,
      sana: sana ?? this.sana,
      filtr: filtr ?? this.filtr,
      saralash: saralash ?? this.saralash,
      filial: identical(filial, _keep) ? this.filial : filial as String?,
      status: status ?? this.status,
      result: result ?? this.result,
      dynamics: dynamics ?? this.dynamics,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    period,
    sana,
    filtr,
    saralash,
    filial,
    status,
    result,
    dynamics,
    error,
  ];
}

const Object _keep = Object();

class TaskStatsCubit extends Cubit<TaskStatsState> {
  final TaskRemoteDataSource ds;
  int _req = 0;

  TaskStatsCubit(this.ds) : super(TaskStatsState(sana: DateTime.now()));

  void setPeriod(TaskPeriod p) {
    if (p == state.period) return;
    emit(state.copyWith(period: p, sana: DateTime.now()));
    load();
  }

  void shift(int step) {
    final next = shiftPeriod(state.period, state.sana, step);
    if (next.isAfter(DateTime.now()) && step > 0) return;
    emit(state.copyWith(sana: next));
    load();
  }

  void setFilter(String f) {
    if (f == state.filtr) return;
    emit(state.copyWith(filtr: f));
    load();
  }

  /// Filial bo'yicha filtr — serverga qayta so'rov yubormaydi.
  void setFilial(String? f) {
    if (f == state.filial) return;
    emit(state.copyWith(filial: f));
  }

  void setSort(String s) {
    if (s == state.saralash) return;
    emit(state.copyWith(saralash: s));
    load();
  }

  Future<void> load() async {
    final req = ++_req;
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        ds.getStats(
          davr: state.period,
          sana: state.sana,
          filtr: state.filtr,
          saralash: state.saralash,
          tartib: state.saralash == 'ism' ? 'asc' : 'desc',
        ),
        ds.getDynamics(davr: state.period, sana: state.sana),
      ]);
      if (isClosed || req != _req) return;
      emit(
        state.copyWith(
          status: LoadStatus.loaded,
          result: results[0] as TaskStatsResult,
          dynamics: results[1] as List<TaskDynamicsPoint>,
        ),
      );
    } catch (e) {
      if (isClosed || req != _req) return;
      emit(state.copyWith(status: LoadStatus.error, error: taskErrorText(e)));
    }
  }
}

// ------------------------------------------------------------ Bitta xodim

class StaffHistoryState extends Equatable {
  final TaskPeriod period;
  final DateTime sana;
  final String holat;
  final LoadStatus status;
  final TaskCounters counters;
  final List<StaffTaskHistoryItem> items;
  final List<TaskDynamicsPoint> dynamics;
  final PageMeta meta;
  final bool loadingMore;
  final String? error;

  const StaffHistoryState({
    required this.period,
    required this.sana,
    this.holat = 'hammasi',
    this.status = LoadStatus.initial,
    this.counters = const TaskCounters(),
    this.items = const [],
    this.dynamics = const [],
    this.meta = const PageMeta(),
    this.loadingMore = false,
    this.error,
  });

  StaffHistoryState copyWith({
    TaskPeriod? period,
    DateTime? sana,
    String? holat,
    LoadStatus? status,
    TaskCounters? counters,
    List<StaffTaskHistoryItem>? items,
    List<TaskDynamicsPoint>? dynamics,
    PageMeta? meta,
    bool? loadingMore,
    String? error,
  }) {
    return StaffHistoryState(
      period: period ?? this.period,
      sana: sana ?? this.sana,
      holat: holat ?? this.holat,
      status: status ?? this.status,
      counters: counters ?? this.counters,
      items: items ?? this.items,
      dynamics: dynamics ?? this.dynamics,
      meta: meta ?? this.meta,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    period,
    sana,
    holat,
    status,
    counters,
    items,
    dynamics,
    meta,
    loadingMore,
    error,
  ];
}

class StaffHistoryCubit extends Cubit<StaffHistoryState> {
  final TaskRemoteDataSource ds;
  final int staffId;
  int _req = 0;

  StaffHistoryCubit(
    this.ds,
    this.staffId, {
    required TaskPeriod period,
    required DateTime sana,
    String holat = 'hammasi',
  }) : super(StaffHistoryState(period: period, sana: sana, holat: holat));

  void setPeriod(TaskPeriod p) {
    if (p == state.period) return;
    emit(state.copyWith(period: p, sana: DateTime.now()));
    load();
  }

  void shift(int step) {
    final next = shiftPeriod(state.period, state.sana, step);
    if (next.isAfter(DateTime.now()) && step > 0) return;
    emit(state.copyWith(sana: next));
    load();
  }

  void setHolat(String h) {
    if (h == state.holat) return;
    emit(state.copyWith(holat: h, items: const []));
    load();
  }

  Future<void> load() async {
    final req = ++_req;
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        ds.getStaffHistory(
          staffId,
          davr: state.period,
          sana: state.sana,
          holat: state.holat,
        ),
        ds.getDynamics(davr: state.period, sana: state.sana, staffId: staffId),
      ]);
      if (isClosed || req != _req) return;
      final h = results[0] as StaffTaskHistory;
      emit(
        state.copyWith(
          status: LoadStatus.loaded,
          counters: h.counters,
          items: h.items,
          meta: h.meta,
          dynamics: results[1] as List<TaskDynamicsPoint>,
        ),
      );
    } catch (e) {
      if (isClosed || req != _req) return;
      emit(state.copyWith(status: LoadStatus.error, error: taskErrorText(e)));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.meta.hasMore) return;
    final req = _req;
    emit(state.copyWith(loadingMore: true));
    try {
      final h = await ds.getStaffHistory(
        staffId,
        davr: state.period,
        sana: state.sana,
        holat: state.holat,
        page: state.meta.page + 1,
      );
      if (isClosed || req != _req) return;
      emit(
        state.copyWith(
          items: [...state.items, ...h.items],
          meta: h.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }
}
