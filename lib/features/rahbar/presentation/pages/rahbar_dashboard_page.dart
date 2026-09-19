import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/core/widgets/language_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/shimmer_loading_widget.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_arizalar_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_kundalik_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

class RahbarDashboardPage extends StatefulWidget {
  const RahbarDashboardPage({super.key});

  @override
  State<RahbarDashboardPage> createState() => _RahbarDashboardPageState();
}

class _RahbarDashboardPageState extends State<RahbarDashboardPage> {
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  int? _selectedFilialId;
  List<Map<String, dynamic>> _branches = [];
  List<RahbarStaffAttendanceEntity> _kundalikStaffList = [];
  Map<String, int> _staffNameToBranchId = {};
  final _fmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    final bloc = context.read<RahbarBloc>();
    if (bloc.state is! RahbarDashboardLoaded && bloc.state is! RahbarLoading) {
      _loadDashboard();
    } else {
      _fetchBranchesAndKundalik();
    }
  }

  void _loadDashboard() {
    context.read<RahbarBloc>().add(
      LoadRahbarDashboard(date: _fmt.format(_selectedDate)),
    );
    _fetchBranchesAndKundalik();
  }

  Future<void> _fetchBranchesAndKundalik() async {
    try {
      final dateStr = _fmt.format(_selectedDate);
      final remoteDs = sl<RahbarRemoteDataSource>();
      final results = await Future.wait([
        remoteDs.getLocations(),
        remoteDs.getKundalik(date: dateStr),
        remoteDs.getFilial(sana: dateStr),
      ]);
      final locations = results[0] as List<Map<String, dynamic>>;
      final kundalik = results[1] as List<RahbarStaffAttendanceEntity>;
      final filialReport = results[2] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _kundalikStaffList = kundalik;

          final List<Map<String, dynamic>> parsedBranches = [];
          final Set<int> addedIds = {};

          for (final loc in locations) {
            final id =
                (loc['id'] as num?)?.toInt() ?? (parsedBranches.length + 1);
            if (!addedIds.contains(id)) {
              addedIds.add(id);
              parsedBranches.add({
                'id': id,
                'name': (loc['name'] ?? loc['nom'] ?? loc['title'] ?? 'Filial')
                    .toString(),
                'lat':
                    (loc['lat'] ?? loc['latitude'] as num?)?.toDouble() ?? 0.0,
                'lng':
                    (loc['lng'] ?? loc['longitude'] as num?)?.toDouble() ?? 0.0,
                'radius':
                    (loc['radius_meter'] ??
                            loc['radius'] ??
                            loc['radius_m'] as num?)
                        ?.toDouble() ??
                    100.0,
              });
            }
          }

          // Build staff name -> branch ID mapping from Filial Report (getFilial)
          final rawFiliallar = (filialReport['filiallar'] as List?) ?? const [];
          final Map<String, int> staffNameToBranch = {};
          List<dynamic> unassignedStaffList = [];

          for (final f in rawFiliallar) {
            final fMap = Map<String, dynamic>.from(f as Map);
            final fNom = (fMap['nom'] ?? fMap['name'] ?? '').toString().trim();
            final fStaff = (fMap['xodimlar'] as List?) ?? const [];

            final isUnassigned =
                fNom.isEmpty ||
                fNom.toLowerCase().contains('biriktirilmagan') ||
                fNom.toLowerCase().contains('unassigned');

            if (isUnassigned) {
              unassignedStaffList = fStaff;
            } else {
              int targetBranchId = parsedBranches.isNotEmpty
                  ? (parsedBranches.first['id'] as int)
                  : 1;
              for (final b in parsedBranches) {
                final bName = (b['name'] as String).toLowerCase();
                final nomLower = fNom.toLowerCase();
                if (bName == nomLower ||
                    bName.contains(nomLower) ||
                    nomLower.contains(bName)) {
                  targetBranchId = b['id'] as int;
                  break;
                }
              }

              for (final st in fStaff) {
                final stMap = Map<String, dynamic>.from(st as Map);
                final stName = (stMap['name'] ?? stMap['xodim'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                if (stName.isNotEmpty) {
                  staffNameToBranch[stName] = targetBranchId;
                }
              }
            }
          }

          // Merge unassigned staff into primary branch (IT PROGRESS 1)
          if (parsedBranches.isNotEmpty) {
            final primaryBranchId = parsedBranches.first['id'] as int;
            for (final st in unassignedStaffList) {
              final stMap = Map<String, dynamic>.from(st as Map);
              final stName = (stMap['name'] ?? stMap['xodim'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              if (stName.isNotEmpty) {
                staffNameToBranch[stName] = primaryBranchId;
              }
            }
          }

          _staffNameToBranchId = staffNameToBranch;
          parsedBranches.sort(
            (a, b) =>
                ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0),
          );
          _branches = parsedBranches;
          if (_branches.isNotEmpty &&
              (_selectedFilialId == null ||
                  !_branches.any((b) => b['id'] == _selectedFilialId))) {
            _selectedFilialId = _branches.first['id'] as int;
          }
        });
      }
    } catch (_) {}
  }

  bool _isStaffInBranch(RahbarStaffAttendanceEntity s, int branchId) {
    if (_branches.isEmpty) return true;
    final int staffBranchId = _getStaffBranchId(s);
    return staffBranchId == branchId;
  }

  int _getStaffBranchId(RahbarStaffAttendanceEntity s) {
    if (_branches.isEmpty) return 0;
    if (_branches.length == 1) {
      return (_branches.first['id'] as num?)?.toInt() ?? 0;
    }

    // 0. Direct match from Filial Report (getFilial)
    final staffNameLower = s.name.trim().toLowerCase();
    if (_staffNameToBranchId.containsKey(staffNameLower)) {
      return _staffNameToBranchId[staffNameLower]!;
    }
    for (final entry in _staffNameToBranchId.entries) {
      if (staffNameLower.contains(entry.key) ||
          entry.key.contains(staffNameLower)) {
        return entry.value;
      }
    }

    // 1. Match by explicit filialId
    if (s.filialId != null && s.filialId! > 0) {
      for (final b in _branches) {
        if ((b['id'] as num?)?.toInt() == s.filialId) {
          return s.filialId!;
        }
      }
    }

    // 2. Match by explicit filialName
    if (s.filialName != null && s.filialName!.trim().isNotEmpty) {
      final sName = s.filialName!.trim().toLowerCase();
      for (final b in _branches) {
        final bName = (b['name'] ?? '').toString().trim().toLowerCase();
        if (bName.isNotEmpty &&
            (sName == bName ||
                sName.contains(bName) ||
                bName.contains(sName))) {
          return (b['id'] as num?)?.toInt() ?? 0;
        }
      }
    }

    // 3. Match if branch name contains staff name (e.g. personal assigned zone)
    if (staffNameLower.isNotEmpty) {
      for (final b in _branches) {
        final bName = (b['name'] ?? '').toString().trim().toLowerCase();
        final nameParts = staffNameLower.split(' ');
        for (final part in nameParts) {
          if (part.length >= 4 && bName.contains(part)) {
            return (b['id'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }

    // 4. Default to first branch
    return (_branches.first['id'] as num?)?.toInt() ?? 0;
  }

  bool _hasCheckIn(RahbarStaffAttendanceEntity item) =>
      item.checkIn != null &&
      item.checkIn!.isNotEmpty &&
      item.checkIn != '--:--' &&
      item.checkIn != '-';

  bool _hasCheckOut(RahbarStaffAttendanceEntity item) =>
      item.checkOut != null &&
      item.checkOut!.isNotEmpty &&
      item.checkOut != '--:--' &&
      item.checkOut != '-';

  bool _isLate(RahbarStaffAttendanceEntity item) {
    final statusLower = item.status.toLowerCase();
    final hasDelay =
        item.delay != null &&
        item.delay!.isNotEmpty &&
        item.delay != '0' &&
        item.delay != '00:00' &&
        item.delay != '--' &&
        item.delay != '0 daq';
    return statusLower.contains('kechik') || hasDelay;
  }

  bool _isAbsent(RahbarStaffAttendanceEntity item) {
    final statusLower = item.status.toLowerCase();
    final hasIn = _hasCheckIn(item);
    return statusLower.contains('kelmagan') ||
        (!hasIn && !statusLower.contains('kelgan') && !_isLate(item));
  }

  bool _isPresent(RahbarStaffAttendanceEntity item) {
    final statusLower = item.status.toLowerCase();
    final hasIn = _hasCheckIn(item);
    return (hasIn || statusLower.contains('kelgan') || _isLate(item)) &&
        !_isAbsent(item);
  }

  bool _isCurrentlyAtWork(RahbarStaffAttendanceEntity item) {
    return _hasCheckIn(item) && !_hasCheckOut(item);
  }

  void _openKundalikWithFilter(KundalikFilter filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<RahbarBloc>(),
          child: RahbarKundalikPage(
            initialFilter: filter,
            initialDate: _selectedDate,
            initialFilialId: _selectedFilialId,
          ),
        ),
      ),
    );
  }

  void _openArizalar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<RahbarBloc>()..add(LoadRahbarArizalar()),
          child: const RahbarArizalarPage(),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0D6E6E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      _loadDashboard();
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('rahbar_logout_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          context.tr('rahbar_logout_confirm'),
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('no'),
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = sl<SharedPreferences>();
              await prefs.clear();
              await FcmService.syncUserRole();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              context.tr('rahbar_logout_yes'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout_rounded, color: AppColors.error),
          tooltip: context.tr('rahbar_logout_tooltip'),
        ),
        title: Text(
          context.tr('rahbar_dashboard_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => LanguagePickerBottomSheet.show(context),
            icon: const Icon(
              Icons.language_rounded,
              color: Color(0xFF0D6E6E),
            ),
            tooltip: context.tr('app_language'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDashboard(),
        color: const Color(0xFF0D6E6E),
        child: BlocBuilder<RahbarBloc, RahbarState>(
          buildWhen: (prev, curr) =>
              curr is RahbarLoading ||
              curr is RahbarDashboardLoaded ||
              curr is RahbarError,
          builder: (context, state) {
            if (state is RahbarLoading) {
              return const RahbarDashboardShimmerWidget();
            } else if (state is RahbarDashboardLoaded) {
              final db = state.dashboard;
              final user = db.user;
              final malumot = db.malumot;

              int totalStaff = db.totalStaff;
              int presentCount = db.presentCount;
              int lateCount = db.lateCount;
              int absentCount = db.absentCount;
              int hozirIshda = db.hozirIchkarida > 0
                  ? db.hozirIchkarida
                  : db.presentCount;
              double foiz = db.foiz;

              if (_selectedFilialId != null && _kundalikStaffList.isNotEmpty) {
                final branchStaff = _kundalikStaffList
                    .where((s) => _isStaffInBranch(s, _selectedFilialId!))
                    .toList();
                totalStaff = branchStaff.length;
                presentCount = branchStaff.where(_isPresent).length;
                lateCount = branchStaff.where(_isLate).length;
                absentCount = branchStaff.where(_isAbsent).length;
                hozirIshda = branchStaff.where(_isCurrentlyAtWork).length;
                foiz = totalStaff > 0 ? (presentCount / totalStaff * 100) : 0.0;
              }

              // Compute filtered late list for selected filial
              final List<Map<String, dynamic>> filteredKechikkanlar = [];
              if (_selectedFilialId != null && _kundalikStaffList.isNotEmpty) {
                final lateFromKundalik = _kundalikStaffList
                    .where(
                      (s) =>
                          _isStaffInBranch(s, _selectedFilialId!) && _isLate(s),
                    )
                    .toList();

                for (final st in lateFromKundalik) {
                  Map<String, dynamic>? rawMatch;
                  for (final k in db.kechikkanlar) {
                    final kName = (k['name'] ?? k['xodim'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final sName = st.name.trim().toLowerCase();
                    if (kName.isNotEmpty &&
                        (kName == sName ||
                            kName.contains(sName) ||
                            sName.contains(kName))) {
                      rawMatch = k;
                      break;
                    }
                  }
                  filteredKechikkanlar.add(
                    rawMatch ??
                        <String, dynamic>{
                          'name': st.name,
                          'bolim': st.bolim,
                          'kechikish_daqiqa':
                              st.delay?.replaceAll(RegExp(r'[^0-9]'), '') ??
                              '0',
                          'photo': st.photo,
                        },
                  );
                }
              } else {
                filteredKechikkanlar.addAll(db.kechikkanlar);
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. User profile card (if available) - PDF §1.4
                    if (user != null) ...[
                      _buildUserProfileCard(user),
                      const SizedBox(height: 14),
                    ],

                    // 2. Date picker bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            final now = DateTime.now();
                            final isToday =
                                _selectedDate.year == now.year &&
                                _selectedDate.month == now.month &&
                                _selectedDate.day == now.day;
                            return Text(
                              isToday
                                  ? context.tr('rahbar_today_stats')
                                  : context.tr('rahbar_date_stats', {
                                      'date': _displayFmt.format(_selectedDate),
                                    }),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            );
                          },
                        ),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0D6E6E,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF0D6E6E,
                                ).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 16,
                                  color: Color(0xFF0D6E6E),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _displayFmt.format(_selectedDate),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D6E6E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2.5 Branch filter chips (if branches exist)
                    if (_branches.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _branches.map((b) {
                            final id = b['id'] as int;
                            final name = b['name'] as String;
                            final count = _kundalikStaffList
                                .where((s) => _isStaffInBranch(s, id))
                                .length;
                            final bool isFirst = _branches.indexOf(b) == 0;
                            return Padding(
                              padding: EdgeInsets.only(left: isFirst ? 0 : 8),
                              child: _buildBranchChip(
                                id: id,
                                title: '📍 $name',
                                count: count,
                                isSelected: _selectedFilialId == id,
                                onTap: () =>
                                    setState(() => _selectedFilialId = id),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Data notice if no record on date (PDF §1.2 malumot.bor)
                    if (malumot != null && malumot['bor'] == false) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                malumot['izoh']?.toString() ??
                                    (malumot['oxirgi_sana'] != null
                                        ? context.tr(
                                            'rahbar_no_data_notice_with_last',
                                            {
                                              'date':
                                                  '${malumot['oxirgi_sana']}',
                                            },
                                          )
                                        : context.tr('rahbar_no_data_notice')),
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 3. Grid of KPIs (Kelgan, Kechikkan, Kelmagan, Hozir ishda) - Clickable
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildKpiCard(
                          context.tr('attendance_present'),
                          '$presentCount/$totalStaff',
                          Icons.check_circle_rounded,
                          Colors.green,
                          subtitle: foiz > 0
                              ? '${foiz.toStringAsFixed(1)}%'
                              : null,
                          onTap: () =>
                              _openKundalikWithFilter(KundalikFilter.kelgan),
                        ),
                        _buildKpiCard(
                          context.tr('rahbar_kpi_late'),
                          '$lateCount',
                          Icons.access_time_filled_rounded,
                          Colors.orange,
                          onTap: () =>
                              _openKundalikWithFilter(KundalikFilter.kechikkan),
                        ),
                        _buildKpiCard(
                          context.tr('attendance_absent'),
                          '$absentCount',
                          Icons.cancel_rounded,
                          Colors.red,
                          onTap: () =>
                              _openKundalikWithFilter(KundalikFilter.kelmagan),
                        ),
                        _buildKpiCard(
                          context.tr('home_currently_working'),
                          '$hozirIshda',
                          Icons.business_center_rounded,
                          const Color(0xFF0D6E6E),
                          onTap: () => _openKundalikWithFilter(
                            KundalikFilter.hozirIshda,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Leave & Applications Banner (Yangi arizalar) - Clickable
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openArizalar,
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedRotatingBorderContainer(
                          margin: EdgeInsets.zero,
                          borderRadius: 16,
                          borderWidth: 2.0,
                          gradientColors: const [
                            Color(0xFF0D6E6E),
                            Color(0xFF139797),
                            Color(0xFF26BBAA),
                            Color(0xFF0D6E6E),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0D6E6E,
                                    ).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_ind_rounded,
                                    color: Color(0xFF0D6E6E),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr(
                                          'rahbar_review_applications',
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr(
                                          'rahbar_pending_ariza_count',
                                          {
                                            'count':
                                                '${db.unreviewedArizalarCount}',
                                          },
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF0D6E6E),
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Yangi arizalar list (if present in /bosh) - PDF §1.4
                    if (db.yangilarArizalar.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('rahbar_new_arizalar'),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _openArizalar,
                            child: Text(
                              context.tr('rahbar_view_all_count', {
                                'count': '${db.unreviewedArizalarCount}',
                              }),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D6E6E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...db.yangilarArizalar.map((ar) {
                        final name =
                            ar['xodim']?.toString() ??
                            ar['xodim_name']?.toString() ??
                            context.tr('rahbar_staff_fallback');
                        final turi =
                            ar['turi_nomi']?.toString() ??
                            context.tr('rahbar_ariza_fallback');
                        final kunlar = (ar['kunlar'] as num?)?.toInt() ?? 1;
                        final dateStr = ar['from_date']?.toString() ?? '';
                        final photoUrl = ar['photo']?.toString();

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openArizalar,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: _buildAvatar(photoUrl, name),
                                title: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  context.tr('rahbar_ariza_summary', {
                                    'turi': turi,
                                    'days': '$kunlar',
                                  }),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                trailing: Text(
                                  dateStr,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: const Color(0xFF0D6E6E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // 6. Kechikkanlar section (filial bo'yicha filtrlangan)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('rahbar_late_section_title'),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (filteredKechikkanlar.isNotEmpty)
                          GestureDetector(
                            onTap: () => _openKundalikWithFilter(
                              KundalikFilter.kechikkan,
                            ),
                            child: Text(
                              context.tr('rahbar_view_all_count', {
                                'count': '${filteredKechikkanlar.length}',
                              }),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (filteredKechikkanlar.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF16A34A,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.tr('rahbar_no_late_in_branch'),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ...filteredKechikkanlar.map((k) {
                        final name =
                            k['name']?.toString() ??
                            k['xodim']?.toString() ??
                            context.tr('rahbar_staff_fallback');
                        final bolim = k['bolim']?.toString() ?? '';
                        final daq = k['kechikish_daqiqa'] ?? k['daqiqa'] ?? 0;
                        final photoUrl = k['photo']?.toString();

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openKundalikWithFilter(
                              KundalikFilter.kechikkan,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: _buildAvatar(photoUrl, name),
                                title: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: bolim.isNotEmpty
                                    ? Text(
                                        bolim,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      )
                                    : null,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    context.tr('rahbar_delay_minutes', {
                                      'minutes': '$daq',
                                    }),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // 7. Departments Section - PDF §1.4
                    if (db.bolimlar.isNotEmpty) ...[
                      Text(
                        context.tr('rahbar_departments_attendance'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...db.bolimlar.map((b) {
                        final nom =
                            b['nom']?.toString() ??
                            b['name']?.toString() ??
                            context.tr('rahbar_department_fallback');
                        final kelgan = (b['kelgan'] as num?)?.toInt() ?? 0;
                        final jami = (b['jami'] as num?)?.toInt() ?? 1;
                        final double percent = (kelgan / (jami > 0 ? jami : 1))
                            .clamp(0.0, 1.0);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    nom,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '$kelgan / $jami',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: const Color(0xFF0D6E6E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0D6E6E),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            } else if (state is RahbarError) {
              return RahbarEmptyStateWidget(
                icon: Icons.cloud_off_rounded,
                title: context.tr('rahbar_load_failed'),
                subtitle: state.message,
                onRefresh: _loadDashboard,
              );
            }
            // For RahbarLoading, RahbarInitial, RahbarAuthSuccess or any other transient state
            return const RahbarDashboardShimmerWidget();
          },
        ),
      ),
    );
  }

  Widget _buildBranchChip({
    required int? id,
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D6E6E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D6E6E)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF0D6E6E).withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Safe Avatar Builder with fallback for broken network images (§2.5)
  Widget _buildAvatar(String? photoUrl, String name, {double radius = 20}) {
    final bool validUrl =
        photoUrl != null &&
        photoUrl.isNotEmpty &&
        !photoUrl.contains('localhost') &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));

    Widget fallbackAvatar() => CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF0D6E6E).withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0D6E6E),
          fontSize: radius * 0.7,
        ),
      ),
    );

    if (!validUrl) return fallbackAvatar();

    return CachedNetworkImage(
      imageUrl: photoUrl,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(radius: radius, backgroundImage: imageProvider),
      placeholder: (context, url) => fallbackAvatar(),
      errorWidget: (context, url, error) => fallbackAvatar(),
    );
  }

  Widget _buildUserProfileCard(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? context.tr('user');
    final tashkilot = user['tashkilot'] is Map
        ? (user['tashkilot']['name']?.toString() ?? '')
        : '';
    final photo = user['photo']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAvatar(photo, name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (tashkilot.isNotEmpty)
                  Text(
                    tashkilot,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
