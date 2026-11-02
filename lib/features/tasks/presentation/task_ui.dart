import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/shimmer_loading_widget.dart';
import 'package:skore_hodimlar/features/tasks/data/datasources/task_remote_datasource.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';

/// Topshiriqlar ekranlari uchun umumiy formatlash va kichik vidjetlar.
class TaskUi {
  /// TZ: har qanday muddat hozirdan kamida 1 soat keyin bo'lishi shart.
  static const minLead = Duration(hours: 1);

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// "Bugun, 18:00" / "Ertaga, 09:30" / "5-okt, 18:00".
  static String date(
    BuildContext context,
    DateTime? d, {
    bool withTime = true,
  }) {
    if (d == null) return '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    String datePart;
    if (diff == 0) {
      datePart = context.tr('today');
    } else if (diff == 1) {
      datePart = context.tr('task_tomorrow');
    } else if (diff == -1) {
      datePart = context.tr('task_yesterday');
    } else {
      datePart = context.tr('task_date_short', {
        'day': '${d.day}',
        'month': context.tr('task_month_${d.month}'),
        'year': d.year == now.year ? '' : ' ${d.year}',
      }).trim();
    }
    return withTime ? '$datePart, ${time(d)}' : datePart;
  }

  /// "3 soat qoldi" / "2 kun qoldi" / "45 daqiqa kechikdi".
  static String remaining(BuildContext context, DateTime? deadline) {
    if (deadline == null) return '';
    final diff = deadline.difference(DateTime.now());
    final late = diff.isNegative;
    final abs = diff.abs();
    String amount;
    if (abs.inDays >= 1) {
      amount = context.tr('task_n_days', {'n': '${abs.inDays}'});
    } else if (abs.inHours >= 1) {
      amount = context.tr('task_n_hours', {'n': '${abs.inHours}'});
    } else {
      final m = abs.inMinutes < 1 ? 1 : abs.inMinutes;
      amount = context.tr('task_n_minutes', {'n': '$m'});
    }
    return context.tr(late ? 'task_overdue_by' : 'task_left', {
      'amount': amount,
    });
  }

  static Color color(BuildContext context, TaskHolat h) {
    final c = context.colors;
    switch (h) {
      case TaskHolat.jarayonda:
        return c.info;
      case TaskHolat.bajarilmadi:
        return c.error;
      case TaskHolat.ozvaqtida:
        return c.success;
      case TaskHolat.kechikib:
        return c.warning;
      case TaskHolat.bekor:
      case TaskHolat.otkazildi:
        return c.textSecondary;
    }
  }

  static Color soft(BuildContext context, TaskHolat h) {
    final c = context.colors;
    switch (h) {
      case TaskHolat.jarayonda:
        return c.infoSoft;
      case TaskHolat.bajarilmadi:
        return c.errorSoft;
      case TaskHolat.ozvaqtida:
        return c.successSoft;
      case TaskHolat.kechikib:
        return c.warningSoft;
      case TaskHolat.bekor:
      case TaskHolat.otkazildi:
        return c.surfaceStrong;
    }
  }

  static IconData icon(TaskHolat h) {
    switch (h) {
      case TaskHolat.jarayonda:
        return Icons.schedule_rounded;
      case TaskHolat.bajarilmadi:
        return Icons.error_outline_rounded;
      case TaskHolat.ozvaqtida:
        return Icons.check_circle_rounded;
      case TaskHolat.kechikib:
        return Icons.history_toggle_off_rounded;
      case TaskHolat.bekor:
        return Icons.block_rounded;
      case TaskHolat.otkazildi:
        return Icons.swap_horiz_rounded;
    }
  }

  static TextStyle titleStyle(BuildContext context, {double size = 16}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      );

  static TextStyle bodyStyle(BuildContext context, {double size = 13.5}) =>
      GoogleFonts.outfit(
        fontSize: size,
        color: context.colors.textSecondary,
        height: 1.35,
      );

