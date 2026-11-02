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
import 'package:skore_hodimlar/core/security/app_lock_service.dart';
import 'package:skore_hodimlar/core/security/security_settings_page.dart';
import 'package:skore_hodimlar/core/services/fcm_service.dart';
import 'package:skore_hodimlar/core/theme/theme_cubit.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/core/utils/day_change_watcher.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/core/widgets/language_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/core/widgets/pull_to_refresh.dart';
import 'package:skore_hodimlar/core/widgets/shimmer_loading_widget.dart';
import 'package:skore_hodimlar/core/widgets/theme_picker_bottom_sheet.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/data/unassigned_branch.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_arizalar_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_kundalik_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/rahbar_map_focus.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';
import 'package:skore_hodimlar/features/tasks/presentation/widgets/rahbar_tasks_entry_card.dart';

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
  Map<int, int> _staffIdToBranchId = {};
  List<Map<String, dynamic>> _rawFiliallar = [];
  final _fmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('dd.MM.yyyy');

  /// 00:00 da (yoki ilova ertalab orqa fondan qaytganda) "bugun" ko'rib
  /// turilgan bo'lsa — yangi kunga o'tiladi. Kalendardan tanlangan boshqa
  /// sana o'zgarmaydi.
  late final DayChangeWatcher _dayWatcher = DayChangeWatcher(
    onNewDay: (today) {
      if (!mounted) return;
      final yesterday = DateUtils.addDaysToDate(today, -1);
      if (!DateUtils.isSameDay(_selectedDate, yesterday)) return;
      setState(() => _selectedDate = today);
      _loadDashboard();
    },
  );

  @override
  void initState() {
    super.initState();
    _dayWatcher;
    rahbarOpenRequest.addListener(_onOpenRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpenRequest());
    final bloc = context.read<RahbarBloc>();
    if (bloc.state is! RahbarDashboardLoaded && bloc.state is! RahbarLoading) {
      _loadDashboard();
    } else {
      _fetchBranchesAndKundalik();
    }
  }

  @override
  void dispose() {
    rahbarOpenRequest.removeListener(_onOpenRequest);
    _dayWatcher.dispose();
    super.dispose();
  }

  void _loadDashboard() {
    context.read<RahbarBloc>().add(
      LoadRahbarDashboard(date: _fmt.format(_selectedDate)),
    );
    _fetchBranchesAndKundalik();
  }

  int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final clean = val.trim();
      return int.tryParse(clean) ?? fallback;
    }
    return fallback;
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
            final rawNom = (loc['name'] ?? loc['nom'] ?? loc['title'] ?? '')
                .toString()
                .trim();
            final isUn =
                rawNom.isEmpty ||
                rawNom.toLowerCase().contains('biriktirilmagan') ||
                rawNom.toLowerCase().contains('unassigned') ||
                rawNom.toLowerCase() == 'null';

            final id = isUn
                ? 0
                : (_parseInt(loc['id']) > 0
                      // Large offset so this synthetic id can never collide
                      // with a real backend branch id (small sequential DB ids).
                      ? _parseInt(loc['id'])
                      : (1000000 + parsedBranches.length));

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
          _rawFiliallar = rawFiliallar
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final Map<String, int> staffNameToBranch = {};
          final Map<int, int> staffIdToBranch = {};

          for (final f in rawFiliallar) {
            final fMap = Map<String, dynamic>.from(f as Map);
            final fNom = (fMap['nom'] ?? fMap['name'] ?? '').toString().trim();
            final fStaff = (fMap['xodimlar'] as List?) ?? const [];

            // Backend guarantees `is_unassigned: true` on the "unassigned
            // staff" pseudo-branch — confirmed authoritative.
            final isUnassigned = fMap['is_unassigned'] == true;

            if (isUnassigned) {
              for (final st in fStaff) {
                final stMap = Map<String, dynamic>.from(st as Map);
                final stName = (stMap['name'] ?? stMap['xodim'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                if (stName.isNotEmpty) {
                  staffNameToBranch[stName] = 0;
                }
                final stId = _parseInt(stMap['id']);
                if (stId > 0) {
                  staffIdToBranch[stId] = 0;
                }
              }
            } else {
              int? targetBranchId;
              // 1. Match by branch name first!
              if (fNom.isNotEmpty) {
                final nomLower = fNom.toLowerCase();
                for (final b in parsedBranches) {
                  final bName = (b['name'] as String).toLowerCase();
                  if (bName == nomLower) {
                    targetBranchId = b['id'] as int;
                    break;
                  }
                }
                if (targetBranchId == null) {
                  for (final b in parsedBranches) {
                    final bName = (b['name'] as String).toLowerCase();
                    if (bName.contains(nomLower) || nomLower.contains(bName)) {
                      targetBranchId = b['id'] as int;
                      break;
                    }
                  }
                }
              }
              // 2. Fallback to fId only if name matching did not find branch
              if (targetBranchId == null) {
                final fId = _parseInt(
                  fMap['id'] ?? fMap['filial_id'] ?? fMap['location_id'],
                );
                if (fId > 0) {
                  for (final b in parsedBranches) {
                    if ((b['id'] as int) == fId) {
                      targetBranchId = b['id'] as int;
                      break;
                    }
                  }
                }
              }

              if (targetBranchId != null) {
                for (final st in fStaff) {
                  final stMap = Map<String, dynamic>.from(st as Map);
                  final stName = (stMap['name'] ?? stMap['xodim'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();
                  if (stName.isNotEmpty) {
                    staffNameToBranch[stName] = targetBranchId;
                  }
                  final stId = _parseInt(stMap['id']);
                  if (stId > 0) {
                    staffIdToBranch[stId] = targetBranchId;
                  }
                }
              }
            }
          }

          // Agar rawFiliallar ichida biriktirilmagan xodimlar bo'lsa va parsedBranches da id==0 bo'lmasa, qo'shamiz
          // Filialsiz guruh nomi serverdan (`nom`) olinadi.
          final serverUnassignedName = unassignedBranchName(rawFiliallar);
          for (final b in parsedBranches) {
            if (b['id'] == 0 && serverUnassignedName != null) {
              b['name'] = serverUnassignedName;
            }
          }
          if (!parsedBranches.any((b) => (b['id'] as int) == 0)) {
            final hasUnassignedStaff = rawFiliallar.any((f) {
              final fMap = Map<String, dynamic>.from(f as Map);
              final fStaff = (fMap['xodimlar'] as List?) ?? const [];
              return fMap['is_unassigned'] == true && fStaff.isNotEmpty;
            });
            if (hasUnassignedStaff) {
              parsedBranches.add({
                'id': 0,
                'name':
                    serverUnassignedName ??
                    context.tr('rahbar_unassigned_branch'),
                'lat': 0.0,
                'lng': 0.0,
                'radius': 0.0,
              });
            }
          }

          _staffNameToBranchId = staffNameToBranch;
          _staffIdToBranchId = staffIdToBranch;
          // Real filiallar (id > 0) oldinda, biriktirilmagan (id == 0) esa oxirida bo'lsin
          parsedBranches.sort((a, b) {
            final aId = (a['id'] as int?) ?? 0;
            final bId = (b['id'] as int?) ?? 0;
            if (aId == 0) return 1;
            if (bId == 0) return -1;
            return aId.compareTo(bId);
          });
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

  bool _isSameStaff(String name1, String name2) {
    final n1 = name1.trim().toLowerCase();
    final n2 = name2.trim().toLowerCase();
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1 == n2) return true;

    final words1 = n1
        .split(RegExp(r"[\s\-_',.]+"))
        .where((w) => w.length >= 2)
        .toList();
    final words2 = n2
        .split(RegExp(r"[\s\-_',.]+"))
        .where((w) => w.length >= 2)
        .toList();
    if (words1.isEmpty || words2.isEmpty) return false;

    final set1 = words1.toSet();
    final set2 = words2.toSet();

    if (set1.length == set2.length && set1.containsAll(set2)) return true;

    final common = set1.intersection(set2).where((w) => w.length >= 3).toList();
    if (common.length >= 2) return true;

    if (set1.length == 1 && set2.length == 1 && set1.first == set2.first) {
      return true;
    }

    return false;
  }

  bool _isStaffInBranch(RahbarStaffAttendanceEntity s, int branchId) {
    if (_branches.isEmpty) return true;
    final int staffBranchId = _getStaffBranchId(s);
    return staffBranchId == branchId;
  }

  int _getStaffBranchId(RahbarStaffAttendanceEntity s) {
    if (_branches.isEmpty) return 0;

    // 0. Direct ID match from Filial Report (getFilial)
    if (_staffIdToBranchId.containsKey(s.id)) {
      final bId = _staffIdToBranchId[s.id]!;
      return bId;
    }

    // 1. Direct Name match from Filial Report (getFilial)
    final staffNameLower = s.name.trim().toLowerCase();
    if (_staffNameToBranchId.containsKey(staffNameLower)) {
      return _staffNameToBranchId[staffNameLower]!;
    }
    for (final entry in _staffNameToBranchId.entries) {
      if (_isSameStaff(staffNameLower, entry.key)) {
        return entry.value;
      }
    }

    // 2. Match by explicit filialName
    if (s.filialName != null && s.filialName!.trim().isNotEmpty) {
      final sName = s.filialName!.trim().toLowerCase();
      if (sName.contains('biriktirilmagan') ||
          sName.contains('unassigned') ||
          sName == 'null') {
        return 0;
      }
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

    // 3. Match by explicit filialId
    if (s.filialId != null && s.filialId! > 0) {
      for (final b in _branches) {
        if ((b['id'] as num?)?.toInt() == s.filialId) {
          return s.filialId!;
        }
      }
    }

    // 4. Default: return 0 (unassigned). NEVER default to first branch!
    return 0;
  }

  void _logBranchInfo(
    Map<String, dynamic> b,
    List<RahbarStaffAttendanceEntity> allList,
  ) {
    final id = b['id'] as int;
    final name = (b['name'] ?? 'Filial').toString();
    final staffInBranch = allList
        .where((s) => _isStaffInBranch(s, id))
        .toList();

    final bool isUnassigned = id == 0;
    debugPrint(
      '════════════════════════════════════════════════════════════════',
    );
    debugPrint('🏢 [DASHBOARD - FILIAL BOSILDI]: $name (ID: $id)');
    if (!isUnassigned) {
      debugPrint(
        '📍 Koordinatalar: lat=${b['lat']}, lng=${b['lng']}, radius=${b['radius']}m',
      );
    } else {
      debugPrint('📍 Filial biriktirilmagan xodimlar ro\'yxati');
    }
    debugPrint('👥 Biriktirilgan xodimlar soni: ${staffInBranch.length} nafar');
    debugPrint(
      '────────────────────────────────────────────────────────────────',
    );
    for (int i = 0; i < staffInBranch.length; i++) {
      final s = staffInBranch[i];
      debugPrint(
        ' #${i + 1} ${s.name} (ID: ${s.id}) | Bo\'lim: ${s.bolim} | Lavozim: ${s.lavozim}\n'
        '     Kelish: ${s.checkIn ?? "--"} | Ketish: ${s.checkOut ?? "--"} | Status: ${s.status} | Filial: ${s.filialName ?? "--"} (ID: ${s.filialId})\n'
        '     GPS: lat=${s.lat}, lng=${s.lng}',
      );
    }
    for (final f in _rawFiliallar) {
      final fNom = (f['nom'] ?? f['name'] ?? '').toString().toLowerCase();
      final fId = _parseInt(f['id'] ?? f['filial_id'] ?? f['location_id']);
      final bool matches =
          (id == 0 &&
              (fNom.contains('biriktirilmagan') ||
                  fNom.contains('unassigned') ||
                  fId == 0)) ||
          (id > 0 &&
              (fId == id ||
                  fNom == name.toLowerCase() ||
                  (fNom.isNotEmpty && name.toLowerCase() == fNom)));
      if (matches) {
        debugPrint('📦 [BACKEND RAW DATA]: $f');
      }
    }
    debugPrint(
      '════════════════════════════════════════════════════════════════',
    );
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
    return BackendTextMapper.isLateStatus(item.status) ||
        BackendTextMapper.isLate(item.delay);
  }

  bool _isAbsent(RahbarStaffAttendanceEntity item) {
    final hasIn = _hasCheckIn(item);
    return BackendTextMapper.isAbsentStatus(item.status) ||
        (!hasIn &&
            !BackendTextMapper.isPresentStatus(item.status) &&
            !_isLate(item));
  }

  bool _isPresent(RahbarStaffAttendanceEntity item) {
    final hasIn = _hasCheckIn(item);
    return (hasIn ||
            BackendTextMapper.isPresentStatus(item.status) ||
            _isLate(item)) &&
        !_isAbsent(item);
  }

  bool _isCurrentlyAtWork(RahbarStaffAttendanceEntity item) {
    return _hasCheckIn(item) && !_hasCheckOut(item);
  }

  /// Bildirishnoma bosilganda (ilova yopiq bo'lsa — sahifa ochilgach).
  void _onOpenRequest() {
    final request = rahbarOpenRequest.value;
    if (request == null || !mounted) return;
    rahbarOpenRequest.value = null;
    switch (request.target) {
      case RahbarOpenTarget.arizalar:
        _openArizalar();
      case RahbarOpenTarget.kelmaganlar:
        _openKundalikWithFilter(
          KundalikFilter.kelmagan,
          date: request.day,
          filialId: request.filialId,
        );
    }
  }

  void _openKundalikWithFilter(
    KundalikFilter filter, {
    DateTime? date,
    int? filialId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<RahbarBloc>(),
          child: RahbarKundalikPage(
            initialFilter: filter,
            initialDate: date ?? _selectedDate,
            initialFilialId: filialId ?? _selectedFilialId,
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
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          context.tr('rahbar_logout_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: context.colors.textPrimary,
          ),
        ),
        content: Text(
          context.tr('rahbar_logout_confirm'),
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('no'),
              style: GoogleFonts.outfit(color: context.colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = sl<SharedPreferences>();
              await FcmService.deleteRahbarTokenFromBackend();
              await FcmService.clearPrefsKeepingDeviceId(prefs);
              await FcmService.syncUserRole();
              await AppLockService.instance.clear();
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => _confirmLogout(context),
          icon: Icon(Icons.logout_rounded, color: context.colors.error),
          tooltip: context.tr('rahbar_logout_tooltip'),
        ),
        title: Text(
          context.tr('rahbar_dashboard_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => SecuritySettingsPage.open(context),
            icon: Icon(
              Icons.lock_outline_rounded,
              color: context.colors.primary,
            ),
            tooltip: context.tr('security_title'),
          ),
          IconButton(
            onPressed: () => LanguagePickerBottomSheet.show(context),
            icon: Icon(Icons.language_rounded, color: context.colors.primary),
            tooltip: context.tr('app_language'),
          ),
          IconButton(
            onPressed: () => ThemePickerBottomSheet.show(context),
            icon: Icon(
              ThemePickerBottomSheet.iconFor(context.watch<ThemeCubit>().state),
              color: context.colors.primary,
            ),
            tooltip: context.tr('app_theme'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshWithMinDelay(_loadDashboard),
        color: context.colors.primary,
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
                                color: context.colors.textPrimary,
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
                              color: context.colors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.colors.primary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 16,
                                  color: context.colors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _displayFmt.format(_selectedDate),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.primary,
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
                            final bool isUnassigned = id == 0;
                            final String chipTitle = isUnassigned
                                ? name
                                : '📍 $name';
                            return Padding(
                              padding: EdgeInsets.only(left: isFirst ? 0 : 8),
                              child: _buildBranchChip(
                                id: id,
                                title: chipTitle,
                                count: count,
                                isSelected: _selectedFilialId == id,
                                onTap: () {
                                  setState(() => _selectedFilialId = id);
                                  _logBranchInfo(b, _kundalikStaffList);
                                },
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
                          border: Border.all(color: context.colors.warning),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: context.colors.warning,
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
                                  color: context.colors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 3. Grid of KPIs (Kelgan, Kechikkan, Kelmagan, Hozir ishda) - Clickable
                    // Using IntrinsicHeight Rows instead of GridView to avoid shrinkWrap padding quirks
                    // and ensure consistent UI/UX spacing across all devices.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              context.tr('attendance_present'),
                              '$presentCount/$totalStaff',
                              Icons.check_circle_rounded,
                              Colors.green,
                              subtitle: foiz > 0
                                  ? '${foiz.toStringAsFixed(1)}%'
                                  : null,
                              onTap: () => _openKundalikWithFilter(
                                KundalikFilter.kelgan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              context.tr('rahbar_kpi_late'),
                              '$lateCount',
                              Icons.access_time_filled_rounded,
                              Colors.orange,
                              onTap: () => _openKundalikWithFilter(
                                KundalikFilter.kechikkan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              context.tr('attendance_absent'),
                              '$absentCount',
                              Icons.cancel_rounded,
                              Colors.red,
                              onTap: () => _openKundalikWithFilter(
                                KundalikFilter.kelmagan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              context.tr('home_currently_working'),
                              '$hozirIshda',
                              Icons.business_center_rounded,
                              context.colors.primary,
                              onTap: () => _openKundalikWithFilter(
                                KundalikFilter.hozirIshda,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Topshiriqlar (TOPSHIRIQLAR_TZ_BACKEND.md)
                    const RahbarTasksEntryCard(),
                    const SizedBox(height: 14),

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
                          gradientColors: [
                            context.colors.primary,
                            Color(0xFF139797),
                            Color(0xFF26BBAA),
                            context.colors.primary,
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
                                  child: Icon(
                                    Icons.assignment_ind_rounded,
                                    color: context.colors.primary,
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
                                          color: context.colors.textPrimary,
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
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.colors.primary,
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
                              color: context.colors.textPrimary,
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
                                color: context.colors.primary,
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
                                color: context.colors.surface,
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
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                trailing: Text(
                                  dateStr,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: context.colors.primary,
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
                            color: context.colors.textPrimary,
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
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.divider),
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
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: context.colors.success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.tr('rahbar_no_late_in_branch'),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textSecondary,
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
                                color: context.colors.surface,
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
                                          color: context.colors.textSecondary,
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
                          color: context.colors.textPrimary,
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
                            color: context.colors.surface,
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
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '$kelgan / $jami',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: context.colors.primary,
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
                                  backgroundColor: context.colors.surfaceStrong,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    context.colors.primary,
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
          color: isSelected ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? context.colors.primary.withValues(alpha: 0.25)
                  : context.colors.shadow,
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
                color: isSelected ? Colors.white : context.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : context.colors.surfaceStrong,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : context.colors.textPrimary,
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
      backgroundColor: context.colors.primary.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: context.colors.primary,
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
        color: context.colors.surface,
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
                    color: context.colors.textPrimary,
                  ),
                ),
                if (tashkilot.isNotEmpty)
                  Text(
                    tashkilot,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
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
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: context.colors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.colors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
