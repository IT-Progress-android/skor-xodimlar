import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';

/// Bo'sh yoki xato holatlarda "Yangilash" tugmasi o'rniga ko'rsatiladigan
/// kichik ishora: sahifani pastga tortib yangilash mumkin.
class PullToRefreshHint extends StatelessWidget {
  const PullToRefreshHint({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.textHint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.south_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr('pull_to_refresh_hint'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12.5, color: color),
          ),
        ),
      ],
    );
  }
}

/// [child] ni ekran balandligi bo'ylab markazda joylashtiradi va har doim
/// aylantiriladigan qiladi — shunda ustidagi `RefreshIndicator` bo'sh
/// holatda ham pastga tortishni ushlaydi. Balandlik cheklanmagan joyda
/// (masalan boshqa ro'yxat ichida) [child] o'zgarishsiz qaytariladi.
class ScrollableFill extends StatelessWidget {
  final Widget child;
  const ScrollableFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

/// [ScrollableFill] + o'zining `RefreshIndicator` i. Ustida boshqa
/// `RefreshIndicator` bo'lmagan alohida bo'sh/xato holatlar uchun.
class RefreshableFill extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const RefreshableFill({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ScrollableFill(child: child),
    );
  }
}

/// Bloc/Cubit'ga hodisa yuborilgach, [isDone] holati kelguncha kutadi —
/// `RefreshIndicator` aylanasi ma'lumot haqiqatan kelganda yopiladi.
Future<void> refreshAndWait<S>(
  StateStreamable<S> bloc,
  void Function() trigger,
  bool Function(S state) isDone,
) async {
  final done = bloc.stream
      .firstWhere(isDone)
      .timeout(const Duration(seconds: 30), onTimeout: () => bloc.state);
  trigger();
  await done;
}

/// Natija qaytarmaydigan qayta yuklash funksiyalari uchun: aylana hech
/// bo'lmasa qisqa vaqt ko'rinib turadi.
Future<void> refreshWithMinDelay(FutureOr<void> Function() action) async {
  await Future.wait([
    Future.sync(action),
    Future<void>.delayed(const Duration(milliseconds: 600)),
  ]);
}
