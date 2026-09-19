import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/widgets/no_internet_view.dart';
import 'package:skore_hodimlar/core/widgets/notification_bell_button.dart';
import 'package:skore_hodimlar/core/widgets/skor_logo_widget.dart';
import 'package:skore_hodimlar/features/applications/domain/entities/ariza_entity.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPhone();
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('ariza_cancel_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 19,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          context.tr('ariza_cancel_confirm', {
            'name': ariza.turiNomi,
            'date': ariza.fromDate,
          }),
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            color: const Color(0xFF4B5563),
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
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
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
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
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
            color: const Color(0xFF0D6E6E),
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
                labelColor: const Color(0xFF0D6E6E),
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: const Color(0xFF0D6E6E),
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
        backgroundColor: const Color(0xFF0D6E6E),
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
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
          );
        } else if (state is ArizalarLoaded) {
          final list = state.list;
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _loadData(_tabController.index),
              color: const Color(0xFF0D6E6E),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('ariza_empty_title'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('ariza_empty_desc'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
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
            onRefresh: () async => _loadData(_tabController.index),
            color: const Color(0xFF0D6E6E),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
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
