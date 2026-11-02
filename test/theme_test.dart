import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/theme/app_theme.dart';
import 'package:skore_hodimlar/core/theme/theme_cubit.dart';
import 'package:skore_hodimlar/core/widgets/custom_animated_bottom_nav_bar.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';
import 'package:skore_hodimlar/core/widgets/no_internet_view.dart';
import 'package:skore_hodimlar/core/widgets/shimmer_loading_widget.dart';
import 'package:skore_hodimlar/core/widgets/theme_picker_bottom_sheet.dart';

/// WCAG relative-luminance contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) * 1.0;
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Minimal app shell mirroring main.dart's theme wiring, without the DI /
/// Firebase / plugin setup the real app needs.
class _ThemedHost extends StatelessWidget {
  final Widget child;
  const _ThemedHost({required this.child});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeCubit>().state;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      locale: AppLanguage.english.locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate],
      home: Scaffold(body: child),
    );
  }
}

Future<ThemeCubit> _cubit([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return ThemeCubit(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // No network or bundled Roboto in tests: google_fonts reports the missing
  // font asynchronously. Build both themes once in a guarded zone so those
  // font-loading errors are swallowed; text falls back to the test font.
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await runZonedGuarded(() async {
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (_, _) {});
  });

  group('ThemeCubit', () {
    test('defaults to following the system', () async {
      final cubit = await _cubit();
      expect(cubit.state, ThemeMode.system);
    });

    test('restores the saved mode on startup', () async {
      final cubit = await _cubit({ThemeCubit.prefKey: 'dark'});
      expect(cubit.state, ThemeMode.dark);
    });

    test('falls back to system for corrupt saved values', () async {
      final cubit = await _cubit({ThemeCubit.prefKey: 'purple'});
      expect(cubit.state, ThemeMode.system);
    });

    test('persists changes so they survive a restart', () async {
      final cubit = await _cubit();
      await cubit.changeTheme(ThemeMode.light);
      expect(cubit.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeCubit.prefKey), 'light');
      expect(ThemeCubit(prefs).state, ThemeMode.light);
    });
  });

  group('AppPalette', () {
    for (final (name, p) in [
      ('light', AppPalette.light),
      ('dark', AppPalette.dark),
    ]) {
      test('$name: text is readable (WCAG AA) on surfaces', () {
        for (final bg in [p.background, p.surface, p.surfaceVariant]) {
          expect(_contrast(p.textPrimary, bg), greaterThanOrEqualTo(7.0));
        }
        // Secondary text sits on cards/sheets; AA there.
        for (final bg in [p.surface, p.surfaceVariant]) {
          expect(_contrast(p.textSecondary, bg), greaterThanOrEqualTo(4.5));
        }
        // Original light palette: #6B7280 on #F2F2F7 is 4.33:1 — just under
        // AA. Kept as-is to preserve the existing light design.
        expect(_contrast(p.textSecondary, p.background), greaterThan(4.3));
        // Hints and brand-colored text/icons: large-text / UI threshold.
        expect(_contrast(p.textHint, p.surface), greaterThanOrEqualTo(2.5));
        expect(_contrast(p.primary, p.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.error, p.surface), greaterThanOrEqualTo(4.0));
        expect(_contrast(p.success, p.surface), greaterThanOrEqualTo(3.0));
      });

      test('$name: white labels stay legible on filled primary buttons', () {
        expect(_contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(3.0));
      });
    }

    test('lerp hits both ends exactly (animated theme switch)', () {
      final l = AppPalette.light, d = AppPalette.dark;
      expect(l.lerp(d, 0).surface, l.surface);
      expect(l.lerp(d, 1).surface, d.surface);
      expect(l.lerp(d, 1).textPrimary, d.textPrimary);
      expect(l.lerp(null, 0.5), same(l));
    });

    test('copyWith overrides only the given token', () {
      final p = AppPalette.light.copyWith(primary: Colors.pink);
      expect(p.primary, Colors.pink);
      expect(p.surface, AppPalette.light.surface);
    });
  });

  group('AppTheme', () {
    test('light and dark themes carry matching brightness and palette', () {
      final light = AppTheme.lightTheme, dark = AppTheme.darkTheme;
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.extension<AppPalette>(), AppPalette.light);
      expect(dark.extension<AppPalette>(), AppPalette.dark);
      expect(dark.scaffoldBackgroundColor, AppPalette.dark.background);
      expect(dark.colorScheme.surface, AppPalette.dark.surface);
      expect(dark.colorScheme.onSurface, AppPalette.dark.textPrimary);
      expect(dark.textTheme.bodyMedium?.color, AppPalette.dark.textPrimary);
    });

    test('themes are cached (no rebuild of ThemeData per frame)', () {
      expect(identical(AppTheme.darkTheme, AppTheme.darkTheme), isTrue);
    });

    test('status bar icons contrast with the background', () {
      expect(
        AppTheme.overlayStyleFor(Brightness.dark).statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        AppTheme.overlayStyleFor(Brightness.light).statusBarIconBrightness,
        Brightness.dark,
      );
    });
  });

  group('Widgets follow the selected theme', () {
    testWidgets('context.colors resolves per mode and updates live', (
      tester,
    ) async {
      final cubit = await _cubit({ThemeCubit.prefKey: 'light'});
      late AppPalette seen;
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: _ThemedHost(
            child: Builder(
              builder: (context) {
                seen = context.colors;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(seen, AppPalette.light);

      await cubit.changeTheme(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(seen, AppPalette.dark);
    });

    testWidgets('system mode follows platform brightness', (tester) async {
      final cubit = await _cubit();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      late AppPalette seen;
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: _ThemedHost(
            child: Builder(
              builder: (context) {
                seen = context.colors;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen, AppPalette.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(seen, AppPalette.light);
    });

    testWidgets('picker sheet switches the whole app to dark', (tester) async {
      final cubit = await _cubit({ThemeCubit.prefKey: 'light'});
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: _ThemedHost(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => ThemePickerBottomSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(cubit.state, ThemeMode.dark);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        Theme.of(tester.element(find.byWidget(scaffold))).brightness,
        Brightness.dark,
      );
      // The open sheet re-themes itself instantly (live preview).
      expect(tester.takeException(), isNull);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('shared widgets render cleanly in ${mode.name} mode', (
        tester,
      ) async {
        final cubit = await _cubit({ThemeCubit.prefKey: mode.name});
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: _ThemedHost(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 360, child: NoInternetView()),
                    const ShimmerSkeleton(width: 100, height: 20),
                    const SizedBox(
                      height: 700,
                      child: LocationDisclosureDialog(),
                    ),
                    CustomAnimatedBottomNavBar(
                      selectedIndex: 0,
                      onItemTapped: (_) {},
                      items: const [
                        CustomBottomNavItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          label: 'Home',
                        ),
                        CustomBottomNavItem(
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        final expected = mode == ThemeMode.dark
            ? AppPalette.dark
            : AppPalette.light;
        final ctx = tester.element(find.byType(NoInternetView));
        expect(ctx.colors, expected);
      });
    }
  });
}
