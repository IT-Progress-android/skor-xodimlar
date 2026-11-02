import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/tasks/data/models/task_models.dart';
import 'package:skore_hodimlar/features/tasks/presentation/task_ui.dart';

/// Davr turi (kun / hafta / oy / yil) va oldinga/orqaga surish.
class TaskPeriodBar extends StatelessWidget {
  final TaskPeriod period;
  final DateTime sana;
  final TaskPeriodRange? range;
  final ValueChanged<TaskPeriod> onPeriod;
  final ValueChanged<int> onShift;

  const TaskPeriodBar({
    super.key,
    required this.period,
    required this.sana,
    required this.range,
    required this.onPeriod,
    required this.onShift,
  });

  String _label(BuildContext context) {
    switch (period) {
      case TaskPeriod.kun:
        return TaskUi.date(context, sana, withTime: false);
      case TaskPeriod.hafta:
        final from =
            range?.dan ?? sana.subtract(Duration(days: sana.weekday - 1));
        final to = range?.gacha ?? from.add(const Duration(days: 6));
        return '${TaskUi.date(context, from, withTime: false)} – '
            '${TaskUi.date(context, to, withTime: false)}';
      case TaskPeriod.oy:
        return '${context.tr('task_month_full_${sana.month}')} ${sana.year}';
      case TaskPeriod.yil:
        return '${sana.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = DateTime.now();
    final isCurrent = switch (period) {
      TaskPeriod.kun =>
        sana.year == next.year &&
            sana.month == next.month &&
            sana.day == next.day,
      TaskPeriod.hafta =>
        next.difference(sana).inDays < 7 && !sana.isAfter(next),
      TaskPeriod.oy => sana.year == next.year && sana.month == next.month,
      TaskPeriod.yil => sana.year == next.year,
    };
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TaskPeriod>(
            segments: TaskPeriod.values
                .map(
                  (p) => ButtonSegment(
                    value: p,
                    label: Text(context.tr(p.translationKey)),
                  ),
                )
                .toList(),
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onPeriod(s.first),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              onPressed: () => onShift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                _label(context),
                textAlign: TextAlign.center,
                style: TaskUi.titleStyle(context, size: 15),
              ),
            ),
            IconButton(
              onPressed: isCurrent ? null : () => onShift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asosiy ko'rsatkichlar kartasi.
class TaskCountersCard extends StatelessWidget {
  final TaskCounters c;
  const TaskCountersCard({super.key, required this.c});

  String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    Widget cell(String key, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(key),
            textAlign: TextAlign.center,
            style: TaskUi.bodyStyle(context, size: 11.5),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: col.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: col.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              cell('task_stat_given', '${c.berilgan}', col.textPrimary),
              cell(
                'task_holat_ozvaqtida',
                '${c.ozvaqtida}',
                TaskUi.color(context, TaskHolat.ozvaqtida),
              ),
              cell(
                'task_holat_kechikib',
                '${c.kechikib}',
                TaskUi.color(context, TaskHolat.kechikib),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              cell(
                'task_holat_bajarilmadi',
                '${c.bajarilmadi}',
                TaskUi.color(context, TaskHolat.bajarilmadi),
              ),
              cell(
                'task_holat_otkazildi',
                '${c.otkazilgan}',
                TaskUi.color(context, TaskHolat.otkazildi),
              ),
              cell(
                'task_holat_jarayonda',
                '${c.jarayonda}',
                TaskUi.color(context, TaskHolat.jarayonda),
              ),
            ],
          ),
          Divider(height: 24, color: col.divider),
          Row(
            children: [
              cell('task_stat_done_pct', _pct(c.bajarishFoizi), col.success),
              cell('task_stat_ontime_pct', _pct(c.ozvaqtidaFoizi), col.primary),
              cell('task_stat_failed_pct', _pct(c.uddalamadiFoizi), col.error),
            ],
          ),
          if (c.qaytarilgan > 0) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('task_stat_returned', {'n': '${c.qaytarilgan}'}),
              style: TaskUi.bodyStyle(context, size: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Davr bo'laklari bo'yicha stacked ustunli grafik:
/// o'z vaqtida · kechikib · bajarilmadi · o'tkazilgan.
class TaskDynamicsChart extends StatelessWidget {
  final List<TaskDynamicsPoint> points;
  final TaskPeriod period;
  const TaskDynamicsChart({
    super.key,
    required this.points,
    required this.period,
  });

  String _xLabel(BuildContext context, String sana) {
    final d = DateTime.tryParse(sana);
    if (d == null) return sana;
    switch (period) {
      case TaskPeriod.yil:
        return context.tr('task_month_${d.month}');
      case TaskPeriod.hafta:
        return context.tr('task_weekday_${d.weekday}');
      case TaskPeriod.oy:
      case TaskPeriod.kun:
        return '${d.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    if (points.isEmpty) return const SizedBox.shrink();
    final segments = [
      (TaskHolat.ozvaqtida, (TaskDynamicsPoint p) => p.ozvaqtida),
      (TaskHolat.kechikib, (TaskDynamicsPoint p) => p.kechikib),
      (TaskHolat.bajarilmadi, (TaskDynamicsPoint p) => p.bajarilmadi),
      (TaskHolat.otkazildi, (TaskDynamicsPoint p) => p.otkazilgan),
    ];
    int total(TaskDynamicsPoint p) =>
        segments.fold(0, (s, seg) => s + seg.$2(p));
    // Bitta kunda grafik bitta keng ustun bo'lib qoladi va tushunarsiz —
    // o'rniga shu kun natijasini holatlar bo'yicha ko'rsatamiz.
    if (period == TaskPeriod.kun) {
      final p = points.first;
      final sum = total(p);
      if (sum == 0) return const SizedBox.shrink();
      return _DayBreakdown(
        parts: [for (final s in segments) (s.$1, s.$2(p))],
        total: sum,
      );
    }
    final maxV = points.map(total).fold(0, (a, b) => a > b ? a : b);
    const chartH = 120.0;
    // Oy kunlarida yorliqlar zich bo'lmasligi uchun har 5-kunni yozamiz.
    final labelEvery = period == TaskPeriod.oy ? 5 : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: col.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: col.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('task_dynamics'),
            style: TaskUi.titleStyle(context, size: 14.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: chartH + 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${points[i].sana}\n'
                          '${segments.map((s) => '${context.tr(s.$1.translationKey)}: ${s.$2(points[i])}').join('\n')}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1.5,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final seg in segments.reversed)
                                  if (seg.$2(points[i]) > 0)
                                    Container(
                                      height: maxV == 0
                                          ? 0
                                          : chartH * seg.$2(points[i]) / maxV,
                                      color: TaskUi.color(context, seg.$1),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 14,
                            child: (i % labelEvery == 0)
                                ? FittedBox(
                                    child: Text(
                                      _xLabel(context, points[i].sana),
                                      style: TaskUi.bodyStyle(
                                        context,
                                        size: 10,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: segments
                .map(
                  (s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: TaskUi.color(context, s.$1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(s.$1.translationKey),
                        style: TaskUi.bodyStyle(context, size: 11.5),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// "Kun" davri uchun: holatlar ulushi bitta chiziqda va ro'yxatda.
class _DayBreakdown extends StatelessWidget {
  final List<(TaskHolat, int)> parts;
  final int total;
  const _DayBreakdown({required this.parts, required this.total});

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final shown = parts.where((p) => p.$2 > 0).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: col.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: col.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('task_day_result', {'n': '$total'}),
            style: TaskUi.titleStyle(context, size: 14.5),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final p in shown)
                    Expanded(
                      flex: p.$2,
                      child: Container(color: TaskUi.color(context, p.$1)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: TaskUi.color(context, p.$1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr(p.$1.translationKey),
                      style: TaskUi.bodyStyle(context, size: 13),
                    ),
                  ),
                  Text(
                    '${p.$2}',
                    style: TaskUi.titleStyle(context, size: 13.5),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(p.$2 * 100 / total).round()}%',
                      textAlign: TextAlign.end,
                      style: TaskUi.bodyStyle(context, size: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
