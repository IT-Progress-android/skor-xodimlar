import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/cubit/staff_tasks_cubit.dart';

// ------------------------------------------------------------ Ro'yxat

class RahbarTasksState extends Equatable {
  /// `null` = hammasi; aks holda TZ'dagi `holat` filtri.
  final String? holat;
  final String query;
  final LoadStatus status;
  final List<RahbarTaskSummary> items;
  final PageMeta meta;
  final bool loadingMore;
  final String? error;

  /// Tanlangan filial; `null` — barcha filiallar. Ro'yxat endpoint'ida
  /// filial yo'q, shuning uchun ilovada filtrlanadi.
  final String? filial;

  /// Topshiriq id → uning ijrochilari biriktirilgan filiallar (tafsilotdan).
  final Map<int, Set<String>> taskFilials;

  const RahbarTasksState({
    this.holat,
    this.query = '',
    this.status = LoadStatus.initial,
    this.items = const [],
    this.meta = const PageMeta(),
    this.loadingMore = false,
    this.error,
    this.filial,
    this.taskFilials = const {},
  });

  /// Ro'yxatdagi topshiriqlarda uchragan barcha filiallar.
  List<String> get filials =>
      distinctFilials(taskFilials.values.expand((s) => s));

  /// Filial tanlangan bo'lsa — faqat shu filial xodimiga berilganlar.
  /// Filiali hali aniqlanmagan topshiriqlar bu holda ko'rsatilmaydi.
  List<RahbarTaskSummary> get visibleItems => filial == null
      ? items
      : items
            .where((t) => taskFilials[t.id]?.contains(filial) ?? false)
            .toList();

  /// Filiali hali yuklanmagan topshiriqlar bormi (filtr natijasi to'liq emas).
  bool get filialsPending => items.any((t) => !taskFilials.containsKey(t.id));

  RahbarTasksState copyWith({
    String? Function()? holat,
    String? query,
    LoadStatus? status,
    List<RahbarTaskSummary>? items,
    PageMeta? meta,
    bool? loadingMore,
    String? error,
    String? Function()? filial,
    Map<int, Set<String>>? taskFilials,
  }) {
    return RahbarTasksState(
      holat: holat != null ? holat() : this.holat,
      query: query ?? this.query,
      status: status ?? this.status,
      items: items ?? this.items,
      meta: meta ?? this.meta,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
      filial: filial != null ? filial() : this.filial,
      taskFilials: taskFilials ?? this.taskFilials,
    );
  }

  @override
  List<Object?> get props => [
    holat,
    query,
    status,
    items,
    meta,
    loadingMore,
    error,
    filial,
    taskFilials,
  ];
}

class RahbarTasksCubit extends Cubit<RahbarTasksState> {
  final TaskRemoteDataSource ds;
  int _req = 0;
  RahbarTasksCubit(this.ds) : super(const RahbarTasksState());

  void setFilter(String? holat) {
    if (holat == state.holat) return;
    emit(state.copyWith(holat: () => holat, items: const []));
    load();
  }

  void setFilial(String? f) {
    if (f == state.filial) return;
    emit(state.copyWith(filial: () => f));
  }

  /// Hali filiali aniqlanmagan topshiriqlar tafsilotini 4 tadan parallel
  /// yuklab, ijrochilarning filiallarini yig'adi. Natija cubit ichida
  /// keshlanadi — har topshiriq uchun bir marta so'raladi.
  Future<void> _loadFilials(List<RahbarTaskSummary> items) async {
    final todo = items
        .map((t) => t.id)
        .where((id) => !state.taskFilials.containsKey(id) && _filialReq.add(id))
        .toList();
    for (var i = 0; i < todo.length; i += 4) {
      final batch = todo.skip(i).take(4).toList();
      final results = await Future.wait(
        batch.map((id) async {
          try {
            final d = await ds.getTask(id);
            return MapEntry(id, {
              for (final x in d.xodimlar)
                if ((x.filial ?? '').trim().isNotEmpty) x.filial!.trim(),
            });
          } catch (_) {
            _filialReq.remove(id); // keyingi yuklashda qayta urinamiz
            return null;
          }
        }),
      );
      if (isClosed) return;
      final map = Map<int, Set<String>>.from(state.taskFilials);
      for (final r in results) {
        if (r != null) map[r.key] = r.value;
      }
      emit(state.copyWith(taskFilials: map));
    }
  }

  final Set<int> _filialReq = {};

  void setQuery(String q) {
    if (q == state.query) return;
    emit(state.copyWith(query: q));
    load();
  }

  static List<RahbarTaskSummary> _sortLatest(List<RahbarTaskSummary> list) {
    final copy = List<RahbarTaskSummary>.from(list);
    copy.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        final c = b.createdAt!.compareTo(a.createdAt!);
        if (c != 0) return c;
      }
      return b.id.compareTo(a.id);
    });
    return copy;
  }

  Future<void> load() async {
    final req = ++_req;
    if (state.items.isEmpty) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final res = await ds.getTasks(holat: state.holat, qidiruv: state.query);
      if (isClosed || req != _req) return;
      emit(
        state.copyWith(
          status: LoadStatus.loaded,
          items: _sortLatest(res.items),
          meta: res.meta,
        ),
      );
      unawaited(_loadFilials(res.items));
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
      final res = await ds.getTasks(
        holat: state.holat,
        qidiruv: state.query,
        page: state.meta.page + 1,
      );
      if (isClosed || req != _req) return;
      emit(
        state.copyWith(
          items: _sortLatest([...state.items, ...res.items]),
          meta: res.meta,
          loadingMore: false,
        ),
      );
      unawaited(_loadFilials(res.items));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }
}

