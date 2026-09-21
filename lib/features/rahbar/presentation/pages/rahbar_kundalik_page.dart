import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/backend_text_mapper.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_border_container.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/bloc/rahbar_bloc.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/widgets/rahbar_empty_state_widget.dart';

enum KundalikFilter { all, kelgan, kechikkan, kelmagan, hozirIshda }

class RahbarKundalikPage extends StatefulWidget {
  final KundalikFilter initialFilter;
  final DateTime? initialDate;
  final int? initialFilialId;

  const RahbarKundalikPage({
    super.key,
    this.initialFilter = KundalikFilter.all,
    this.initialDate,
    this.initialFilialId,
  });

  @override
  State<RahbarKundalikPage> createState() => _RahbarKundalikPageState();
}

class _RahbarKundalikPageState extends State<RahbarKundalikPage> {
  final TextEditingController _searchController = TextEditingController();
  late KundalikFilter _selectedFilter;
  late DateTime _selectedDate;
  int? _selectedFilialId;
  List<Map<String, dynamic>> _branches = [];
  Map<String, int> _staffNameToBranchId = {};
  final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFmt = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    final now = DateTime.now();
    _selectedDate =
        widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _selectedFilialId = widget.initialFilialId;
    _fetchData();
  }

  void _fetchData() {
    context.read<RahbarBloc>().add(
      LoadRahbarKundalik(date: _fmt.format(_selectedDate)),
    );
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final dateStr = _fmt.format(_selectedDate);
      final remoteDs = sl<RahbarRemoteDataSource>();
      final results = await Future.wait([
        remoteDs.getLocations(),
        remoteDs.getFilial(sana: dateStr),
      ]);
      final locations = results[0] as List<Map<String, dynamic>>;
      final filialReport = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          final List<Map<String, dynamic>> parsedBranches = [];
          for (final loc in locations) {
            final id =
                (loc['id'] as num?)?.toInt() ?? (parsedBranches.length + 1);
            parsedBranches.add({
              'id': id,
              'name': (loc['name'] ?? loc['nom'] ?? loc['title'] ?? 'Filial')
                  .toString(),
              'lat': (loc['lat'] ?? loc['latitude'] as num?)?.toDouble() ?? 0.0,
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

          // Build staff name -> branch ID mapping from Filial Report (getFilial)
          final rawFiliallar = (filialReport['filiallar'] as List?) ?? const [];
          final Map<String, int> staffNameToBranch = {};

          for (final f in rawFiliallar) {
            final fMap = Map<String, dynamic>.from(f as Map);
            final fNom = (fMap['nom'] ?? fMap['name'] ?? '').toString().trim();
            final fStaff = (fMap['xodimlar'] as List?) ?? const [];

            final isUnassigned =
                fNom.isEmpty ||
                fNom.toLowerCase().contains('biriktirilmagan') ||
                fNom.toLowerCase().contains('unassigned');

            if (!isUnassigned) {
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

  bool _isStaffInBranch(
    RahbarStaffAttendanceEntity s,
    int branchId,
    List<Map<String, dynamic>> allBranches,
  ) {
    if (allBranches.isEmpty) return true;
    final int staffBranchId = _getStaffBranchId(s, allBranches);
    return staffBranchId == branchId;
  }

  int _getStaffBranchId(
    RahbarStaffAttendanceEntity s,
    List<Map<String, dynamic>> allBranches,
  ) {
    if (allBranches.isEmpty) return 0;
    if (allBranches.length == 1) {
      return (allBranches.first['id'] as num?)?.toInt() ?? 0;
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

    // 1. Explicit filialId
    if (s.filialId != null && s.filialId! > 0) {
      for (final b in allBranches) {
        if ((b['id'] as num?)?.toInt() == s.filialId) {
          return s.filialId!;
        }
      }
    }

    // 2. Explicit filialName
    if (s.filialName != null && s.filialName!.trim().isNotEmpty) {
      final sName = s.filialName!.trim().toLowerCase();
      for (final b in allBranches) {
        final bName = (b['name'] ?? '').toString().trim().toLowerCase();
        if (bName.isNotEmpty &&
            (sName == bName ||
                sName.contains(bName) ||
                bName.contains(sName))) {
          return (b['id'] as num?)?.toInt() ?? 0;
        }
      }
    }

    // 3. Match by staff GPS coordinates (inside geofence or closest)
    if (s.lat != null && s.lng != null && s.lat != 0.0 && s.lng != 0.0) {
      double minDistance = double.infinity;
      int? closestBranchId;
      for (final b in allBranches) {
        final bLat = (b['lat'] as num?)?.toDouble() ?? 0.0;
        final bLng = (b['lng'] as num?)?.toDouble() ?? 0.0;
        final bRadius = (b['radius'] as num?)?.toDouble() ?? 100.0;
        if (bLat != 0.0 && bLng != 0.0) {
          final d = Geolocator.distanceBetween(s.lat!, s.lng!, bLat, bLng);
          if (d <= bRadius) {
            return (b['id'] as num?)?.toInt() ?? 0;
          }
          if (d < minDistance) {
            minDistance = d;
            closestBranchId = (b['id'] as num?)?.toInt();
          }
        }
      }
      if (closestBranchId != null) {
        return closestBranchId;
      }
    }

    // 4. Match if branch name contains staff name
    if (staffNameLower.isNotEmpty) {
      for (final b in allBranches) {
        final bName = (b['name'] ?? '').toString().trim().toLowerCase();
        final nameParts = staffNameLower.split(' ');
        for (final part in nameParts) {
          if (part.length >= 4 && bName.contains(part)) {
            return (b['id'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }

    // 5. Default to primary branch
    return (allBranches.first['id'] as num?)?.toInt() ?? 0;
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
      _fetchData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(String? rawTime) {
    if (rawTime == null ||
        rawTime.isEmpty ||
        rawTime == '--:--' ||
        rawTime == '-') {
      return '--:--';
    }
    final trimmed = rawTime.trim();
    // If string is "2026-08-25 08:45:12" or "2026-08-25T08:45:12"
    if (trimmed.contains('T') || trimmed.contains(' ')) {
      final parts = trimmed.split(RegExp(r'[ T]'));
      if (parts.length > 1) {
        final timeSub = parts[1].split(':');
        if (timeSub.length >= 2) {
          return '${timeSub[0].padLeft(2, '0')}:${timeSub[1].padLeft(2, '0')}';
        }
      }
    }
    final timeSub = trimmed.split(':');
    if (timeSub.length >= 2) {
      return '${timeSub[0].padLeft(2, '0')}:${timeSub[1].padLeft(2, '0')}';
    }
    return trimmed;
  }

  String _formatDelayText(String? delayStr) {
    if (delayStr == null ||
        delayStr.isEmpty ||
        !BackendTextMapper.isLate(delayStr)) {
      return '';
    }
    final clean = delayStr
        .replaceAll('+', '')
        .replaceAll('daq', '')
        .replaceAll('daqiqa', '')
        .replaceAll('min', '')
        .trim();
    final intVal = int.tryParse(clean);
    if (intVal != null) {
      if (intVal <= 0) return '';
      if (intVal >= 60) {
        final hours = intVal ~/ 60;
        final mins = intVal % 60;
        return mins > 0
            ? context.tr('rahbar_delay_hours_mins', {
                'hours': '$hours',
                'mins': '$mins',
              })
            : context.tr('rahbar_delay_hours', {'hours': '$hours'});
      }
      return context.tr('rahbar_delay_mins', {'mins': '$intVal'});
    }
    if (delayStr.contains(':')) {
      final parts = delayStr.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (h == 0 && m == 0) return '';
      if (h > 0) {
        return m > 0
            ? context.tr('rahbar_delay_hours_mins', {
                'hours': '$h',
                'mins': '$m',
              })
            : context.tr('rahbar_delay_hours', {'hours': '$h'});
      }
      return context.tr('rahbar_delay_mins', {'mins': '$m'});
    }
    return context.tr('rahbar_delay_raw', {
      'delay': delayStr.startsWith('+') ? delayStr : '+$delayStr',
    });
  }

  bool _hasCheckIn(RahbarStaffAttendanceEntity item) {
    return item.checkIn != null &&
        item.checkIn!.isNotEmpty &&
        item.checkIn != '--:--' &&
        item.checkIn != '-';
  }

  bool _hasCheckOut(RahbarStaffAttendanceEntity item) {
    return item.checkOut != null &&
        item.checkOut!.isNotEmpty &&
        item.checkOut != '--:--' &&
        item.checkOut != '-';
  }

  bool _isLate(RahbarStaffAttendanceEntity item) {
    return BackendTextMapper.isLateStatus(item.status) ||
        BackendTextMapper.isLate(item.delay);
  }

  bool _isAbsent(RahbarStaffAttendanceEntity item) {
    final hasIn = _hasCheckIn(item);
    return BackendTextMapper.isAbsentStatus(item.status) ||
        (!hasIn && !BackendTextMapper.isPresentStatus(item.status) && !_isLate(item));
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

  bool _matchesFilter(RahbarStaffAttendanceEntity item, KundalikFilter filter) {
    switch (filter) {
      case KundalikFilter.all:
        return true;
      case KundalikFilter.kelgan:
        return _isPresent(item);
      case KundalikFilter.kechikkan:
        return _isLate(item);
      case KundalikFilter.kelmagan:
        return _isAbsent(item);
      case KundalikFilter.hozirIshda:
        return _isCurrentlyAtWork(item);
    }
  }

  String _getFilterTitle(KundalikFilter filter) {
    switch (filter) {
      case KundalikFilter.all:
        return context.tr('notif_filter_all');
      case KundalikFilter.kelgan:
        return context.tr('rahbar_filter_kelganlar');
      case KundalikFilter.kechikkan:
        return context.tr('rahbar_late_section_title');
      case KundalikFilter.kelmagan:
        return context.tr('rahbar_filter_kelmaganlar');
      case KundalikFilter.hozirIshda:
        return context.tr('home_currently_working');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0D6E6E),
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          context.tr('rahbar_kundalik_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF0D6E6E),
              size: 26,
            ),
            tooltip: context.tr('rahbar_prev_day'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
              _fetchData();
            },
          ),
          // Date selection button
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D6E6E).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: Color(0xFF0D6E6E),
                  ),
                  const SizedBox(width: 4),
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
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF0D6E6E),
              size: 26,
            ),
            tooltip: context.tr('rahbar_next_day'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              _fetchData();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: BlocBuilder<RahbarBloc, RahbarState>(
        builder: (context, state) {
          List<RahbarStaffAttendanceEntity> allList = [];
          if (state is RahbarKundalikLoaded) {
            allList = state.list;
          }

          // Merge branches from backend + attendance
          final List<Map<String, dynamic>> branchList = [];
          final Set<int> addedIds = {};

          for (final loc in _branches) {
            final id = (loc['id'] as num?)?.toInt() ?? (branchList.length + 1);
            if (!addedIds.contains(id)) {
              addedIds.add(id);
              branchList.add(loc);
            }
          }
          for (final st in allList) {
            if (st.filialId != null && !addedIds.contains(st.filialId)) {
              addedIds.add(st.filialId!);
              branchList.add({
                'id': st.filialId!,
                'name': st.filialName ?? 'Filial #${st.filialId}',
                'lat': 0.0,
                'lng': 0.0,
                'radius': 100.0,
              });
            }
          }

          final int activeBranchId =
              _selectedFilialId ??
              (branchList.isNotEmpty ? (branchList.first['id'] as int) : 0);

          final branchStaff = activeBranchId == 0
              ? allList
              : allList
                    .where(
                      (e) => _isStaffInBranch(e, activeBranchId, branchList),
                    )
                    .toList();

          final int countAll = branchStaff.length;
          final int countKelgan = branchStaff
              .where((e) => _matchesFilter(e, KundalikFilter.kelgan))
              .length;
          final int countKechikkan = branchStaff
              .where((e) => _matchesFilter(e, KundalikFilter.kechikkan))
              .length;
          final int countKelmagan = branchStaff
              .where((e) => _matchesFilter(e, KundalikFilter.kelmagan))
              .length;
          final int countHozirIshda = branchStaff
              .where((e) => _matchesFilter(e, KundalikFilter.hozirIshda))
              .length;

          return Column(
            children: [
              // Search & Filter Header Container
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    // Search field
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() {}),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('rahbar_search_hint'),
                        hintStyle: GoogleFonts.outfit(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF0D6E6E),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF0D6E6E),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Branch filter chips row (if branches exist)
                    if (branchList.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: branchList.map((b) {
                            final id = b['id'] as int;
                            final name = (b['name'] ?? 'Filial').toString();
                            final count = allList
                                .where(
                                  (s) => _isStaffInBranch(s, id, branchList),
                                )
                                .length;
                            final bool isFirst = branchList.indexOf(b) == 0;
                            return Padding(
                              padding: EdgeInsets.only(left: isFirst ? 0 : 8),
                              child: _buildBranchFilterChip(
                                id: id,
                                title: '📍 $name',
                                count: count,
                                isSelected: activeBranchId == id,
                                onTap: () =>
                                    setState(() => _selectedFilialId = id),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 2. Status Filter chips row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip(
                            filter: KundalikFilter.all,
                            label: context.tr('notif_filter_all'),
                            count: countAll,
                            icon: Icons.people_alt_rounded,
                            activeColor: const Color(0xFF0D6E6E),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            filter: KundalikFilter.kelgan,
                            label: context.tr('attendance_present'),
                            count: countKelgan,
                            icon: Icons.check_circle_rounded,
                            activeColor: const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            filter: KundalikFilter.kechikkan,
                            label: context.tr('rahbar_kpi_late'),
                            count: countKechikkan,
                            icon: Icons.access_time_filled_rounded,
                            activeColor: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            filter: KundalikFilter.kelmagan,
                            label: context.tr('attendance_absent'),
                            count: countKelmagan,
                            icon: Icons.cancel_rounded,
                            activeColor: Colors.red.shade600,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            filter: KundalikFilter.hozirIshda,
                            label: context.tr('home_currently_working'),
                            count: countHozirIshda,
                            icon: Icons.business_center_rounded,
                            activeColor: const Color(0xFF0D6E6E),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Attendance List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _fetchData(),
                  color: const Color(0xFF0D6E6E),
                  child: Builder(
                    builder: (context) {
                      if (state is RahbarLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0D6E6E),
                          ),
                        );
                      } else if (state is RahbarKundalikLoaded) {
                        final query = _searchController.text
                            .trim()
                            .toLowerCase();

                        final filtered = branchStaff.where((item) {
                          // Apply category filter
                          if (!_matchesFilter(item, _selectedFilter)) {
                            return false;
                          }

                          // Apply search query
                          if (query.isNotEmpty) {
                            final matchName = item.name.toLowerCase().contains(
                              query,
                            );
                            final matchBolim = item.bolim
                                .toLowerCase()
                                .contains(query);
                            final matchLavozim = item.lavozim
                                .toLowerCase()
                                .contains(query);
                            return matchName || matchBolim || matchLavozim;
                          }
                          return true;
                        }).toList();

                        if (filtered.isEmpty) {
                          final title = query.isNotEmpty
                              ? context.tr('rahbar_search_no_staff', {
                                  'query': query,
                                })
                              : context.tr('rahbar_filter_no_data', {
                                  'filter': _getFilterTitle(_selectedFilter),
                                });
                          final subtitle = query.isNotEmpty
                              ? context.tr('rahbar_try_different_search')
                              : context.tr('rahbar_no_staff_on_date', {
                                  'date': _displayFmt.format(_selectedDate),
                                });

                          return RahbarEmptyStateWidget(
                            icon: Icons.search_off_rounded,
                            title: title,
                            subtitle: subtitle,
                            onRefresh: _fetchData,
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _buildStaffCard(item);
                          },
                        );
                      } else if (state is RahbarError) {
                        return RahbarEmptyStateWidget(
                          icon: Icons.error_outline_rounded,
                          title: context.tr('error_occurred_title'),
                          subtitle: state.message,
                          onRefresh: _fetchData,
                        );
                      }
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0D6E6E),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required KundalikFilter filter,
    required String label,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final bool isSelected = _selectedFilter == filter;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchFilterChip({
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
          color: isSelected ? const Color(0xFF0D6E6E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D6E6E)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
                    : const Color(0xFFE2E8F0),
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

  Widget _buildStaffCard(RahbarStaffAttendanceEntity item) {
    final bool isLate = _isLate(item);
    final bool isAbsent = _isAbsent(item);
    final bool isPresent = _isPresent(item);
    final bool isAtWork = _isCurrentlyAtWork(item);

    final String inTimeFormatted = _formatTime(item.checkIn);
    final String outTimeFormatted = _formatTime(item.checkOut);
    final String delayFormatted = _formatDelayText(item.delay);

    // Color theme for border & badges
    Color statusColor;
    List<Color> borderGradient;

    if (isAbsent) {
      statusColor = const Color(0xFFDC2626);
      borderGradient = const [
        Color(0xFFDC2626),
        Color(0xFFEF4444),
        Color(0xFFB91C1C),
        Color(0xFFDC2626),
      ];
    } else if (isLate) {
      statusColor = const Color(0xFFEA580C);
      borderGradient = const [
        Color(0xFFEA580C),
        Color(0xFFF97316),
        Color(0xFFC2410C),
        Color(0xFFEA580C),
      ];
    } else if (isPresent) {
      statusColor = const Color(0xFF16A34A);
      borderGradient = const [
        Color(0xFF16A34A),
        Color(0xFF22C55E),
        Color(0xFF15803D),
        Color(0xFF16A34A),
      ];
    } else {
      statusColor = Colors.grey.shade600;
      borderGradient = [
        Colors.grey.shade400,
        Colors.grey.shade300,
        Colors.grey.shade500,
        Colors.grey.shade400,
      ];
    }

    return AnimatedRotatingBorderContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      borderWidth: 1.8,
      gradientColors: borderGradient,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name, Department, and Status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.bolim}${item.lavozim.isNotEmpty ? " · ${item.lavozim}" : ""}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.status,
                    style: GoogleFonts.outfit(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Kirish vaqti & Chiqish vaqti (Time indicators box)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Kirish vaqti (Nechida kelgani)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _hasCheckIn(item)
                                ? const Color(
                                    0xFF16A34A,
                                  ).withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.login_rounded,
                            size: 16,
                            color: _hasCheckIn(item)
                                ? const Color(0xFF16A34A)
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('rahbar_entry_label'),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              inTimeFormatted,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _hasCheckIn(item)
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(height: 26, width: 1, color: Colors.grey.shade300),
                  const SizedBox(width: 12),

                  // Chiqish vaqti
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _hasCheckOut(item)
                                ? Colors.orange.withValues(alpha: 0.12)
                                : (isAtWork
                                      ? const Color(
                                          0xFF0D6E6E,
                                        ).withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.1)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _hasCheckOut(item)
                                ? Icons.logout_rounded
                                : (isAtWork
                                      ? Icons.business_center_rounded
                                      : Icons.logout_rounded),
                            size: 16,
                            color: _hasCheckOut(item)
                                ? Colors.orange.shade700
                                : (isAtWork
                                      ? const Color(0xFF0D6E6E)
                                      : Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('rahbar_exit_label'),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _hasCheckOut(item)
                                  ? outTimeFormatted
                                  : (isAtWork
                                        ? context.tr('rahbar_at_work_short')
                                        : '--:--'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _hasCheckOut(item)
                                    ? const Color(0xFF1E293B)
                                    : (isAtWork
                                          ? const Color(0xFF0D6E6E)
                                          : Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Worked duration (if available)
                  if (item.ishlaganDaqiqa > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.tr('rahbar_hours_worked', {
                          'hours': (item.ishlaganDaqiqa / 60).toStringAsFixed(
                            1,
                          ),
                        }),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D6E6E),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Row 3: Kechikish vaqti (Qancha vaqt kechikkani) if late
            if (isLate &&
                (delayFormatted.isNotEmpty ||
                    BackendTextMapper.isLate(item.delay))) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      size: 16,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      delayFormatted.isNotEmpty
                          ? delayFormatted
                          : context.tr('rahbar_delay_raw', {
                              'delay': item.delay!.startsWith('+')
                                  ? item.delay!
                                  : '+${item.delay}',
                            }),
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isAtWork) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6E6E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0D6E6E).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D6E6E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('rahbar_currently_at_work_inside'),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D6E6E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
