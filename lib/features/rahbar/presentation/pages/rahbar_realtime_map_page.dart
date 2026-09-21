import 'dart:async';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/avatar_marker_helper.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_assign_zone_page.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

/// Real-Time Live Staff & Branch Map for Admin / Rahbar
class RahbarRealtimeMapPage extends StatefulWidget {
  const RahbarRealtimeMapPage({super.key});

  @override
  State<RahbarRealtimeMapPage> createState() => _RahbarRealtimeMapPageState();
}

class _BranchLocation {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final double radius;

  const _BranchLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
  });
}

class _StaffMapItem {
  final int id;
  final String name;
  final String bolim;
  final String lavozim;
  final String checkIn;
  final String checkOut;
  final String status;
  final bool isInside;
  final String? photo;
  final double lat;
  final double lng;
  final int? filialId;
  final String? filialName;
  final String attendanceStatus; // 'ishda', 'kechikkan', 'kelmagan', 'ketgan'
  final String holat; // 'hududda', 'tashqarida', 'eskirgan', 'jonli'
  final double distanceMeters;
  final String? lastUpdated;

  const _StaffMapItem({
    required this.id,
    required this.name,
    required this.bolim,
    required this.lavozim,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.isInside,
    this.photo,
    required this.lat,
    required this.lng,
    this.filialId,
    this.filialName,
    this.attendanceStatus = '',
    this.holat = '',
    this.distanceMeters = 0.0,
    this.lastUpdated,
  });
}

class _RahbarRealtimeMapPageState extends State<RahbarRealtimeMapPage> {
  YandexMapController? _controller;
  final List<MapObject<dynamic>> _mapObjects = [];
  final Map<int, Uint8List> _markerBytesCache = {};
  final Map<int, int> _markerColorCache = {};
  Uint8List? _officeMarkerBytes;

  List<_BranchLocation> _branches = [];
  int _selectedBranchIndex = 0;

  List<_StaffMapItem> _allStaff = [];
  List<_StaffMapItem> _filteredStaff = [];

  double? _myLat;
  double? _myLng;

  Point? _activeRouteTarget;
  String? _activeRouteStaffName;

  bool _loading = true;
  Timer? _autoRefreshTimer;
  MapType _mapType = MapType.map;
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _staffNameToBranchId = {};
  Map<int, int> _staffIdToBranchId = {};