// ------------------------------------------------------------ Batafsil

class RahbarTaskDetailState extends Equatable {
  final LoadStatus status;
  final RahbarTaskDetail? task;
  final bool busy;
  final String? error;

  /// Amal muvaffaqiyatli bajarilgach ko'rsatiladigan xabar (bir martalik).
  final String? message;

  const RahbarTaskDetailState({
    this.status = LoadStatus.initial,
    this.task,
    this.busy = false,
    this.error,
    this.message,
  });

  RahbarTaskDetailState copyWith({
    LoadStatus? status,
    RahbarTaskDetail? task,
    bool? busy,
    String? error,
    String? message,
  }) {
    return RahbarTaskDetailState(
      status: status ?? this.status,
      task: task ?? this.task,
      busy: busy ?? this.busy,
      error: error,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, task, busy, error, message];
}

class RahbarTaskDetailCubit extends Cubit<RahbarTaskDetailState> {
  final TaskRemoteDataSource ds;
  final int taskId;

  /// Ro'yxat ekrani qaytganda yangilanishi kerakligini bildiradi.
  bool changed = false;

  RahbarTaskDetailCubit(this.ds, this.taskId)
    : super(const RahbarTaskDetailState());

  Future<void> load() async {
    if (state.task == null) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final t = await ds.getTask(taskId);
      if (!isClosed) emit(state.copyWith(status: LoadStatus.loaded, task: t));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: LoadStatus.error, error: taskErrorText(e)));
      }
    }
  }

  Future<bool> _run(Future<void> Function() action, String successKey) async {
    if (state.busy) return false;
    emit(state.copyWith(busy: true));
    try {
      await action();
      changed = true;
      final t = await ds.getTask(taskId);
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            task: t,
            status: LoadStatus.loaded,
            message: AppLocalizations.trStatic(successKey),
          ),
        );
      }
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(busy: false, error: taskErrorText(e)));
      // 409: holat boshqa joyda o'zgargan — eng so'nggi holatni ko'rsatamiz.
      if (e is TaskApiException && e.statusCode == 409) await load();
      return false;
    }
  }

  Future<bool> edit({String? title, String? description, DateTime? deadline}) =>
      _run(
        () => ds.updateTask(
          taskId,
          title: title,
          description: description,
          deadline: deadline,
        ),
        'task_msg_updated',
      );

  Future<bool> cancel() =>
      _run(() => ds.cancelTask(taskId), 'task_msg_cancelled');

  Future<bool> addHelpers(List<int> ids, DateTime? muddat) => _run(
    () => ds.addHelpers(taskId, ids, muddat: muddat),
    'task_msg_helpers_added',
  );

  Future<bool> setDeadline(int staffId, DateTime muddat) => _run(
    () => ds.setStaffDeadline(taskId, staffId, muddat),
    'task_msg_deadline_set',
  );

  Future<bool> transfer(
    int staffId,
    int toStaffId,
    String? izoh,
    DateTime? muddat,
  ) => _run(
    () => ds.transfer(
      taskId,
      staffId,
      yangiStaffId: toStaffId,
      izoh: izoh,
      muddat: muddat,
    ),
    'task_msg_transferred',
  );

  Future<bool> returnTask(int staffId, String izoh, DateTime? muddat) => _run(
    () => ds.returnTask(taskId, staffId, izoh: izoh, yangiMuddat: muddat),
    'task_msg_returned',
  );

  Future<bool> remove(int staffId) =>
      _run(() => ds.removeStaff(taskId, staffId), 'task_msg_removed');
}

// ------------------------------------------------------------ Xodim tanlash

class StaffPickerState extends Equatable {
  final LoadStatus status;
  final List<PickableStaff> staff;
  final String? error;
  const StaffPickerState({
    this.status = LoadStatus.initial,
    this.staff = const [],
    this.error,
  });

  @override
  List<Object?> get props => [status, staff, error];
}

/// Xodimlar ro'yxati bir marta yuklanadi va yaratish, yordamchi qo'shish,
/// o'tkazish oynalarida qayta ishlatiladi.
class StaffPickerCubit extends Cubit<StaffPickerState> {
  final TaskRemoteDataSource ds;
  StaffPickerCubit(this.ds) : super(const StaffPickerState());

  Future<void> load({bool force = false}) async {
    if (!force && state.status == LoadStatus.loaded) return;
    emit(const StaffPickerState(status: LoadStatus.loading));
    try {
      final list = await ds.getPickableStaff();
      if (!isClosed) {
        emit(StaffPickerState(status: LoadStatus.loaded, staff: list));
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          StaffPickerState(status: LoadStatus.error, error: taskErrorText(e)),
        );
      }
    }
  }
}
