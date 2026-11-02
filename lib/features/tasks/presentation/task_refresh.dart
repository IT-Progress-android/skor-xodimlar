import 'dart:async';

import 'package:flutter/widgets.dart';

/// Topshiriq push'i kelganda yoki bosilganda — push'dagi `task_id`. Shu
/// topshiriq sahifasi ochiq turgan bo'lsa, u serverdan qayta yuklanadi
/// (masalan, rahbar tafsilotni ochib turganda xodim "Bajardim" qilsa).
final taskPushes = StreamController<int>.broadcast();

/// [child] dagi topshiriqni [taskPushes] da shu [taskId] kelganda va ilova
/// orqa fondan qaytganda [onRefresh] orqali yangilaydi.
class TaskAutoRefresh extends StatefulWidget {
  const TaskAutoRefresh({
    super.key,
    required this.taskId,
    required this.onRefresh,
    required this.child,
  });

  final int taskId;
  final VoidCallback onRefresh;
  final Widget child;

  @override
  State<TaskAutoRefresh> createState() => _TaskAutoRefreshState();
}

class _TaskAutoRefreshState extends State<TaskAutoRefresh>
    with WidgetsBindingObserver {
  late final StreamSubscription<int> _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = taskPushes.stream.listen((id) {
      if (id == widget.taskId) widget.onRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onRefresh();
  }

  @override
  void dispose() {
    _sub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
