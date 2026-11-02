import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/theme/theme_cubit.dart';

/// Appearance picker (system / light / dark). Shared between the staff
/// profile and the rahbar dashboard.
class ThemePickerBottomSheet {
  static void show(BuildContext context) {
    final cubit = context.read<ThemeCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Rebuilds live while the sheet is open, so the sheet itself previews
      // the chosen theme before it is dismissed.
      builder: (ctx) =>
          BlocProvider.value(value: cubit, child: const _ThemePickerContent()),
    );
  }

  static IconData iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };

  static String labelKeyFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'theme_system',
    ThemeMode.light => 'theme_light',
    ThemeMode.dark => 'theme_dark',
  };
}

class _ThemePickerContent extends StatelessWidget {
  const _ThemePickerContent();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = context.watch<ThemeCubit>().state;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: c.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('select_theme'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('select_theme_desc'),
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final mode in ThemeMode.values)
                _ThemeOption(mode: mode, isSelected: mode == current),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemeMode mode;
  final bool isSelected;

  const _ThemeOption({required this.mode, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelKey = ThemePickerBottomSheet.labelKeyFor(mode);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? c.primarySoft : c.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? c.primary : c.border,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.read<ThemeCubit>().changeTheme(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  ThemePickerBottomSheet.iconFor(mode),
                  size: 26,
                  color: isSelected ? c.primary : c.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(labelKey),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected ? c.primary : c.textPrimary,
                        ),
                      ),
                      Text(
                        context.tr('${labelKey}_desc'),
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: c.onPrimary,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
