import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/no_internet_view.dart';
import 'package:skore_hodimlar/core/widgets/notification_bell_button.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
import 'package:skore_hodimlar/features/applications/presentation/ariza_refresh.dart';
import 'package:skore_hodimlar/features/applications/presentation/bloc/ariza_bloc.dart';
import 'package:skore_hodimlar/features/applications/presentation/widgets/ariza_card.dart';
import 'package:skore_hodimlar/features/applications/presentation/widgets/new_application_bottom_sheet.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String?> _statusFilters = [
    null,
    'kutilmoqda',
    'tasdiqlandi',
    'rad_etildi',
  ];
  String? phone;
  int? staffId;
  late final StreamSubscription<String> _pushSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPhone();
    _pushSub = arizaPushes.stream.listen((type) {
      if (type == 'manual_review') _loadData(_tabController.index);
    });
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData(_tabController.index);
      }
    });
  }

  Future<void> _loadPhone() async {
    final prefs = sl<SharedPreferences>();
    phone = prefs.getString('phone') ?? prefs.getString('staff_phone');
    staffId = prefs.getInt('staff_id');
    _loadData(0);
  }

  void _loadData(int index) {
    if (phone != null && mounted) {
      final status = _statusFilters[index];
      context.read<ArizaBloc>().add(
        LoadArizalar(phone!, staffId: staffId, status: status),
      );
    }
  }

  void _confirmCancel(ArizaEntity ariza) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('ariza_cancel_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 19,
            color: context.colors.textPrimary,
          ),
        ),
        content: Text(
          context.tr('ariza_cancel_confirm', {
            'name': ariza.turiNomi,
            'date': ariza.fromDate,
          }),
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            color: context.colors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              context.tr('no'),
              style: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (phone != null) {
                context.read<ArizaBloc>().add(
                  CancelAriza(
                    phone: phone!,
                    staffId: staffId,
                    arizaId: ariza.id,
                  ),
                );
              }
            },
            child: Text(
              context.tr('ariza_cancel_yes'),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? context.colors.error
            : context.colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _pushSub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.colors.surface,
        elevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Tooltip(
              message: context.tr('refresh'),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _loadData(_tabController.index),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: SkorLogoWidget(
                    size: 34,
                    showText: false,
                    animateParticles: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          context.tr('applications_title'),
          style: GoogleFonts.outfit(
            color: context.colors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: const [NotificationBellButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: BlocBuilder<ArizaBloc, ArizaState>(
            builder: (context, state) {
              int hamma = 0;
              int kutilmoqda = 0;
              int tasdiqlandi = 0;
              int radEtildi = 0;

              if (state is ArizalarLoaded) {
                hamma = state.summary.jami;
                kutilmoqda = state.summary.kutilmoqda;
                tasdiqlandi = state.summary.tasdiqlandi;
                radEtildi = state.summary.radEtildi;
              }

              return TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: context.colors.primary,
                unselectedLabelColor: context.colors.textSecondary,
                indicatorColor: context.colors.primary,
                labelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    text: hamma > 0
                        ? '${context.tr('ariza_tab_all')} ($hamma)'
                        : context.tr('ariza_tab_all'),
                  ),
                  Tab(
                    text: kutilmoqda > 0
                        ? '${context.tr('ariza_tab_pending')} ($kutilmoqda)'
                        : context.tr('ariza_tab_pending'),
                  ),
                  Tab(
                    text: tasdiqlandi > 0
                        ? '${context.tr('ariza_tab_approved')} ($tasdiqlandi)'
                        : context.tr('ariza_tab_approved'),
                  ),
                  Tab(
                    text: radEtildi > 0
                        ? '${context.tr('ariza_tab_rejected')} ($radEtildi)'
                        : context.tr('ariza_tab_rejected'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: BlocListener<ArizaBloc, ArizaState>(
        listener: (context, state) {
          if (state is ArizaCancelled) {
            _showSnackBar(state.message, isError: false);
            _loadData(_tabController.index);
          } else if (state is ArizaError) {
            _showSnackBar(state.message, isError: true);
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: List.generate(4, (index) => _buildList()),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await NewApplicationBottomSheet.show(context);
          if (mounted) {
            _loadData(_tabController.index);
          }
        },
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          context.tr('ariza_new'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildList() {
    return BlocBuilder<ArizaBloc, ArizaState>(
      builder: (context, state) {
        if (state is ArizaLoading) {
          return Center(
            child: CircularProgressIndicator(color: context.colors.primary),
          );
        } else if (state is ArizalarLoaded) {
          final list = state.list;
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  refreshWithMinDelay(() => _loadData(_tabController.index)),
              color: context.colors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 64,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('ariza_empty_title'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('ariza_empty_desc'),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                refreshWithMinDelay(() => _loadData(_tabController.index)),
            color: context.colors.primary,
            child: ListView.builder(
              // Pastda "Yangi ariza" tugmasi oxirgi arizani yopmasin.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return ArizaCard(
                  ariza: item,
                  onCancel: () => _confirmCancel(item),
                );
              },
            ),
          );
        } else if (state is ArizaError) {
          final isNetwork =
              state.message.toLowerCase().contains('internet') ||
              state.message.toLowerCase().contains('tarmoq');
          return NoInternetView(
            title: isNetwork
                ? context.tr('no_internet_title')
                : context.tr('error_occurred_title'),
            message: state.message,
            onRetry: () => _loadData(_tabController.index),
          );
        }
        return const SizedBox();
      },
    );
  }
}
