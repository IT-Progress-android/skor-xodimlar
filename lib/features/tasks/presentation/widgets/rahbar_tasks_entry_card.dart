import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/tasks/presentation/pages/rahbar_tasks_page.dart';

/// Rahbar bosh sahifasidagi "Topshiriqlar" kirish kartasi.
class RahbarTasksEntryCard extends StatelessWidget {
  const RahbarTasksEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RahbarTasksPage()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedRotatingBorderContainer(
          margin: EdgeInsets.zero,
          borderRadius: 16,
          borderWidth: 2.0,
          gradientColors: [
            c.primary,
            const Color(0xFF139797),
            const Color(0xFF26BBAA),
            c.primary,
          ],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    color: c.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('task_title'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('task_entry_desc'),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