  static void snack(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? context.colors.error
              : context.colors.success,
        ),
      );
  }

  /// Sana va vaqt tanlash. Muddat hozirdan kamida 1 soat keyin bo'lmasa
  /// ogohlantiradi va `null` qaytaradi.
  static Future<DateTime?> pickDeadline(
    BuildContext context, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final min = now.add(minLead);
    final start = initial != null && initial.isAfter(min)
        ? initial
        : DateTime(now.year, now.month, now.day, 18).isAfter(min)
        ? DateTime(now.year, now.month, now.day, 18)
        : min.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(min.year, min.month, min.day),
      lastDate: now.add(const Duration(days: 730)),
      helpText: context.tr('task_pick_date'),
    );
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      helpText: context.tr('task_pick_time'),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !context.mounted) return null;
    final result = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (result.isBefore(DateTime.now().add(minLead))) {
      snack(context, context.tr('task_err_min_deadline'), error: true);
      return null;
    }
    return result;
  }
}

/// Holat yorlig'i (rangli chip).
class TaskHolatChip extends StatelessWidget {
  final TaskHolat holat;
  final bool dense;
  const TaskHolatChip({super.key, required this.holat, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final color = TaskUi.color(context, holat);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: TaskUi.soft(context, holat),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TaskUi.icon(holat), size: dense ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            context.tr(holat.translationKey),
            style: GoogleFonts.outfit(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bo'sh ro'yxat yoki xato holati.
class TaskEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const TaskEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: context.colors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TaskUi.titleStyle(context),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TaskUi.bodyStyle(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ro'yxat yuklanayotgandagi skelet.
class TaskListSkeleton extends StatelessWidget {
  final double itemHeight;
  const TaskListSkeleton({super.key, this.itemHeight = 96});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: List.generate(
        5,
        (_) => ShimmerSkeleton(
          width: double.infinity,
          height: itemHeight,
          borderRadius: 16,
          margin: const EdgeInsets.only(bottom: 12),
        ),
      ),
    );
  }
}

/// Filiallar bo'yicha tab bar: «Hammasi» + tashkilotdagi har bir filial.
/// Filial ro'yxati `GET /rahbar/hisobot/filial` dan olinadi (keshlanadi);
/// [extraFilials] — ma'lumotlarda uchragan, katalogda yo'q nomlar.
/// Faqat 2 tadan ko'p filial bo'lsa ko'rinadi.
class TaskFilialTabs extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Iterable<String?> extraFilials;

  const TaskFilialTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.extraFilials = const [],
  });

  @override
  State<TaskFilialTabs> createState() => _TaskFilialTabsState();
}

class _TaskFilialTabsState extends State<TaskFilialTabs>
    with TickerProviderStateMixin {
  List<String> _dir = const [];
  TabController? _ctrl;

  @override
  void initState() {
    super.initState();
    sl<TaskRemoteDataSource>().getFilialDirectory().then((d) {
      if (mounted) setState(() => _dir = d.names);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  List<String> get _names => distinctFilials([..._dir, ...widget.extraFilials]);

  @override
  Widget build(BuildContext context) {
    final names = _names;
    if (names.length < 2) return const SizedBox.shrink();
    final index = widget.selected == null
        ? 0
        : (names.indexOf(widget.selected!) + 1).clamp(0, names.length);
    if (_ctrl == null || _ctrl!.length != names.length + 1) {
      _ctrl?.dispose();
      _ctrl = TabController(
        length: names.length + 1,
        vsync: this,
        initialIndex: index,
      );
    } else if (_ctrl!.index != index) {
      _ctrl!.index = index;
    }
    final col = context.colors;
    return ColoredBox(
      color: col.surface,
      child: TabBar(
        controller: _ctrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: col.primary,
        unselectedLabelColor: col.textSecondary,
        indicatorColor: col.primary,
        dividerColor: col.border,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        onTap: (i) => widget.onSelected(i == 0 ? null : names[i - 1]),
        tabs: [
          Tab(text: context.tr('task_filial_all')),
          for (final n in names)
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_mall_directory_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(n),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
