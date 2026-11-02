import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/services/app_update_service.dart';
import 'package:skore_hodimlar/core/widgets/app_update_bottom_sheet.dart';

/// Butun ilova ustidagi majburiy yangilanish darvozasi.
///
/// [AppUpdateService.forcedUpdate] to'lsa, ilova (router va barcha
/// sahifalar, bottom navigation ham) daraxtdan butunlay olinib, o'rniga
/// [ForceUpdatePage] qo'yiladi — ostida bosiladigan, surib yopiladigan yoki
/// "orqaga" bilan qaytiladigan hech narsa qolmaydi. Android'da "orqaga"
/// ilovani yopadi, iOS'da chetdan surish ishlamaydi.
///
/// Tekshiruv ilova ochilganda va har safar fondan qaytganda qayta qilinadi:
/// foydalanuvchi do'kondan yangilamay qaytsa ham sahifa turaveradi.
class AppUpdateGate extends StatefulWidget {
  final Widget child;
  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: AppUpdateService.refresh);
    AppUpdateService.refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUpdateInfo?>(
      valueListenable: AppUpdateService.forcedUpdate,
      builder: (context, forced, _) =>
          forced == null ? widget.child : ForceUpdatePage(updateInfo: forced),
    );
  }
}

/// Majburiy yangilanish sahifasi: faqat "Yangilash" tugmasi bor.
class ForceUpdatePage extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  const ForceUpdatePage({super.key, required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AppUpdateContent(updateInfo: updateInfo),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