  @override
  void initState() {
    super.initState();
    _loadAllBackendData();
    _fetchMyLocation();

    // Fast lightweight live location refresh every 4 seconds (without re-fetching heavy static reports)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _refreshLiveOnly();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        final accepted = await LocationDisclosureDialog.show(context);
        if (!accepted) return;
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        if (mounted) {
          setState(() {
            _myLat = pos.latitude;
            _myLng = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  int _parseInt(dynamic val, [int fallback = 0]) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  Future<void> _loadAllBackendData({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final remoteDs = sl<RahbarRemoteDataSource>();

      // 1. Fetch real branches, filial report, and live locations from backend
      final results = await Future.wait([
        remoteDs.getLocations(),
        remoteDs.getKundalik(),
        remoteDs.getFilial(),
        remoteDs.getLiveLocations(),
      ]);
      if (!mounted) return;

      final rawLocations = results[0] as List<Map<String, dynamic>>;
      final List<RahbarStaffAttendanceEntity> attendanceList =
          results[1] as List<RahbarStaffAttendanceEntity>;
      final filialReport = results[2] as Map<String, dynamic>;
      final List<Map<String, dynamic>> liveLocations =
          results[3] as List<Map<String, dynamic>>;

      final List<_BranchLocation> parsedBranches = [];

      for (final loc in rawLocations) {
        final lat = _parseDouble(loc['lat'] ?? loc['latitude']);
        final lng = _parseDouble(loc['lng'] ?? loc['longitude']);
        final radius = _parseDouble(
          loc['radius_meter'] ?? loc['radius'] ?? loc['radius_m'],
          100.0,
        );
        final name =
            (loc['name'] ?? loc['nom'] ?? context.tr('rahbar_branch_fallback'))
                .toString();
        final id = _parseInt(loc['id']);

        if (lat != 0.0 && lng != 0.0) {
          parsedBranches.add(
            _BranchLocation(
              id: id,
              name: name,
              lat: lat,
              lng: lng,
              radius: radius.clamp(20.0, 1000.0),
            ),
          );
        }
      }

      // Build staff name and ID -> branch ID mapping from Filial Report (getFilial)
      final rawFiliallar = (filialReport['filiallar'] as List?) ?? const [];
      final Map<String, int> staffNameToBranch = {};
      final Map<int, int> staffIdToBranch = {};
      _BranchLocation? unassignedBranchObj;

      for (final f in rawFiliallar) {
        final fMap = Map<String, dynamic>.from(f as Map);
        final fNom = (fMap['nom'] ?? fMap['name'] ?? '').toString().trim();
        final fId = _parseInt(
          fMap['id'] ?? fMap['filial_id'] ?? fMap['location_id'],
        );
        final fStaff = (fMap['xodimlar'] as List?) ?? const [];

        final isUnassigned =
            fNom.isEmpty ||
            fNom.toLowerCase().contains('biriktirilmagan') ||
            fNom.toLowerCase().contains('unassigned');

        if (isUnassigned) {
          if (fStaff.isNotEmpty) {
            final unassignedName =
                fNom.isNotEmpty ? fNom : 'Filial biriktirilmagan';
            unassignedBranchObj = _BranchLocation(
              id: 0,
              name: unassignedName,
              lat: 0.0,
              lng: 0.0,
              radius: 0.0,
            );
            for (final st in fStaff) {
              final stMap = Map<String, dynamic>.from(st as Map);
              final stName = (stMap['name'] ?? stMap['xodim'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              if (stName.isNotEmpty) {
                staffNameToBranch[stName] = 0;
              }
              final stId = _parseInt(stMap['id'] ?? stMap['staff_id']);
              if (stId > 0) {
                staffIdToBranch[stId] = 0;
              }
            }
          }
        } else {
          int? targetBranchId;
          if (fId > 0) {
            for (final b in parsedBranches) {
              if (b.id == fId) {
                targetBranchId = b.id;
                break;
              }
            }
          }
          if (targetBranchId == null && fNom.isNotEmpty) {
            final nomLower = fNom.toLowerCase();
            for (final b in parsedBranches) {
              final bName = b.name.toLowerCase();
              if (bName == nomLower ||
                  bName.contains(nomLower) ||
                  nomLower.contains(bName)) {
                targetBranchId = b.id;
                break;
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
              final stId = _parseInt(stMap['id'] ?? stMap['staff_id']);
              if (stId > 0) {
                staffIdToBranch[stId] = targetBranchId;
              }
            }
          }
        }
      }

      _staffNameToBranchId = staffNameToBranch;
      _staffIdToBranchId = staffIdToBranch;
      parsedBranches.sort((a, b) => a.id.compareTo(b.id));
      if (unassignedBranchObj != null) {
        parsedBranches.add(unassignedBranchObj);
      }
      _branches = parsedBranches;

      final List<_StaffMapItem> parsedStaff = [];
      final currentBranch =
          (_branches.isNotEmpty &&
              _selectedBranchIndex >= 0 &&
              _selectedBranchIndex < _branches.length)
          ? _branches[_selectedBranchIndex]
          : (_branches.isNotEmpty ? _branches.first : null);

      // Map live locations by staff ID and normalized name
      final Map<int, Map<String, dynamic>> liveById = {};
      final Map<String, Map<String, dynamic>> liveByName = {};
      for (final item in liveLocations) {
        final lid = _parseInt(item['id'] ?? item['staff_id']);
        if (lid > 0) liveById[lid] = item;
        final lName = (item['name'] ?? item['full_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (lName.isNotEmpty) liveByName[lName] = item;
      }

      for (int i = 0; i < attendanceList.length; i++) {
        final s = attendanceList[i];
        final bool hasCheckIn =
            s.checkIn != null && s.checkIn!.isNotEmpty && s.checkIn != '--:--';
        final bool hasCheckOut =
            s.checkOut != null &&
            s.checkOut!.isNotEmpty &&
            s.checkOut != '--:--';
        final bool isInside = hasCheckIn && !hasCheckOut;

        final liveItem =
            liveById[s.id] ?? liveByName[s.name.trim().toLowerCase()];
        final String liveAtt = (liveItem?['attendance_status'] ?? '')
            .toString()
            .trim();
        final String liveHolat = (liveItem?['holat'] ?? '').toString().trim();

        // 1. Prefer real-time GPS coordinates from /api/rahbar/lokatsiya/live (check top-level and nested 'location')
        double staffLat = 0.0;
        double staffLng = 0.0;
        if (liveItem != null) {
          final loc = liveItem['location'];
          if (loc is Map) {
            staffLat = _parseDouble(loc['latitude'] ?? loc['lat']);
            staffLng = _parseDouble(loc['longitude'] ?? loc['lng']);
          } else {
            staffLat = _parseDouble(
              liveItem['lat'] ??
                  liveItem['latitude'] ??
                  liveItem['location_lat'],
            );
            staffLng = _parseDouble(
              liveItem['lng'] ??
                  liveItem['longitude'] ??
                  liveItem['location_lng'],
            );
          }
        }

        // 2. Fallback to s.lat / s.lng (from check-in record) ONLY if real coordinates
        if (staffLat == 0.0 || staffLng == 0.0) {
          staffLat = s.lat ?? 0.0;
          staffLng = s.lng ?? 0.0;
        }

        final int targetBranchId = _getStaffBranchId(
          filialId: s.filialId,
          filialName: s.filialName,
          staffName: s.name,
          staffId: s.id,
          lat: staffLat,
          lng: staffLng,
        );

        _BranchLocation? staffBranch;
        for (final b in _branches) {
          if (b.id == targetBranchId) {
            staffBranch = b;
            break;
          }
        }
        staffBranch ??=
            currentBranch ?? (_branches.isNotEmpty ? _branches.first : null);

        // Geofence masofasini hisoblash (xodim biriktirilgan O'Z filialiga nisbatan)
        bool isInsideReal = isInside;
        String calculatedHolat = liveHolat;
        double distanceMeters = 0.0;

        if (staffBranch != null &&
            staffBranch.lat != 0.0 &&
            staffBranch.lng != 0.0 &&
            staffLat != 0.0 &&
            staffLng != 0.0) {
          distanceMeters = Geolocator.distanceBetween(
            staffLat,
            staffLng,
            staffBranch.lat,
            staffBranch.lng,
          );
          isInsideReal = distanceMeters <= staffBranch.radius;
          calculatedHolat = isInsideReal ? 'hududda' : 'tashqarida';
        } else if (staffLat != 0.0 && staffLng != 0.0) {
          calculatedHolat = 'tashqarida';
        } else {
          calculatedHolat = isInside ? 'hududda' : 'joylashuv_yoq';
        }

        final String? timeStr =
            liveItem?['time']?.toString() ??
            liveItem?['updated_at']?.toString() ??
            liveItem?['recorded_at']?.toString() ??
            liveItem?['vaqt']?.toString();
        final int? agoMin = liveItem?['ago_min'] != null
            ? _parseInt(liveItem!['ago_min'])
            : null;
        final String? lastUpdatedDisplay = timeStr != null
            ? (agoMin != null && agoMin > 0
                  ? context.tr('rahbar_time_ago', {
                      'time': timeStr,
                      'min': '$agoMin',
                    })
                  : timeStr)
            : null;

        parsedStaff.add(
          _StaffMapItem(
            id: s.id,
            name: s.name,
            bolim: s.bolim,
            lavozim: s.lavozim,
            checkIn: s.checkIn ?? '--:--',
            checkOut: s.checkOut ?? '--:--',
            status: s.status,
            isInside: isInsideReal,
            photo: s.photo,
            lat: staffLat,
            lng: staffLng,
            filialId: staffBranch?.id ?? targetBranchId,
            filialName: staffBranch?.name ?? s.filialName,
            attendanceStatus: liveAtt.isNotEmpty
                ? liveAtt
                : (isInside ? 'ishda' : (hasCheckIn ? 'ketgan' : 'kelmagan')),
            holat: calculatedHolat,
            distanceMeters: distanceMeters,
            lastUpdated: lastUpdatedDisplay,
          ),
        );
      }

      // Also add any staff reported exclusively by /api/rahbar/lokatsiya/live
      final existingIds = parsedStaff.map((e) => e.id).toSet();
      for (final item in liveLocations) {
        final lid = _parseInt(item['id'] ?? item['staff_id']);
        if (lid > 0 && !existingIds.contains(lid)) {
          double lLat = 0.0;
          double lLng = 0.0;
          final loc = item['location'];
          if (loc is Map) {
            lLat = _parseDouble(loc['latitude'] ?? loc['lat']);
            lLng = _parseDouble(loc['longitude'] ?? loc['lng']);
          } else {
            lLat = _parseDouble(
              item['lat'] ?? item['latitude'] ?? item['location_lat'],
            );
            lLng = _parseDouble(
              item['lng'] ?? item['longitude'] ?? item['location_lng'],
            );
          }

          if (lLat != 0.0 && lLng != 0.0) {
            final lName =
                (item['name'] ??
                        item['full_name'] ??
                        context.tr('rahbar_staff_fallback'))
                    .toString();
            final lAtt = (item['attendance_status'] ?? 'ishda').toString();
            final lHolat = (item['holat'] ?? 'hududda').toString();

            final int liveTargetBranchId = _getStaffBranchId(
              filialId: _parseInt(item['filial_id'] ?? item['branch_id']),
              filialName:
                  (item['filial_name'] ?? item['branch_name'])?.toString(),
              staffName: lName,
              staffId: lid,
              lat: lLat,
              lng: lLng,
            );

            _BranchLocation? liveBranch;
            for (final b in _branches) {
              if (b.id == liveTargetBranchId) {
                liveBranch = b;
                break;
              }
            }
            liveBranch ??=
                currentBranch ?? (_branches.isNotEmpty ? _branches.first : null);

            double distanceMeters = 0.0;
            bool isInsideReal = false;
            if (liveBranch != null &&
                liveBranch.lat != 0.0 &&
                liveBranch.lng != 0.0) {
              distanceMeters = Geolocator.distanceBetween(
                lLat,
                lLng,
                liveBranch.lat,
                liveBranch.lng,
              );
              isInsideReal = distanceMeters <= liveBranch.radius;
            }

            parsedStaff.add(
              _StaffMapItem(
                id: lid,
                name: lName,
                bolim: (item['bolim'] ?? item['bolim_name'] ?? '').toString(),
                lavozim: (item['lavozim'] ?? item['lavozim_name'] ?? '')
                    .toString(),
                checkIn: '--:--',
                checkOut: '--:--',
                status: lAtt,
                isInside: isInsideReal,
                photo:
                    item['photo']?.toString() ?? item['photo_url']?.toString(),
                lat: lLat,
                lng: lLng,
                filialId: liveBranch?.id ?? liveTargetBranchId,
                filialName: liveBranch?.name,
                attendanceStatus: lAtt,
                holat: isInsideReal
                    ? 'hududda'
                    : (lHolat.isNotEmpty ? lHolat : 'tashqarida'),
                distanceMeters: distanceMeters,
                lastUpdated: (() {
                  final String? t =
                      item['time']?.toString() ??
                      item['updated_at']?.toString() ??
                      item['recorded_at']?.toString() ??
                      item['vaqt']?.toString();
                  final int? ago = item['ago_min'] != null
                      ? _parseInt(item['ago_min'])
                      : null;
                  return t != null
                      ? (ago != null && ago > 0
                            ? context.tr('rahbar_time_ago', {
                                'time': t,
                                'min': '$ago',
                              })
                            : t)
                      : null;
                })(),
              ),
            );
          }
        }
      }

      _allStaff = parsedStaff;
      _filterStaff(_searchController.text);
      await _generateMarkerBytes();
      _buildMapObjects();

      if (mounted) {
        setState(() => _loading = false);
      }

      // Initial camera move on fresh first load only
      if (!silent) {
        _moveCameraToBranch();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _getStaffBranchId({
    required int? filialId,
    required String? filialName,
    required String staffName,
    int? staffId,
    required double lat,
    required double lng,
  }) {
    if (_branches.isEmpty) return 0;
    if (_branches.length == 1) return _branches.first.id;

    final staffNameLower = staffName.trim().toLowerCase();

    // 1. Direct ID match from Filial Report (getFilial)
    if (staffId != null && _staffIdToBranchId.containsKey(staffId)) {
      final bId = _staffIdToBranchId[staffId]!;
      if (_branches.any((b) => b.id == bId)) return bId;
    }

    // 2. Direct Name match from Filial Report (getFilial)
    if (_staffNameToBranchId.containsKey(staffNameLower)) {
      final bId = _staffNameToBranchId[staffNameLower]!;
      if (_branches.any((b) => b.id == bId)) return bId;
    }
    for (final entry in _staffNameToBranchId.entries) {
      if (staffNameLower.isNotEmpty &&
          (staffNameLower.contains(entry.key) ||
              entry.key.contains(staffNameLower))) {
        if (_branches.any((b) => b.id == entry.value)) return entry.value;
      }
    }

    // 3. Explicit filial ID from attendance record
    if (filialId != null) {
      for (final b in _branches) {
        if (b.id == filialId) return filialId;
      }
    }

    // 4. Explicit filial name from attendance record
    if (filialName != null && filialName.trim().isNotEmpty) {
      final sName = filialName.trim().toLowerCase();
      for (final b in _branches) {
        final bName = b.name.trim().toLowerCase();
        if (bName.isNotEmpty &&
            (sName == bName ||
                sName.contains(bName) ||
                bName.contains(sName))) {
          return b.id;
        }
      }
    }

    // 5. If filialName indicates unassigned, return branch 0 if exists
    if (filialName != null) {
      final fnLower = filialName.toLowerCase();
      if (fnLower.contains('biriktirilmagan') ||
          fnLower.contains('unassigned')) {
        for (final b in _branches) {
          if (b.id == 0) return 0;
        }
      }
    }

    // 6. Name parts matching branch name
    if (staffNameLower.isNotEmpty) {
      for (final b in _branches) {
        final bName = b.name.trim().toLowerCase();
        final nameParts = staffNameLower.split(' ');
        for (final part in nameParts) {
          if (part.length >= 4 && bName.contains(part)) {
            return b.id;
          }
        }
      }
    }

    return _branches.isNotEmpty ? _branches.first.id : 0;
  }

  bool _isStaffInCurrentBranch(_StaffMapItem s, _BranchLocation branch) {
    final staffBranchId = _getStaffBranchId(
      filialId: s.filialId,
      filialName: s.filialName,
      staffName: s.name,
      staffId: s.id,
      lat: s.lat,
      lng: s.lng,
    );

    return staffBranchId == branch.id;
  }

  void _onBranchSelected(int index) {
    setState(() {
      _selectedBranchIndex = index;
      _filterStaff(_searchController.text);
      _buildMapObjects();
    });
    _moveCameraToBranch();
  }

  Future<void> _generateMarkerBytes() async {
    _officeMarkerBytes ??= await AvatarMarkerHelper.generateOfficePinBytes();
    for (final staff in _allStaff) {
      Color pinColor;
      final att = staff.attendanceStatus.toLowerCase();
      if (staff.isInside) {
        pinColor = const Color(0xFF16A34A); // Green (Hudud ichida)
      } else if (staff.lat != 0.0 && staff.lng != 0.0) {
        // Tashqarida bo'lsa
        if (att == 'ishda') {
          pinColor = const Color(0xFFEA580C); // Orange (Tashqarida ishda)
        } else if (att == 'kechikkan') {
          pinColor = const Color(0xFFD97706); // Amber (Kechikkan)
        } else {
          pinColor = const Color(0xFFE11D48); // Rose/Red (Tashqarida)
        }
      } else if (att == 'ishda') {
        pinColor = const Color(0xFF16A34A);
      } else if (att == 'kechikkan') {
        pinColor = const Color(0xFFEA580C);
      } else if (att == 'ketgan') {
        pinColor = const Color(0xFF64748B);
      } else {
        pinColor = const Color(0xFFDC2626);
      }

      final colorInt = pinColor.toARGB32();
      if (_markerBytesCache.containsKey(staff.id) &&
          _markerColorCache[staff.id] == colorInt) {
        continue; // Already rasterized and cached! Skip Canvas repaint!
      }

      final bytes = await AvatarMarkerHelper.generateAvatarPinBytes(
        name: staff.name,
        statusColor: pinColor,
        photoUrl: staff.photo,
      );
      _markerBytesCache[staff.id] = bytes;
      _markerColorCache[staff.id] = colorInt;
    }
  }

  /// Fast lightweight live location polling: only hits live-locations API,
  /// updates coordinates and only repaints if positions actually changed!
  Future<void> _refreshLiveOnly() async {
    try {
      final remoteDs = sl<RahbarRemoteDataSource>();
      final liveLocations = await remoteDs.getLiveLocations();
      if (!mounted || liveLocations.isEmpty) return;

      final Map<int, Map<String, dynamic>> liveById = {};
      final Map<String, Map<String, dynamic>> liveByName = {};
      for (final item in liveLocations) {
        final lid = _parseInt(item['id'] ?? item['staff_id']);
        if (lid > 0) liveById[lid] = item;
        final lName = (item['name'] ?? item['full_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (lName.isNotEmpty) liveByName[lName] = item;
      }

      for (int i = 0; i < _allStaff.length; i++) {
        final s = _allStaff[i];
        final liveItem =
            liveById[s.id] ?? liveByName[s.name.trim().toLowerCase()];
        if (liveItem == null) continue;

        double staffLat = 0.0;
        double staffLng = 0.0;
        final loc = liveItem['location'];
        if (loc is Map) {
          staffLat = _parseDouble(loc['latitude'] ?? loc['lat']);
          staffLng = _parseDouble(loc['longitude'] ?? loc['lng']);
        } else {
          staffLat = _parseDouble(
            liveItem['lat'] ?? liveItem['latitude'] ?? liveItem['location_lat'],
          );
          staffLng = _parseDouble(
            liveItem['lng'] ??
                liveItem['longitude'] ??
                liveItem['location_lng'],
          );
        }

        if (staffLat != 0.0 && staffLng != 0.0) {
          _BranchLocation? staffBranch;
          for (final b in _branches) {
            if (b.id == s.filialId) {
              staffBranch = b;
              break;
            }
          }

          double distanceMeters = 0.0;
          bool isInside = s.isInside;
          if (staffBranch != null &&
              staffBranch.lat != 0.0 &&
              staffBranch.lng != 0.0) {
            distanceMeters = Geolocator.distanceBetween(
              staffLat,
              staffLng,
              staffBranch.lat,
              staffBranch.lng,
            );
            isInside = distanceMeters <= staffBranch.radius;
          }

          _allStaff[i] = _StaffMapItem(
            id: s.id,
            name: s.name,
            bolim: s.bolim,
            lavozim: s.lavozim,
            checkIn: s.checkIn,
            checkOut: s.checkOut,
            status: s.status,
            isInside: isInside,
            photo: s.photo,
            lat: staffLat,
            lng: staffLng,
            filialId: s.filialId,
            filialName: s.filialName,
            attendanceStatus: s.attendanceStatus,
            holat: isInside ? 'hududda' : 'tashqarida',
            distanceMeters: distanceMeters,
            lastUpdated: (() {
              final String? t =
                  liveItem['time']?.toString() ??
                  liveItem['updated_at']?.toString() ??
                  liveItem['recorded_at']?.toString() ??
                  liveItem['vaqt']?.toString();
              final int? ago = liveItem['ago_min'] != null
                  ? _parseInt(liveItem['ago_min'])
                  : null;
              return t != null
                  ? (ago != null && ago > 0
                        ? context.tr('rahbar_time_ago', {
                            'time': t,
                            'min': '$ago',
                          })
                        : t)
                  : null;
            })(),
          );
        }
      }

      // Check if any brand new staff in liveLocations that was not in _allStaff
      final existingIds = _allStaff.map((e) => e.id).toSet();
      for (final item in liveLocations) {
        final lid = _parseInt(item['id'] ?? item['staff_id']);
        if (lid > 0 && !existingIds.contains(lid)) {
          double lLat = 0.0;
          double lLng = 0.0;
          final loc = item['location'];
          if (loc is Map) {
            lLat = _parseDouble(loc['latitude'] ?? loc['lat']);
            lLng = _parseDouble(loc['longitude'] ?? loc['lng']);
          } else {
            lLat = _parseDouble(
              item['lat'] ?? item['latitude'] ?? item['location_lat'],
            );
            lLng = _parseDouble(
              item['lng'] ?? item['longitude'] ?? item['location_lng'],
            );
          }
          if (lLat != 0.0 && lLng != 0.0) {
            final lName =
                (item['name'] ??
                        item['full_name'] ??
                        context.tr('rahbar_staff_fallback'))
                    .toString();
            final lAtt = (item['attendance_status'] ?? 'ishda').toString();
            final lHolat = (item['holat'] ?? 'hududda').toString();

            final int liveTargetBranchId = _getStaffBranchId(
              filialId: _parseInt(item['filial_id'] ?? item['branch_id']),
              filialName:
                  (item['filial_name'] ?? item['branch_name'])?.toString(),
              staffName: lName,
              staffId: lid,
              lat: lLat,
              lng: lLng,
            );

            _BranchLocation? liveBranch;
            for (final b in _branches) {
              if (b.id == liveTargetBranchId) {
                liveBranch = b;
                break;
              }
            }
            liveBranch ??= (_branches.isNotEmpty ? _branches.first : null);

            double distanceMeters = 0.0;
            bool isInside = false;
            if (liveBranch != null &&
                liveBranch.lat != 0.0 &&
                liveBranch.lng != 0.0) {
              distanceMeters = Geolocator.distanceBetween(
                lLat,
                lLng,
                liveBranch.lat,
                liveBranch.lng,
              );
              isInside = distanceMeters <= liveBranch.radius;
            }

            _allStaff.add(
              _StaffMapItem(
                id: lid,
                name: lName,
                bolim: (item['bolim'] ?? item['bolim_name'] ?? '').toString(),
                lavozim: (item['lavozim'] ?? item['lavozim_name'] ?? '')
                    .toString(),
                checkIn: '--:--',
                checkOut: '--:--',
                status: lAtt,
                isInside: isInside,
                photo:
                    item['photo']?.toString() ?? item['photo_url']?.toString(),
                lat: lLat,
                lng: lLng,
                filialId: liveBranch?.id ?? liveTargetBranchId,
                filialName: liveBranch?.name,
                attendanceStatus: lAtt,
                holat: isInside
                    ? 'hududda'
                    : (lHolat.isNotEmpty ? lHolat : 'tashqarida'),
                distanceMeters: distanceMeters,
                lastUpdated: (() {
                  final String? t =
                      item['time']?.toString() ??
                      item['updated_at']?.toString() ??
                      item['recorded_at']?.toString() ??
                      item['vaqt']?.toString();
                  final int? ago = item['ago_min'] != null
                      ? _parseInt(item['ago_min'])
                      : null;
                  return t != null
                      ? (ago != null && ago > 0
                            ? context.tr('rahbar_time_ago', {
                                'time': t,
                                'min': '$ago',
                              })
                            : t)
                      : null;
                })(),
              ),
            );
          }
        }
      }

      // Always refresh map UI on every poll cycle
      if (mounted) {
        _filterStaff(_searchController.text);
        await _generateMarkerBytes();
        if (mounted) {
          _buildMapObjects();
        }
      }
    } catch (_) {}
  }

  void _filterStaff(String query) {
    List<_StaffMapItem> baseStaff;
    if (_branches.isNotEmpty) {
      final currentBranch =
          _branches[_selectedBranchIndex.clamp(0, _branches.length - 1)];
      baseStaff = _allStaff
          .where((s) => _isStaffInCurrentBranch(s, currentBranch))
          .toList();
    } else {
      baseStaff = _allStaff;
    }

    if (query.trim().isEmpty) {
      _filteredStaff = baseStaff;
    } else {
      final q = query.toLowerCase();
      _filteredStaff = baseStaff.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.bolim.toLowerCase().contains(q) ||
            s.lavozim.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _buildMapObjects() {
    _mapObjects.clear();

    // 1. Draw all configured branches (circles & clean center dots)
    for (int i = 0; i < _branches.length; i++) {
      final branch = _branches[i];
      if (branch.lat == 0.0 || branch.lng == 0.0) continue;
      final bool isCurrent = i == _selectedBranchIndex;

      // Circle geofence zone
      _mapObjects.add(
        CircleMapObject(
          mapId: MapObjectId('branch_zone_${branch.id}'),
          circle: Circle(
            center: Point(latitude: branch.lat, longitude: branch.lng),
            radius: branch.radius,
          ),
          strokeColor: isCurrent
              ? const Color(0xFF0D6E6E)
              : Colors.grey.shade600,
          strokeWidth: isCurrent ? 2.5 : 1.5,
          fillColor: (isCurrent ? const Color(0xFF0D6E6E) : Colors.grey)
              .withValues(alpha: isCurrent ? 0.18 : 0.08),
          zIndex: isCurrent ? 2.0 : 1.0,
          consumeTapEvents: true,
          onTap: (object, point) => _onBranchSelected(i),
        ),
      );

      // Clean Minimalist Center Dot Marker (Oddiy nuqta)
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('branch_dot_${branch.id}'),
          point: Point(latitude: branch.lat, longitude: branch.lng),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: _officeMarkerBytes != null
                  ? BitmapDescriptor.fromBytes(_officeMarkerBytes!)
                  : BitmapDescriptor.fromAssetImage(
                      'assets/images/work_marker.png',
                    ),
              scale: isCurrent ? 0.9 : 0.75,
            ),
          ),
          opacity: 1.0,
          zIndex: isCurrent ? 6.0 : 5.0,
          consumeTapEvents: true,
          onTap: (object, point) => _onBranchSelected(i),
        ),
      );
    }

    // 2. Real Staff Markers with Photo Pins
    // Xodim 'hududda' yoki 'tashqarida' bo'lishidan qat'i nazar — REAL GPS koordinatasi bo'lsa ALBATTA xaritada ko'rsatiladi!
    for (final staff in _filteredStaff) {
      if (staff.lat == 0.0 || staff.lng == 0.0) continue;
      final staffPoint = Point(latitude: staff.lat, longitude: staff.lng);
      final bytes = _markerBytesCache[staff.id];

      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('staff_${staff.id}'),
          point: staffPoint,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: bytes != null
                  ? BitmapDescriptor.fromBytes(bytes)
                  : BitmapDescriptor.fromAssetImage(
                      'assets/images/user_marker.png',
                    ),
              scale: 0.85,
            ),
          ),
          opacity: 1.0,
          zIndex: 10.0,
          consumeTapEvents: true,
          onTap: (object, point) => _showStaffBottomSheet(staff, staffPoint),
        ),
      );
    }

    // 3. In-App Polyline route between branch and staff if active
    if (_activeRouteTarget != null && _branches.isNotEmpty) {
      final currentBranch =
          (_selectedBranchIndex >= 0 && _selectedBranchIndex < _branches.length)
          ? _branches[_selectedBranchIndex]
          : _branches.first;
      if (currentBranch.lat != 0.0 && currentBranch.lng != 0.0) {
        final start = Point(
          latitude: currentBranch.lat,
          longitude: currentBranch.lng,
        );

        _mapObjects.add(
          PolylineMapObject(
            mapId: const MapObjectId('in_app_staff_route'),
            polyline: Polyline(points: [start, _activeRouteTarget!]),
            strokeColor: const Color(0xFF0D6E6E),
            strokeWidth: 4.0,
            outlineColor: Colors.white,
            outlineWidth: 1.5,
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  void _moveCameraToBranch() {
    if (_branches.isEmpty) return;
    final b =
        (_selectedBranchIndex >= 0 && _selectedBranchIndex < _branches.length)
        ? _branches[_selectedBranchIndex]
        : _branches.first;
    if (b.lat != 0.0 && b.lng != 0.0) {
      _controller?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: b.lat, longitude: b.lng),
            zoom: 15.5,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.8,
        ),
      );
    } else {
      final staffWithCoords =
          _filteredStaff.where((s) => s.lat != 0.0 && s.lng != 0.0).toList();
      if (staffWithCoords.isNotEmpty) {
        final firstStaff = staffWithCoords.first;
        _controller?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: Point(latitude: firstStaff.lat, longitude: firstStaff.lng),
              zoom: 15.5,
            ),
          ),
          animation: const MapAnimation(
            type: MapAnimationType.smooth,
            duration: 0.8,
          ),
        );
      }
    }
  }

  void _moveCameraToMyLoc() {
    if (_myLat == null || _myLng == null) return;
    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: _myLat!, longitude: _myLng!),
          zoom: 16.5,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.8,
      ),
    );
  }

  void _drawInAppRouteToStaff(_StaffMapItem staff) {
    if (_branches.isEmpty) return;
    final branch =
        _branches[_selectedBranchIndex.clamp(0, _branches.length - 1)];

    final startPoint = Point(latitude: branch.lat, longitude: branch.lng);
    final endPoint = Point(latitude: staff.lat, longitude: staff.lng);

    setState(() {
      _activeRouteTarget = endPoint;
      _activeRouteStaffName = staff.name;
    });

    _buildMapObjects();

    final midLat = (startPoint.latitude + endPoint.latitude) / 2;
    final midLng = (startPoint.longitude + endPoint.longitude) / 2;

    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: midLat, longitude: midLng),
          zoom: 15.5,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.8,
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, {double radius = 26}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF0D6E6E).withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
          color: const Color(0xFF0D6E6E),
        ),
      ),
    );
  }

  void _showStaffBottomSheet(_StaffMapItem staff, Point point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (staff.photo != null &&
                    staff.photo!.isNotEmpty &&
                    !staff.photo!.contains('localhost') &&
                    (staff.photo!.startsWith('http://') ||
                        staff.photo!.startsWith('https://')))
                  CachedNetworkImage(
                    imageUrl: staff.photo!,
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 26,
                      backgroundImage: imageProvider,
                    ),
                    placeholder: (context, url) =>
                        _buildFallbackAvatar(staff.name),
                    errorWidget: (context, url, error) =>
                        _buildFallbackAvatar(staff.name),
                  )
                else
                  _buildFallbackAvatar(staff.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${staff.bolim}${staff.lavozim.isNotEmpty ? " · ${staff.lavozim}" : ""}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (_) {
                    final att = staff.attendanceStatus.toLowerCase();
                    Color badgeColor;
                    String badgeLabel;

                    if (att == 'ishda') {
                      badgeColor = const Color(0xFF16A34A);
                      badgeLabel = context.tr('rahbar_badge_at_work');
                    } else if (att == 'kechikkan') {
                      badgeColor = const Color(0xFFEA580C);
                      badgeLabel = context.tr('rahbar_kpi_late');
                    } else if (att == 'kelmagan') {
                      badgeColor = const Color(0xFFDC2626);
                      badgeLabel = context.tr('attendance_absent');
                    } else if (att == 'ketgan') {
                      badgeColor = const Color(0xFF64748B);
                      badgeLabel = context.tr('rahbar_badge_left');
                    } else {
                      badgeColor = staff.isInside
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEA580C);
                      badgeLabel = staff.isInside
                          ? context.tr('rahbar_badge_at_work')
                          : context.tr('rahbar_badge_outside');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: badgeColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                badgeLabel,
                                style: GoogleFonts.outfit(
                                  color: badgeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (staff.holat.isNotEmpty &&
                            staff.holat != badgeLabel.toLowerCase())
                          Padding(
                            padding: const EdgeInsets.only(top: 3, right: 4),
                            child: Text(
                              staff.holat,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeDetail(
                  context.tr('rahbar_checkin_time_label'),
                  staff.checkIn,
                  Icons.login_rounded,
                  const Color(0xFF0D6E6E),
                ),
                _buildTimeDetail(
                  context.tr('rahbar_checkout_time_label'),
                  staff.checkOut,
                  Icons.logout_rounded,
                  const Color(0xFFF5A623),
                ),
                _buildTimeDetail(
                  context.tr('rahbar_status_label'),
                  staff.status,
                  Icons.verified_user_rounded,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Button 1: Assign In-App Work Geofence Zone for this staff
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E6E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RahbarAssignZonePage(
                        staffName: staff.name,
                        staffId: staff.id,
                        initialLat: staff.lat,
                        initialLng: staff.lng,
                      ),
                    ),
                  );
                  if (result == true) {
                    unawaited(_loadAllBackendData());
                  }
                },
                icon: const Icon(Icons.add_location_alt_rounded),
                label: Text(
                  context.tr('rahbar_assign_zone_button'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Button 2: Draw in-app route polyline on our map
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D6E6E),
                  side: const BorderSide(color: Color(0xFF0D6E6E), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _drawInAppRouteToStaff(staff);
                },
                icon: const Icon(
                  Icons.alt_route_rounded,
                  color: Color(0xFF0D6E6E),
                ),
                label: Text(
                  context.tr('rahbar_view_route_button'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDetail(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch =
        (_branches.isNotEmpty &&
            _selectedBranchIndex >= 0 &&
            _selectedBranchIndex < _branches.length)
        ? _branches[_selectedBranchIndex]
        : null;
    final currentBranchStaff = currentBranch != null
        ? _allStaff
              .where((s) => _isStaffInCurrentBranch(s, currentBranch))
              .toList()
        : _allStaff;
    final totalCount = currentBranchStaff.length;
    final withGps = currentBranchStaff
        .where((s) => s.lat != 0.0 && s.lng != 0.0)
        .toList();
    final insideCount = withGps.where((s) => s.isInside).length;
    final outsideCount = withGps.length - insideCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('rahbar_map_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D6E6E),
            fontSize: 18,
          ),
        ),
        actions: [
          // "Yangi hudud" button placed on top in AppBar replacing manual refresh icon
          Container(
            margin: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6E6E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RahbarAssignZonePage(),
                  ),
                );
                if (result == true) {
                  unawaited(_loadAllBackendData());
                }
              },
              icon: const Icon(Icons.add_location_alt_rounded, size: 16),
              label: Text(
                context.tr('rahbar_new_zone_button'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Yandex Map Widget
          YandexMap(
            mapType: _mapType,
            mapObjects: _mapObjects,
            onMapCreated: (controller) async {
              _controller = controller;
              _moveCameraToBranch();
            },
          ),

          // 2. Top Controls & Live Summary Card
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              children: [
                // Live count badges
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  context.tr('rahbar_live_badge'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            context.tr('rahbar_total_count', {
                              'count': '$totalCount',
                            }),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('rahbar_inside_count', {
                              'count': '$insideCount',
                            }),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('rahbar_outside_count', {
                              'count': '$outsideCount',
                            }),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),

                      // If multiple branches exist, display a branch selector
                      if (_branches.length > 1) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(_branches.length, (idx) {
                              final b = _branches[idx];
                              final isSelected = idx == _selectedBranchIndex;
                              final count = _allStaff
                                  .where((s) => _isStaffInCurrentBranch(s, b))
                                  .length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('${b.name} ($count)'),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF0D6E6E),
                                  labelStyle: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade800,
                                  ),
                                  onSelected: (_) => _onBranchSelected(idx),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // If active in-app route is showing, display a route dismiss bar
                if (_activeRouteTarget != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6E6E),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alt_route_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('rahbar_route_label', {
                              'name':
                                  _activeRouteStaffName ??
                                  context.tr('rahbar_staff_fallback'),
                            }),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeRouteTarget = null;
                              _activeRouteStaffName = null;
                            });
                            _buildMapObjects();
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Search field
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _filterStaff(val);
                        _buildMapObjects();
                      });
                    },
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFF0D6E6E),
                    decoration: InputDecoration(
                      hintText: context.tr('rahbar_search_staff_plural'),
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13.5,
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
                                setState(() {
                                  _filterStaff('');
                                  _buildMapObjects();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating action buttons on bottom right (Layers, Center, My Location)
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_layer_toggle',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D6E6E),
                  onPressed: () {
                    setState(() {
                      _mapType = _mapType == MapType.map
                          ? MapType.hybrid
                          : MapType.map;
                    });
                  },
                  child: const Icon(Icons.layers_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'center_branch',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D6E6E),
                  onPressed: _moveCameraToBranch,
                  child: const Icon(Icons.center_focus_strong_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'my_location',
                  backgroundColor: const Color(0xFF0D6E6E),
                  foregroundColor: Colors.white,
                  onPressed: _moveCameraToMyLoc,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),

          // 4. Loading overlay (only on fresh first load)
          if (_loading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D6E6E)),
              ),
            ),
        ],
      ),
    );
  }
}
