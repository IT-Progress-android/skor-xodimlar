import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/app_day.dart';
import 'package:skore_hodimlar/core/utils/avatar_marker_helper.dart';
import 'package:skore_hodimlar/core/widgets/location_disclosure_dialog.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:skore_hodimlar/features/rahbar/data/live_playback.dart';
import 'package:skore_hodimlar/features/rahbar/data/location_outage.dart';
import 'package:skore_hodimlar/features/rahbar/data/speed_track.dart';
import 'package:skore_hodimlar/features/rahbar/data/staff_stops.dart';
import 'package:skore_hodimlar/features/rahbar/data/street_router.dart';
import 'package:skore_hodimlar/features/rahbar/data/walk_route_store.dart';
import 'package:skore_hodimlar/features/rahbar/domain/entities/rahbar_entity.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/pages/rahbar_assign_zone_page.dart';
import 'package:skore_hodimlar/features/rahbar/presentation/rahbar_map_focus.dart';
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

  /// Oxirgi lokatsiya necha daqiqa oldin kelgani (`ago_min`), bo'lmasa null.
  final int? agoMin;

  /// Ish vaqtida signal yo'q (lokatsiya o'chirilgan, telefon o'chgan...);
  /// signal bor bo'lsa `null`.
  final SignalLoss? signal;

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
    this.agoMin,
    this.signal,
  });
}

class _LocationHistoryPoint {
  final double lat;
  final double lng;
  final String vaqt;
  final String? holat;
  final bool? inside;
  final double? distanceM;

  const _LocationHistoryPoint({
    required this.lat,
    required this.lng,
    required this.vaqt,
    this.holat,
    this.inside,
    this.distanceM,
  });
}

class _RahbarRealtimeMapPageState extends State<RahbarRealtimeMapPage> {
  YandexMapController? _controller;
  List<MapObject<dynamic>> _mapObjects = const [];

  /// iOS'da xarita controller'i faqat tab ko'ringanda tayyor bo'ladi. Ungacha
  /// yandex_mapkit har bir yangilanishni eski holatdan hisoblab, obyektlarni
  /// qayta "qo'shadi" — native tomonda eski nusxalar egasiz qolib, filial
  /// almashganda ham xaritada qolib ketadi. Shuning uchun obyektlar
  /// controller tayyor bo'lgandan keyingina beriladi.
  bool _mapReady = false;
  final Map<int, Uint8List> _markerBytesCache = {};
  final Map<int, int> _markerColorCache = {};
  Uint8List? _officeMarkerBytes;
  Uint8List? _defaultUserMarkerBytes;

  /// Tartib raqami -> to'xtash metkasi rasmi.
  final Map<int, Uint8List> _stopMarkerCache = {};

  List<_BranchLocation> _branches = [];
  int _selectedBranchIndex = 0;

  List<_StaffMapItem> _allStaff = [];
  List<_StaffMapItem> _filteredStaff = [];

  double? _myLat;
  double? _myLng;

  String? _historyStaffName;
  int? _historyStaffId;
  bool _loadingHistory = false;

  /// Tarix ko'rsatilayotgan xodim va kun — sana almashtirilganda qayta
  /// yuklash uchun saqlanadi.
  _StaffMapItem? _historyStaff;
  DateTime _historyDate = DateTime.now();

  /// Tanlangan kunda serverda nuqta bo'lmasa, nega bo'shligi (C).
  String? _historyEmptyReason;
  String? _historyCheckIn;

  /// Tanlangan kundagi to'xtash joylari (xodim 10+ daqiqa turgan joylar).
  List<StaffStop> _historyStops = [];

  /// Yuklangandagi to'xtashlar; [_historyStops] shundan + yangi nuqtalardan
  /// jonli hisoblanadi ([liveStops]).
  List<StaffStop> _baseStops = [];

  /// Xodim 10+ daqiqadan beri shu joyda va hali ketmagan (faqat bugun):
  /// boshqa rangli metka, vaqti sanalib turadi. Ketgach — oddiy to'xtash.
  StaffStop? _ongoingStop;
  Uint8List? _ongoingMarker;
  String? _ongoingMarkerLabel;
  DateTime _liveStopsAt = DateTime(2000);
  bool _liveStopsBusy = false;

  /// Xodimning shu kundagi real GPS nuqtalari (vaqt bo'yicha) — hech qanday
  /// tozalash, soddalashtirish yoki yo'lga moslashsiz, aynan kelganidek.
  List<TimedPoint> _historyRoute = [];

  /// Tarix kunidagi lokatsiya uzilishlari: xaritada belgi va ro'yxat.
  List<LocationOutage> _historyOutages = [];

  /// Xaritadagi uzilish belgilari va ularning rasmlari (bir xil tartibda).
  List<OutageMark> _outageMarks = [];
  List<Uint8List> _outageMarkIcons = [];

  static bool _markViolation(OutageMark m) => m.outages.any((o) => o.violation);

  static String _markLabel(OutageMark m) => m.outages.length > 1
      ? '${_hm(m.time)} +${m.outages.length - 1}'
      : _hm(m.time);

  /// Tarixi ochiq xodim hozir harakatlanyapti: marker jonli nuqtalarni
  /// ozgina kechikish bilan o'ynatadi, chiziq esa shu vaqtgacha chiziladi
  /// (oldinga o'tib ketmasin). Qolgani — marker bilan birga o'sadigan
  /// "bosh" ([_historyHead]).
  DateTime? _historyCut;

  /// Chiziladigan qism: [_historyCut] gacha (u bo'lmasa — hammasi).
  List<TimedPoint> get _drawnRoute {
    final cut = _historyCut;
    if (cut == null) return _historyRoute;
    return [
      for (final p in _historyRoute)
        if (!p.time.isAfter(cut)) p,
    ];
  }

  /// Bugungi tarix ochiq va marker xodimning zich (`tail`) nuqtalarini
  /// o'ynatyapti — marker ko'rsatayotgan vaqt.
  DateTime? _historyPlayTime(DateTime now) {
    final id = _historyStaffId;
    if (id == null || !DateUtils.isSameDay(_historyDate, now)) return null;
    if (_playback.sourceOf(id) != 'tail') return null;
    return _playback.playTime(id, now);
  }

  /// Chiziq oxiridan markergacha: [_historyCut] dan keyin o'ynab bo'lingan
  /// nuqtalar va markerning hozirgi joyi.
  MapObject<dynamic>? _historyHead(DateTime now) {
    final id = _historyStaffId;
    final cut = _historyCut;
    if (id == null || cut == null || _loadingHistory) return null;
    final pos = _playback.position(id, now);
    final play = _playback.playTime(id, now);
    if (pos == null || play == null) return null;
    TimedPoint? from;
    final pts = <({double lat, double lng})>[];
    for (final p in _historyRoute) {
      if (!p.time.isAfter(cut)) {
        from = p;
      } else if (!p.time.isAfter(play)) {
        pts.add((lat: p.lat, lng: p.lng));
      }
    }
    if (from == null) return null;
    final line = [(lat: from.lat, lng: from.lng), ...pts, pos];
    final out = <MapObject<dynamic>>[];
    _addRouteLine(out, 'history_head', line);
    return out.firstOrNull;
  }

  /// Bir joyda turish hisob-kitobi keshi (nuqtalar soni o'zgarmasa qayta
  /// hisoblanmaydi).
  final Map<String, (int, DateTime, List<StaffStop>, List<TimedPoint>)>
  _dwellCache = {};

  static const Color _stopColor = Color(0xFF15803D);
  static const Color _ongoingColor = Color(0xFFF97316);
  static const Color _routeColor = Color(0xFF2563EB);
  static const Color _signalLostColor = Color(0xFF94A3B8);
  static const Color _outageColor = Color(0xFFDC2626);

  /// Transportda (mashina, avtobus) yurgan qism — piyodadan farqlanadi.
  static const Color _vehicleRouteColor = Color(0xFF7C3AED);
  final Map<String, String> _stopAddressCache = {};

  /// To'xtash joyidagi tashkilot nomi (`''` — yaqinda tashkilot yo'q).
  final Map<String, String> _stopPlaceCache = {};

  /// Siyrak nuqtalar orasini ko'chalar bo'ylab to'ldiradi (natija kelganda
  /// xarita qayta chiziladi).
  late final StreetRouter _streetRouter = StreetRouter(
    // Yo'lakka moslangan bo'laklar telefonda saqlanadi — ochilgan tarix
    // qayta darhol ochiladi.
    walkStore: FileWalkRouteStore(),
    onUpdate: () {
      if (mounted) _buildMapObjects();
    },
  );

  bool _loading = true;
  bool _isRefreshingLive = false;
  Timer? _autoRefreshTimer;

  /// Markerlarni silliq siljitish: kelgan haqiqiy nuqtalar real tezlikda
  /// qayta o'ynatiladi (sekundiga 5 kadr).
  final LivePlayback _playback = LivePlayback();
  Timer? _animTimer;
  bool _animWasMoving = false;
  MapType _mapType = MapType.map;
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _staffNameToBranchId = {};
  Map<int, int> _staffIdToBranchId = {};
  List<Map<String, dynamic>> _rawFiliallar = [];

  @override
  void initState() {
    super.initState();
    _initBaseMarkerBytes();
    _loadAllBackendData();
    _fetchMyLocation();
    rahbarMapFocusStaff.addListener(_onFocusRequest);
    AppDay.instance.addListener(_onNewDay);
    _animTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _animTick(),
    );

    // Jonli joylashuv va ochiq tarix [_livePollEvery] da bir (xodim ilovasi
    // ham nuqtalarni 10 s lik paket bilan yuboradi — tez-tez so'rash foyda
    // bermaydi, faqat serverni yuklaydi). Taymer soniyalik: vaqt hisobi.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final now = DateTime.now();
        if (now.difference(_lastLivePollAt) >= _livePollEvery) {
          _lastLivePollAt = now;
          _refreshLiveOnly();
          _pollHistoryTail();
        }
        _loadMatchedRoute();
        if (DateTime.now().difference(_liveStopsAt) >=
            const Duration(seconds: 15)) {
          unawaited(_updateLiveStops());
        }
      }
    });
  }

  /// MOBIL_UCHUN_XODIM_XARITASI.md: `/lokatsiya/live` 15–30 s da bir
  /// tavsiya qilingan; xodim nuqtalari 10 s lik paket bilan keladi.
  static const _livePollEvery = Duration(seconds: 10);
  DateTime _lastLivePollAt = DateTime.now();

  /// 00:00 da xarita yangi kunni boshlaydi: kechagi davomat holatlari va
  /// jonli izlar tashlanadi, hammasi qayta yuklanadi. "Bugungi" harakat
  /// tarixi ochiq bo'lsa — yangi kun tarixi (bo'sh) ochiladi; qo'lda
  /// tanlangan boshqa kun tarixi o'zgarmaydi.
  void _onNewDay() {
    if (!mounted) return;
    final day = AppDay.instance;
    final followsToday = day.wasToday(_historyDate);
    _playback.retain(const {});
    _dwellCache.clear();
    final staff = _historyStaff;
    if (staff != null && followsToday) {
      unawaited(_loadStaffHistory(staff, date: day.today));
    } else if (staff == null) {
      _historyDate = day.today;
    }
    unawaited(_loadAllBackendData(silent: true));
  }

  @override
  void dispose() {
    AppDay.instance.removeListener(_onNewDay);
    rahbarMapFocusStaff.removeListener(_onFocusRequest);
    _autoRefreshTimer?.cancel();
    _animTimer?.cancel();
    _streetRouter.dispose();
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
      _feedLive(liveLocations);

      // Build staff name and ID -> branch ID mapping from Filial Report (getFilial)
      final rawFiliallar = (filialReport['filiallar'] as List?) ?? const [];
      _rawFiliallar = rawFiliallar
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      debugPrint(
        '🏢 [XARITA] filiallar (GET /rahbar/lokatsiya): ${rawLocations.length} ta, '
        'jonli: ${liveLocations.length} ta',
      );
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
        int id = _parseInt(loc['id'] ?? loc['filial_id'] ?? loc['location_id']);

        if (id == 0) {
          final nomLower = name.trim().toLowerCase();
          for (final f in _rawFiliallar) {
            final fNom = (f['nom'] ?? f['name'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (fNom == nomLower ||
                fNom.contains(nomLower) ||
                nomLower.contains(fNom)) {
              final foundId = _parseInt(f['id'] ?? f['filial_id']);
              if (foundId > 0) {
                id = foundId;
                break;
              }
            }
          }
        }
        if (id == 0) {
          // Large offset so this synthetic id can never collide with a real
          // backend branch id (which are always small sequential DB ids).
          id = 1000000 + parsedBranches.length;
        }

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

      if (parsedBranches.isEmpty) {
        for (final f in _rawFiliallar) {
          final lat = _parseDouble(f['lat'] ?? f['latitude']);
          final lng = _parseDouble(f['lng'] ?? f['longitude']);
          final radius = _parseDouble(f['radius'] ?? f['radius_meter'], 100.0);
          final nom = (f['nom'] ?? f['name'] ?? '').toString().trim();
          final id = _parseInt(f['id'] ?? f['filial_id']);
          final isUn = f['is_unassigned'] == true;
          if (!isUn && lat != 0.0 && lng != 0.0) {
            parsedBranches.add(
              _BranchLocation(
                id: id,
                name: nom,
                lat: lat,
                lng: lng,
                radius: radius.clamp(20.0, 1000.0),
              ),
            );
          }
        }
      }

      parsedBranches.sort((a, b) => a.id.compareTo(b.id));

      final Map<String, int> staffNameToBranch = {};
      final Map<int, int> staffIdToBranch = {};

      for (final f in _rawFiliallar) {
        final fMap = Map<String, dynamic>.from(f as Map);
        final fNom = (fMap['nom'] ?? fMap['name'] ?? '').toString().trim();
        final fId = _parseInt(
          fMap['id'] ?? fMap['filial_id'] ?? fMap['location_id'],
        );
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
              final bName = b.name.toLowerCase();
              if (bName == nomLower ||
                  bName.contains(nomLower) ||
                  nomLower.contains(bName)) {
                targetBranchId = b.id;
                break;
              }
            }
          }
          // 2. Fallback to fId only if name matching did not find branch
          if (targetBranchId == null && fId > 0) {
            for (final b in parsedBranches) {
              if (b.id == fId) {
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
              final stId = _parseInt(stMap['id']);
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
      _branches = parsedBranches;

      final List<_StaffMapItem> parsedStaff = [];

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
            filialId: targetBranchId,
            filialName: staffBranch?.name ?? s.filialName,
            attendanceStatus: liveAtt.isNotEmpty
                ? liveAtt
                : (isInside ? 'ishda' : (hasCheckIn ? 'ketgan' : 'kelmagan')),
            holat: calculatedHolat,
            distanceMeters: distanceMeters,
            signal: SignalLoss.fromLive(liveItem),
            lastUpdated: lastUpdatedDisplay,
            agoMin: agoMin,
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
              filialName: (item['filial_name'] ?? item['branch_name'])
                  ?.toString(),
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
                filialId: liveTargetBranchId,
                filialName: liveBranch?.name,
                attendanceStatus: lAtt,
                holat: isInsideReal
                    ? 'hududda'
                    : (lHolat.isNotEmpty ? lHolat : 'tashqarida'),
                distanceMeters: distanceMeters,
                signal: SignalLoss.fromLive(item),
                lastUpdated: _lastUpdatedText(item),
                agoMin: item['ago_min'] != null
                    ? _parseInt(item['ago_min'])
                    : null,
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
      _tryFocusPending();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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

  int _getStaffBranchId({
    required int? filialId,
    required String? filialName,
    required String staffName,
    int? staffId,
    required double lat,
    required double lng,
  }) {
    if (_branches.isEmpty) return 0;

    // 1. Direct ID match from Filial Report (getFilial)
    if (staffId != null &&
        staffId > 0 &&
        _staffIdToBranchId.containsKey(staffId)) {
      final bId = _staffIdToBranchId[staffId]!;
      return bId;
    }

    // 2. Direct Name match from Filial Report (getFilial)
    final staffNameLower = staffName.trim().toLowerCase();
    if (_staffNameToBranchId.containsKey(staffNameLower)) {
      return _staffNameToBranchId[staffNameLower]!;
    }
    for (final entry in _staffNameToBranchId.entries) {
      if (_isSameStaff(staffNameLower, entry.key)) {
        return entry.value;
      }
    }

    // 3. Explicit filial name from attendance record
    if (filialName != null && filialName.trim().isNotEmpty) {
      final sName = filialName.trim().toLowerCase();
      if (sName.contains('biriktirilmagan') ||
          sName.contains('unassigned') ||
          sName == 'null') {
        return 0;
      }
      for (final b in _branches) {
        final bName = b.name.trim().toLowerCase();
        if (bName == sName || bName.contains(sName) || sName.contains(bName)) {
          return b.id;
        }
      }
    }

    // 4. Explicit filial ID from attendance record
    if (filialId != null && filialId > 0) {
      for (final b in _branches) {
        if (b.id == filialId) return filialId;
      }
    }

    // 5. Default: if not matched to any branch, return 0 (unassigned). NEVER default to _branches.first.id!
    return 0;
  }

  bool _isStaffInCurrentBranch(_StaffMapItem s, _BranchLocation branch) {
    if (s.filialId != null && s.filialId! > 0 && branch.id > 0) {
      return s.filialId == branch.id;
    }
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

  Future<void> _onBranchSelected(int index) async {
    if (index < 0 || index >= _branches.length) return;
    _selectedBranchIndex = index;
    _filterStaff(_searchController.text);
    _buildMapObjects();
    _moveCameraToBranch();

    await _generateMarkerBytes();
    if (mounted) {
      _filterStaff(_searchController.text);
      _buildMapObjects();
    }

    if (index >= 0 && index < _branches.length) {
      final b = _branches[index];
      final staffInThisBranch = _allStaff
          .where((s) => _isStaffInCurrentBranch(s, b))
          .toList();

      debugPrint(
        '════════════════════════════════════════════════════════════════',
      );
      debugPrint('🏢 [XARITA - FILIAL BOSILDI]: ${b.name} (ID: ${b.id})');
      debugPrint(
        '📍 Koordinatalar: lat=${b.lat}, lng=${b.lng}, radius=${b.radius}m',
      );
      debugPrint(
        '👥 Biriktirilgan xodimlar: ${staffInThisBranch.length} nafar',
      );
      debugPrint(
        '────────────────────────────────────────────────────────────────',
      );
      for (int i = 0; i < staffInThisBranch.length; i++) {
        final s = staffInThisBranch[i];
        debugPrint(
          ' #${i + 1} ${s.name} (ID: ${s.id}) | Bo\'lim: ${s.bolim} | Lavozim: ${s.lavozim}\n'
          '     Kelish: ${s.checkIn} | Ketish: ${s.checkOut} | Status: ${s.status} | Davomat: ${s.attendanceStatus}\n'
          '     Holat: ${s.holat} | Masofa: ${s.distanceMeters.toStringAsFixed(1)}m | GPS: lat=${s.lat}, lng=${s.lng}\n'
          '     Oxirgi vaqt: ${s.lastUpdated ?? "--"}',
        );
      }
      for (final rf in _rawFiliallar) {
        final rNom = (rf['nom'] ?? rf['name'] ?? '').toString().toLowerCase();
        final rId = _parseInt(rf['id'] ?? rf['filial_id'] ?? rf['location_id']);
        if (rId == b.id ||
            rNom == b.name.toLowerCase() ||
            (rNom.isNotEmpty && b.name.toLowerCase() == rNom)) {
          debugPrint('📦 [BACKEND RAW DATA]: $rf');
        }
      }
      debugPrint(
        '════════════════════════════════════════════════════════════════',
      );
    }
  }

  Future<void> _initBaseMarkerBytes() async {
    _officeMarkerBytes ??= await AvatarMarkerHelper.generateOfficePinBytes();
    _defaultUserMarkerBytes ??=
        await AvatarMarkerHelper.generateDefaultPinBytes();
    if (mounted) setState(() {});
  }

  Future<void> _generateMarkerBytes() async {
    await _initBaseMarkerBytes();
    final staffList = _filteredStaff.isNotEmpty ? _filteredStaff : _allStaff;
    for (final staff in staffList) {
      Color pinColor;
      final att = staff.attendanceStatus.toLowerCase();
      if (staff.signal != null) {
        pinColor = _signalLostColor; // Kulrang (signal yo'q)
      } else if (staff.isInside) {
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
        pinColor = const Color(0xFF6B7280);
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
  /// "13:21:05 (7 s oldin)" — real vaqt uchun soniya (`ago_sec`) ustun.
  String? _lastUpdatedText(Map<String, dynamic> item) {
    final t =
        item['time']?.toString() ??
        item['updated_at']?.toString() ??
        item['recorded_at']?.toString() ??
        item['vaqt']?.toString();
    if (t == null) return null;
    final sec = item['ago_sec'] != null ? _parseInt(item['ago_sec']) : null;
    final min = item['ago_min'] != null ? _parseInt(item['ago_min']) : null;
    if (sec != null && sec > 0 && sec < 60) {
      return context.tr('rahbar_time_ago_sec', {'time': t, 'sec': '$sec'});
    }
    final m = min ?? (sec != null ? sec ~/ 60 : null);
    if (m != null && m > 0) {
      return context.tr('rahbar_time_ago', {'time': t, 'min': '$m'});
    }
    return t;
  }

  /// Marshrut chizig'i (oq hoshiyali to'liq chiziq).
  void _addRouteLine(
    List<MapObject<dynamic>> objects,
    String id,
    List<({double lat, double lng})> points, {
    bool dashed = false,
    Color? color,
  }) {
    if (points.length < 2) return;
    final stroke = color ?? _routeColor;
    objects.add(
      PolylineMapObject(
        mapId: MapObjectId(id),
        polyline: Polyline(
          points: [
            for (final p in points) Point(latitude: p.lat, longitude: p.lng),
          ],
        ),
        // Punktir — "bu oraliqda ma'lumot yo'q" (backend `uzilish`).
        dashLength: dashed ? 8 : 0,
        gapLength: dashed ? 6 : 0,
        strokeColor: dashed ? stroke.withValues(alpha: 0.6) : stroke,
        strokeWidth: 4,
        outlineColor: Colors.white,
        outlineWidth: 1,
        turnRadius: 0,
        zIndex: 5,
      ),
    );
  }

  /// Harakat tarixi chiziqlari (hammasi to'liq chiziq, punktir yo'q):
  /// - backend yo'lga moslagan bo'laklar — o'zicha;
  /// - backend moslay olmagan yoki hali hisoblamagan oraliqlardagi real
  ///   nuqtalar — bir joyda turish yig'ilgan, orasi eng yaqin ko'chalar
  ///   bo'ylab;
  /// - nuqta kelmagan uzilish — ikki uchi orasi ko'chalar bo'ylab, bo'lmasa
  ///   backend bergan chiziq.
  ///
  /// Ko'cha yo'li hali tayyor bo'lmagan oraliqlar so'rov navbatiga
  /// qo'yiladi ([StreetRouter.whenIdle] bilan kutish mumkin).
  /// Backend yo'li shu oraliqdagi real nuqtalar zanjiridan ancha uzun —
  /// piyodalar o'tish joyiga aylanib borgan / qaytgan (xodim esa to'g'ri,
  /// masalan yer osti o'tish joyidan o'tgan).
  bool _isDetour(RouteSegment seg) {
    final raw = [
      for (final p in _historyRoute)
        if (!p.time.isBefore(seg.from) && !p.time.isAfter(seg.to)) p,
    ];
    if (raw.length < 2) return false;
    double len(List<({double lat, double lng})> l) {
      var t = 0.0;
      for (var i = 1; i < l.length; i++) {
        t += distanceMeters(l[i - 1].lat, l[i - 1].lng, l[i].lat, l[i].lng);
      }
      return t;
    }

    // Real nuqtalarning GPS zigzagi olib tashlangan zanjiri bilan
    // solishtiriladi (aks holda zigzagga moslangan yo'l ham "to'g'ri" chiqadi).
    final rawLen = len([
      for (final p in simplifyExcursions(raw)) (lat: p.lat, lng: p.lng),
    ]);
    return len(seg.points) > rawLen * 1.3 + 30;
  }

  /// Tarix chizig'i tezlikka qarab ([buildSpeedTrack]): bir joyda turish
  /// bitta nuqtaga yig'ilgan GPS izi + transport qismlari uchun backend
  /// `yol` bo'laklari. Piyoda qismlar yo'laklar bo'ylab, silliq
  /// ([StreetRouter.walkPath]).
  List<TrackPiece> _speedTrackPieces() {
    final dayKey = _historyDate.toIso8601String().substring(0, 10);
    final (_, path) = _dwellsFor(
      'speed_${_historyStaffId}_$dayKey',
      _drawnRoute,
    );
    final zone = _branches
        .where((b) => b.id == _historyStaff?.filialId && b.lat != 0.0)
        .firstOrNull;
    final pieces =
        buildSpeedTrack(
          path,
          matched: _matchedRoute ?? const [],
          inOffice: zone == null
              ? null
              : (p) =>
                    distanceMeters(p.lat, p.lng, zone.lat, zone.lng) <=
                    zone.radius + 30,
        ).map((p) {
          if (p.kind != TrackPieceKind.walk || p.samples.length < 2) return p;
          return p.withPoints(_streetRouter.walkPath(p.samples));
        }).toList();
    // Bir yo'ldan borib-qaytgan piyoda qismlar bitta chiziq bo'lib
    // chiziladi (yonma-yon ikki parallel chiziq emas).
    final walkIdx = [
      for (var i = 0; i < pieces.length; i++)
        if (pieces[i].kind == TrackPieceKind.walk) i,
    ];
    final merged = _streetRouter.mergeWalks([
      for (final i in walkIdx) pieces[i].points,
    ]);
    for (var k = 0; k < walkIdx.length; k++) {
      pieces[walkIdx[k]] = pieces[walkIdx[k]].withPoints(merged[k]);
    }
    final shown = dropIsolatedStubs(pieces);
    if (kDebugMode) {
      final count = <TrackPieceKind, int>{};
      for (final p in pieces) {
        count[p.kind] = (count[p.kind] ?? 0) + 1;
      }
      debugPrint(
        '🛣️ [MARSHRUT] tezlik bo\'yicha: ${path.length} nuqta -> '
        '${count.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}'
        ', dumcha=${pieces.length - shown.length}',
      );
    }
    return shown;
  }

  List<List<({double lat, double lng})>> _historyLines() {
    final pieces =
        <
          ({
            DateTime time,
            DateTime end,
            int order,
            List<({double lat, double lng})> points,
          })
        >[];
    var seq = 0;
    void addPiece(
      DateTime time,
      List<({double lat, double lng})> pts, [
      DateTime? end,
    ]) {
      if (pts.isEmpty) return;
      pieces.add((time: time, end: end ?? time, order: seq++, points: pts));
    }

    final dayKey = _historyDate.toIso8601String().substring(0, 10);
    final baseKey = 'history_${_historyStaffId}_$dayKey';
    final route = _drawnRoute;
    var rawRuns = [route];
    final matched = _matchedRoute;
    if (matched != null && matched.isNotEmpty) {
      final (:runs, :emptyGaps) = unmatchedRawRuns(matched, route);
      for (var i = 0; i < matched.length; i++) {
        final seg = matched[i];
        if (seg.kind == RouteSegmentKind.road && !_isDetour(seg)) {
          addPiece(seg.from, seg.points, seg.to);
          continue;
        }
        if (seg.kind == RouteSegmentKind.gap && !emptyGaps.contains(i)) {
          continue;
        }
        // Bo'sh uzilishning ikki uchi ham real nuqtalar ketma-ketligi ichida
        // bo'lsa — u oraliq real nuqtalar bilan chiziladi, ikkinchi marta
        // (ustma-ust, orqaga qaytgan chiziq bilan) chizilmaydi.
        if (seg.kind == RouteSegmentKind.gap &&
            runs.any(
              (r) =>
                  r.isNotEmpty &&
                  !r.first.time.isAfter(seg.from) &&
                  !r.last.time.isBefore(seg.to),
            )) {
          continue;
        }
        // `real` (moslanmagan GPS) va bo'sh uzilish ham faqat ko'chalar /
        // yo'laklar bo'ylab — binolar ustidan hech qachon to'g'ri chiziq yo'q.
        final pts = switch (seg.kind) {
          RouteSegmentKind.gap => [seg.points.first, seg.points.last],
          // Aylanma yo'l: o'rniga shu oraliqdagi real nuqtalar.
          RouteSegmentKind.road => [
            for (final p in _historyRoute)
              if (!p.time.isBefore(seg.from) && !p.time.isAfter(seg.to))
                (lat: p.lat, lng: p.lng),
          ],
          RouteSegmentKind.real => seg.points,
        };
        final span = seg.to.difference(seg.from).inMilliseconds;
        for (final line in _streetRouter.snap([
          for (var k = 0; k < pts.length; k++)
            (
              lat: pts[k].lat,
              lng: pts[k].lng,
              time: seg.from.add(
                Duration(
                  milliseconds: pts.length < 2
                      ? 0
                      : span * k ~/ (pts.length - 1),
                ),
              ),
            ),
        ])) {
          addPiece(seg.from, line, seg.to);
        }
      }
      rawRuns = runs;
    }
    for (final raw in rawRuns) {
      if (raw.length < 2) continue;
      final key = '${baseKey}_${raw.first.time.millisecondsSinceEpoch}';
      final (_, path) = _dwellsFor(key, raw);
      final segments = splitTrackAtGaps(path);
      for (var i = 0; i < segments.length; i++) {
        // Uzilish oralig'i ham ko'chalar bo'ylab (binolar ustidan emas).
        if (i > 0) {
          for (final line in _streetRouter.snap([
            segments[i - 1].last,
            segments[i].first,
          ])) {
            addPiece(segments[i - 1].last.time, line, segments[i].first.time);
          }
        }
        for (final line in _streetRouter.snap(segments[i])) {
          addPiece(segments[i].first.time, line, segments[i].last.time);
        }
      }
    }
    pieces.sort((a, b) {
      final c = a.time.compareTo(b.time);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    // Bo'laklar orasida uzilish bo'lmasin: keyingi bo'lak boshi uzoq bo'lsa
    // — oraliq o'sha qoidalar bilan (ko'cha yo'li / to'g'ri o'tish / binoni
    // chetlab) ulanadi.
    final out = <List<({double lat, double lng})>>[];
    for (var k = 0; k < pieces.length; k++) {
      if (k > 0) {
        final p = pieces[k - 1], q = pieces[k];
        final e = p.points.last, s0 = q.points.first;
        // Faqat vaqt bo'yicha ketma-ket bo'laklar ulanadi (ustma-ust
        // tushganlarini ulash orqaga qaytgan ortiqcha chiziq beradi).
        final sequential = !q.time.isBefore(
          p.end.subtract(const Duration(seconds: 1)),
        );
        if (sequential && distanceMeters(e.lat, e.lng, s0.lat, s0.lng) > 15) {
          out.addAll(
            _streetRouter.snap([
              (lat: e.lat, lng: e.lng, time: p.time),
              (
                lat: s0.lat,
                lng: s0.lng,
                time: q.time.isAfter(p.time)
                    ? q.time
                    : p.time.add(const Duration(seconds: 1)),
              ),
            ]),
          );
        }
      }
      out.add(pieces[k].points);
    }
    return out;
  }

  /// Tarix ochilganda: backend marshruti va hamma ko'cha yo'llari tayyor
  /// bo'lguncha kutadi (ko'pi bilan [_prepareTimeout]), keyin bir marta
  /// to'liq chiziladi.
  static const _prepareTimeout = Duration(seconds: 20);

  /// Server rejimida piyoda yo'laklarni kutish chegarasi.
  static const _walkPrepareTimeout = Duration(seconds: 6);

  Future<void> _prepareHistoryLines() async {
    final sw = Stopwatch()..start();
    try {
      await _loadMatchedRoute(
        force: true,
        redraw: false,
      ).timeout(_prepareTimeout);
    } catch (_) {}
    debugPrint(
      '⏱️ [TARIX VAQT]   yo\'lga moslangan marshrut: ${sw.elapsedMilliseconds} ms',
    );
    if (!mounted) return;
    // Backend marshrutni o'zi hisoblagan — binolar va ko'cha yo'llari
    // telefonda yig'ilmaydi.
    if (_serverRoute) {
      // Piyoda qismlar uchun yo'lak so'rovlari — birinchi chizishda chiziq
      // tayyor bo'lsin (ulgurmasa silliq GPS izi, keyin yangilanadi).
      // Avval saqlangan natijalar: ular uchun so'rov ketmaydi.
      try {
        await _streetRouter.ready.timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!mounted) return;
      _speedTrackPieces();
      if (_streetRouter.isBusy) {
        try {
          await _streetRouter.whenIdle().timeout(_walkPrepareTimeout);
        } catch (_) {}
      }
      debugPrint('🛣️ [MARSHRUT] server rejimi: ${sw.elapsedMilliseconds} ms');
      return;
    }
    // Chiziladigan narsa yo'q (0–1 nuqta) — binolarni kutish behuda.
    if (_historyRoute.length < 2 && (_matchedRoute?.isEmpty ?? true)) {
      debugPrint('🛣️ [MARSHRUT] chiziq yo\'q: ${sw.elapsedMilliseconds} ms');
      return;
    }
    // Bino konturlari — yo'l tanlashdan oldin (yagona taqiq: bino ustidan
    // o'tish).
    final buildingsReady = _streetRouter.buildings.ensure(
      _historyPointsForBuildings().toList(),
    );
    try {
      await buildingsReady.timeout(const Duration(seconds: 12));
      debugPrint('⏱️ [TARIX VAQT]   binolar: ${sw.elapsedMilliseconds} ms');
    } catch (_) {
      debugPrint(
        '⏱️ [TARIX VAQT]   binolar 12 s da ulgurmadi: ${sw.elapsedMilliseconds} ms',
      );
      // Kech yuklansa ham — tayyor bo'lgach qayta chiziladi.
      unawaited(
        buildingsReady.then((_) {
          if (mounted && _historyStaffId != null) _buildMapObjects();
        }),
      );
    }
    if (!mounted) return;
    // Har bosqich natijasi yangi so'rovlar tug'diradi (masalan, keraksiz
    // nuqta tashlangach yangi qo'shnilar orasidagi yo'l) — so'rov qolmaguncha.
    for (var round = 0; round < 6; round++) {
      _historyLines();
      debugPrint(
        '⏱️ [TARIX VAQT]   ko\'cha yo\'li $round-davra: '
        '${_streetRouter.pendingCount} so\'rov, ${sw.elapsedMilliseconds} ms',
      );
      if (!_streetRouter.isBusy) break;
      final left = _prepareTimeout - sw.elapsed;
      if (left <= Duration.zero) break;
      try {
        await _streetRouter.whenIdle().timeout(left);
      } catch (_) {
        break;
      }
      if (!mounted) return;
    }
    debugPrint('🛣️ [MARSHRUT] tayyor: ${sw.elapsedMilliseconds} ms');
  }

  /// Backenddan yo'lga moslangan marshrut (bugun bo'lsa ~1 daqiqada bir
  /// yangilanadi). Backend qo'llamasa — `null`, real nuqtalar chiziladi.
  List<RouteSegment>? _matchedRoute;

  /// Backend marshrutni o'zi to'liq hisoblagan ([MatchedRoute.serverAuthoritative]):
  /// bo'laklar o'zgartirilmay chiziladi, Yandex/Overpass ishlatilmaydi.
  bool _serverRoute = !_phoneRouting;
  String? _matchedStamp;

  /// VAQTINCHA (tekshiruv): `true` — xaritada FAQAT backend yuborgan
  /// bo'laklar, hech qanday telefon to'ldirishi (xom GPS, Yandex, Overpass)
  /// yo'q. Backend nima yuborayotganini toza ko'rish uchun. Release'da `false`.
  static const _pureBackendRoute = false;

  /// Telefonda yo'l yig'ish (Yandex ko'cha yo'llari + Overpass binolari)
  /// o'chirilgan: tarix doim backend bo'laklari + backend qamramagan xom GPS
  /// bilan chiziladi — tez (~1 s) va hamma telefonda bir xil.
  static const _phoneRouting = false;
  DateTime? _matchedFetchedAt;
  bool _matchedBusy = false;

  Future<void> _loadMatchedRoute({
    bool force = false,
    bool redraw = true,
  }) async {
    final id = _historyStaffId;
    if (id == null || _matchedBusy) return;
    final day = _historyDate;
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(day, now);
    final last = _matchedFetchedAt;
    if (!force &&
        last != null &&
        (!isToday || now.difference(last) < const Duration(seconds: 60))) {
      return;
    }
    _matchedBusy = true;
    _matchedFetchedAt = now;
    try {
      final route = await sl<RahbarRemoteDataSource>().getStaffMatchedRoute(
        xodimId: id,
        sana: day.toIso8601String().substring(0, 10),
      );
      if (!mounted || _historyStaffId != id || _historyDate != day) return;
      final stamp = route?.hisoblanganVaqt == null
          ? null
          : '${route!.versiya}|${route.hisoblanganVaqt}';
      final unchanged = stamp != null && stamp == _matchedStamp;
      debugPrint(
        '🛣️ [MARSHRUT] yo\'lga moslangan: ${route?.segments.length ?? '—'} '
        'bo\'lak, versiya=${route?.versiya}, '
        'rejim=${(route?.serverAuthoritative ?? false) ? 'server' : 'telefon'}'
        '${unchanged ? ' (o\'zgarmagan)' : ''}',
      );
      _matchedRoute = route?.segments;
      _serverRoute =
          !_phoneRouting ||
          _pureBackendRoute ||
          (route?.serverAuthoritative ?? false);
      _matchedStamp = stamp;
      if (redraw && !unchanged) _buildMapObjects();
    } catch (e) {
      debugPrint('⚠️ [MARSHRUT] yo\'lga moslangan marshrut olinmadi: $e');
    } finally {
      _matchedBusy = false;
    }
  }

  (List<StaffStop>, List<TimedPoint>) _dwellsFor(
    String key,
    List<TimedPoint> pts,
  ) {
    final cached = _dwellCache[key];
    final now = DateTime.now();
    if (cached != null && cached.$1 <= pts.length) {
      if (cached.$1 == pts.length) return (cached.$3, cached.$4);
      // Har soniyada butun kun qayta hisoblanmaydi: yangi nuqtalar oxiriga
      // qo'shiladi, to'liq hisob 10 soniyada bir.
      if (now.difference(cached.$2) < const Duration(seconds: 10)) {
        final last = cached.$4.isEmpty ? null : cached.$4.last.time;
        return (
          cached.$3,
          [
            ...cached.$4,
            for (final p in pts.skip(cached.$1))
              if (last == null || p.time.isAfter(last)) p,
          ],
        );
      }
    }
    final dwells = detectDwells(pts);
    final path = collapseDwells(pts, dwells);
    _dwellCache[key] = (pts.length, now, dwells, path);
    return (dwells, path);
  }

  Iterable<({double lat, double lng})> _historyPointsForBuildings() sync* {
    for (final p in _historyRoute) {
      yield (lat: p.lat, lng: p.lng);
    }
    for (final seg in _matchedRoute ?? const <RouteSegment>[]) {
      yield* seg.points;
    }
  }

  /// Xodimning O'Z filiali zonasi ichidagi to'xtash ko'rsatilmaydi.
  bool _isOwnZoneStop(StaffStop st) {
    final staff = _historyStaff;
    if (staff == null) return false;
    final zone = _branches
        .where((b) => b.id == staff.filialId && b.lat != 0.0)
        .firstOrNull;
    if (zone == null) return false;
    return distanceMeters(zone.lat, zone.lng, st.lat, st.lng) <= zone.radius;
  }

  static String _elapsedLabel(Duration d) {
    final m = d.inMinutes;
    return m < 60 ? "$m'" : '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// To'xtashlar va "hali shu yerda" metkasini yangi nuqtalar bo'yicha
  /// yangilaydi (har 15 soniyada; metkadagi vaqt ham shu bilan sanaladi).
  Future<void> _updateLiveStops({bool redraw = true}) async {
    _liveStopsAt = DateTime.now();
    if (_liveStopsBusy || _historyStaffId == null) return;
    if (redraw && _historyRoute.isNotEmpty && !_serverRoute) {
      // Xodim yangi hududga o'tgan bo'lsa — u yerning binolari ham.
      final b = _streetRouter.buildings;
      final tail = _historyRoute.length > 120
          ? _historyRoute.sublist(_historyRoute.length - 120)
          : _historyRoute;
      unawaited(b.ensure([for (final p in tail) (lat: p.lat, lng: p.lng)]));
    }
    _liveStopsBusy = true;
    try {
      final id = _historyStaffId;
      final now = DateTime.now();
      final r = liveStops(
        _baseStops,
        _historyRoute,
        now,
        today: DateUtils.isSameDay(_historyDate, now),
        hidden: _isOwnZoneStop,
      );
      final dpr = MediaQuery.of(context).devicePixelRatio;
      for (var i = 1; i <= r.stops.length; i++) {
        _stopMarkerCache[i] ??= await AvatarMarkerHelper.generateNumberPinBytes(
          label: '$i',
          color: _stopColor,
          pixelRatio: dpr,
        );
      }
      final ongoing = r.ongoing;
      if (ongoing != null) {
        final label = _elapsedLabel(now.difference(ongoing.from));
        if (label != _ongoingMarkerLabel || _ongoingMarker == null) {
          _ongoingMarker = await AvatarMarkerHelper.generateNumberPinBytes(
            label: label,
            color: _ongoingColor,
            pixelRatio: dpr,
          );
          _ongoingMarkerLabel = label;
        }
      }
      if (!mounted || _historyStaffId != id) return;
      final changed =
          r.stops.length != _historyStops.length ||
          (r.stops.isNotEmpty && r.stops.last.to != _historyStops.last.to) ||
          (ongoing == null) != (_ongoingStop == null) ||
          ongoing != null;
      _historyStops = r.stops;
      _ongoingStop = ongoing;
      if (redraw && changed && !_loadingHistory) {
        setState(() {});
        _buildMapObjects();
      }
    } catch (_) {
    } finally {
      _liveStopsBusy = false;
    }
  }

  bool _historyTailBusy = false;

  /// Bugungi tarix ochiq bo'lsa, serverdan oxirgi nuqtadan keyingi **real**
  /// nuqtalar (`?from=`) olinib, chiziq oxiriga qo'shiladi.
  Future<void> _pollHistoryTail() async {
    final id = _historyStaffId;
    final day = _historyDate;
    if (_historyTailBusy ||
        _loadingHistory ||
        id == null ||
        !DateUtils.isSameDay(day, DateTime.now())) {
      return;
    }
    _historyTailBusy = true;
    try {
      final last = _historyRoute.isEmpty ? null : _historyRoute.last.time;
      final data = await sl<RahbarRemoteDataSource>().getStaffLocationHistory(
        xodimId: id,
        sana: day.toIso8601String().substring(0, 10),
        from: last == null ? null : isoWithOffset(last),
      );
      final raw = data['nuqtalar'] ?? data['data'] ?? data['points'];
      if (raw is! List || !mounted || _historyStaffId != id) return;
      final fresh = <TimedPoint>[
        for (final m in raw.whereType<Map<dynamic, dynamic>>())
          if (parseStopTime(m['recorded_at'] ?? m['vaqt'], day) case final t?
              when (last == null || t.isAfter(last)) &&
                  _parseDouble(m['accuracy']) <= trackDrawAccuracy &&
                  m['shubhali'] != true)
            (
              lat: _parseDouble(m['lat'] ?? m['latitude']),
              lng: _parseDouble(m['lng'] ?? m['longitude']),
              time: t,
            ),
      ]..removeWhere((p) => p.lat == 0.0 || p.lng == 0.0);
      if (fresh.isEmpty) return;
      fresh.sort((a, b) => a.time.compareTo(b.time));
      // Oxirgi nuqtaga nisbatan bir xil tozalash (sakrash/titrash).
      final tail = _historyRoute.isEmpty
          ? cleanTrack(fresh)
          : cleanTrack([_historyRoute.last, ...fresh]).skip(1).toList();
      if (tail.isEmpty) return;
      // Oldingi oxirgi nuqta endi "igna" ekani bilinishi mumkin — chegara
      // atrofi qayta tekshiriladi.
      final keep = _historyRoute.length > 2
          ? _historyRoute.sublist(0, _historyRoute.length - 2)
          : const <TimedPoint>[];
      // Sakrab ketgan iz qaytgandagina bilinadi — butun iz qayta
      // tekshiriladi (qidiruv 5 daqiqalik oyna bilan cheklangan).
      _historyRoute = removeExcursions([
        ...keep,
        ...removeSpikes([..._historyRoute.skip(keep.length), ...tail]),
      ]);
      // Tarixi ochiq xodim — zich (soniyama-soniya) nuqtalar bilan.
      _playback.push(id, tail, source: 'tail', now: DateTime.now());
      _buildMapObjects();
    } catch (_) {
    } finally {
      _historyTailBusy = false;
    }
  }

  Future<void> _refreshLiveOnly() async {
    if (_isRefreshingLive || !mounted) return;
    _isRefreshingLive = true;
    try {
      final remoteDs = sl<RahbarRemoteDataSource>();
      final liveLocations = await remoteDs.getLiveLocations();
      debugPrint('📡 [LIVE] ${liveLocations.length} ta xodim');
      if (!mounted || liveLocations.isEmpty) return;
      _feedLive(liveLocations);

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
            signal: SignalLoss.fromLive(liveItem),
            lastUpdated: _lastUpdatedText(liveItem),
            agoMin: liveItem['ago_min'] != null
                ? _parseInt(liveItem['ago_min'])
                : null,
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
              filialName: (item['filial_name'] ?? item['branch_name'])
                  ?.toString(),
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
                filialId: liveTargetBranchId,
                filialName: liveBranch?.name,
                attendanceStatus: lAtt,
                holat: isInside
                    ? 'hududda'
                    : (lHolat.isNotEmpty ? lHolat : 'tashqarida'),
                distanceMeters: distanceMeters,
                signal: SignalLoss.fromLive(item),
                lastUpdated: _lastUpdatedText(item),
                agoMin: item['ago_min'] != null
                    ? _parseInt(item['ago_min'])
                    : null,
              ),
            );
          }
        }
      }

      if (mounted) {
        await _generateMarkerBytes();
        if (mounted) {
          _filterStaff(_searchController.text);
          // Xaritadagi markerlar (joy, rang) o'zgarmagan bo'lsa, obyektlar
          // qayta yaratilmaydi — xarita o'sha ro'yxatni oladi va hech narsa
          // qayta chizilmaydi. Ro'yxatdagi "oxirgi vaqt"/masofa matnlari
          // uchun sahifa baribir yangilanadi.
          final signature = _liveMarkersSignature();
          if (signature != _lastLiveMarkersSignature) {
            _lastLiveMarkersSignature = signature;
            _buildMapObjects();
          } else {
            setState(() {});
          }
        }
      }
    } catch (_) {
    } finally {
      _isRefreshingLive = false;
    }
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

  /// Jonli so'rovdan keyin xaritadagi xodim markerlari o'zgardimi —
  /// faqat [_buildMapObjects] ishlatadigan maydonlar: joy va marker rangi.
  String? _lastLiveMarkersSignature;

  String _liveMarkersSignature() {
    final b = StringBuffer();
    for (final s in _filteredStaff) {
      b
        ..write(s.id)
        ..write(':')
        ..write(s.lat)
        ..write(',')
        ..write(s.lng)
        ..write(',')
        ..write(_markerColorCache[s.id])
        ..write(';');
    }
    return b.toString();
  }

  void _buildMapObjects() {
    final List<MapObject<dynamic>> newObjects = [];

    final currentBranch =
        (_branches.isNotEmpty &&
            _selectedBranchIndex >= 0 &&
            _selectedBranchIndex < _branches.length)
        ? _branches[_selectedBranchIndex]
        : (_branches.isNotEmpty ? _branches.first : null);

    // 1. Draw ONLY the selected branch geofence zone & center dot!
    if (currentBranch != null &&
        currentBranch.lat != 0.0 &&
        currentBranch.lng != 0.0) {
      newObjects.add(
        CircleMapObject(
          mapId: const MapObjectId('current_selected_branch_zone'),
          circle: Circle(
            center: Point(
              latitude: currentBranch.lat,
              longitude: currentBranch.lng,
            ),
            radius: currentBranch.radius,
          ),
          strokeColor: context.colors.primary,
          strokeWidth: 2.5,
          fillColor: context.colors.primary.withValues(alpha: 0.18),
          zIndex: 2.0,
        ),
      );

      if (_officeMarkerBytes != null) {
        newObjects.add(
          PlacemarkMapObject(
            mapId: const MapObjectId('current_selected_branch_center_dot'),
            point: Point(
              latitude: currentBranch.lat,
              longitude: currentBranch.lng,
            ),
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(
                image: BitmapDescriptor.fromBytes(_officeMarkerBytes!),
                scale: 0.9,
              ),
            ),
            opacity: 1.0,
            zIndex: 6.0,
          ),
        );
      }
    }

    // 2. Real Staff Markers: ONLY staff belonging to the selected branch!
    final now = DateTime.now();
    for (final staff in _filteredStaff) {
      if (staff.lat == 0.0 || staff.lng == 0.0) continue;
      final shown = _playback.position(staff.id, now);
      final staffPoint = Point(
        latitude: shown?.lat ?? staff.lat,
        longitude: shown?.lng ?? staff.lng,
      );
      final bytes = _markerBytesCache[staff.id] ?? _defaultUserMarkerBytes;
      if (bytes == null) continue;

      newObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('staff_${staff.id}'),
          point: staffPoint,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(bytes),
              scale: 0.75,
            ),
          ),
          opacity: 1.0,
          zIndex: 10.0,
          consumeTapEvents: true,
          onTap: (object, point) => _showStaffBottomSheet(staff, staffPoint),
        ),
      );
    }

    // 3. Marshrut — faqat "Harakat tarixi" ochilganda. Tayyorlanayotganda
    // (backend marshruti va ko'cha yo'llari kutilmoqda) chizilmaydi: rahbar
    // chala, keyin o'zgarib ketadigan chiziqni ko'rib chalg'imasin.
    var lines = const <List<({double lat, double lng})>>[];
    _historyCut = _historyPlayTime(now);
    if (_historyHead(now) case final head?) newObjects.add(head);
    if (_historyStaffId != null && !_loadingHistory && _serverRoute) {
      // Tezlikka qarab: piyoda — haqiqiy GPS izi (Zonic), transport —
      // backend yo'li, ma'lumot yo'q joy binolar ustidan ulanmaydi.
      final pieces = _speedTrackPieces();
      lines = [
        for (final p in pieces)
          if (p.kind == TrackPieceKind.walk || p.kind == TrackPieceKind.vehicle)
            p.points,
      ];
      for (var i = 0; i < pieces.length; i++) {
        final p = pieces[i];
        switch (p.kind) {
          case TrackPieceKind.walk:
            _addRouteLine(newObjects, 'staff_route_$i', p.points);
          case TrackPieceKind.vehicle:
            _addRouteLine(
              newObjects,
              'staff_route_$i',
              p.points,
              color: _vehicleRouteColor,
            );
          case TrackPieceKind.gap:
            _addRouteLine(newObjects, 'staff_gap_$i', p.points, dashed: true);
          case TrackPieceKind.missing:
            break;
        }
      }
    } else if (_historyStaffId != null && !_loadingHistory) {
      // Turish nuqtasiga borib-qaytgan "dumcha"lar chizilmaydi.
      // Borib-qaytgan qismlar va asosiy chiziqdan chiqqan qisqa "T"
      // dumchalar ham.
      lines = removeStubLines([
        for (final l in joinTouchingLines(_historyLines(), tolerance: 15))
          trimEndHooks(removeBacktracks(removeSpurs(l))),
      ]);
      // Yakuniy kafolat: bino ichidagi qism hech qachon chizilmaydi (backend
      // yo'li ham). Bino ichiga kirgan bo'lsa chiziq devor oldida to'xtaydi.
      final buildings = _streetRouter.buildings;
      if (buildings.isReady) {
        lines = [
          for (final l in lines)
            // 15 m: ko'cha yo'li bino chetiga tegib o'tgani (xaritalar farqi)
            // kesilmaydi — faqat haqiqatan bino ichidan o'tgan qism.
            for (final part in buildings.clipOutside(l, toleranceM: 15))
              if (part.length >= 2 &&
                  distanceMeters(
                        part.first.lat,
                        part.first.lng,
                        part.last.lat,
                        part.last.lng,
                      ) >=
                      3)
                part,
        ];
      }
      for (var i = 0; i < lines.length; i++) {
        _addRouteLine(newObjects, 'staff_route_$i', lines[i]);
      }
    }

    // 4. To'xtash joylari: raqamli metkalar, bosilganda vaqt oralig'i va
    // manzil chiqadi.
    for (var i = 0; i < _historyStops.length; i++) {
      final stop = _historyStops[i];
      final bytes = _stopMarkerCache[i + 1];
      if (bytes == null) continue;
      // GPS bino yonida 20–40 m adashadi: metka binoga emas, eng yaqin
      // chiziq ustiga qo'yiladi (60 m ichida bo'lsa; undan uzoq — xodim
      // haqiqatan chetga borgan, joyida qoladi). Joy nomi asl nuqtadan.
      final pin =
          nearestOnLines((lat: stop.lat, lng: stop.lng), lines) ??
          (lat: stop.lat, lng: stop.lng);
      newObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('staff_stop_$i'),
          point: Point(latitude: pin.lat, longitude: pin.lng),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(bytes),
              // Pin uchi aynan nuqtada turadi.
              anchor: const Offset(0.5, 0.95),
            ),
          ),
          opacity: 1.0,
          zIndex: 12.0 + i * 0.01,
          consumeTapEvents: true,
          onTap: (object, point) => _showStopSheet(stop, i + 1),
        ),
      );
    }

    // 4b. Lokatsiya uzilishlari (tomchisiz): uzilgan joyda "!" doira va
    // vaqt, qayta ulangan joyda halqa va vaqt — chiziq tugagan/boshlangan
    // uchda. Qizil — qoidabuzarlik, kulrang — xodim aybi emas.
    for (var i = 0; i < _outageMarks.length; i++) {
      final m = _outageMarks[i];
      final pin =
          nearestLineEnd(m.at, lines) ?? nearestOnLines(m.at, lines) ?? m.at;
      newObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('staff_outage_$i'),
          point: Point(latitude: pin.lat, longitude: pin.lng),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(_outageMarkIcons[i]),
              // Doira markazi aynan chiziq ustida.
              anchor: const Offset(
                0.5,
                AvatarMarkerHelper.outageDotY /
                    AvatarMarkerHelper.outageMarkerHeight,
              ),
            ),
          ),
          opacity: 1.0,
          zIndex: 12.5 + i * 0.01,
          consumeTapEvents: true,
          onTap: (object, point) => m.outages.length == 1
              ? _showOutageSheet(m.outages.first)
              : _showOutagesList(m.outages),
        ),
      );
    }

    // 5. Xodim hali shu joyda (10+ daqiqa): boshqa rangli metka, ichida
    // necha daqiqadan beri turgani. U yerdagi u yoq-bu yoqqa harakat
    // chizilmaydi (bitta nuqtaga yig'ilgan).
    final ongoing = _ongoingStop;
    final ongoingIcon = _ongoingMarker;
    if (_historyStaffId != null &&
        !_loadingHistory &&
        ongoing != null &&
        ongoingIcon != null) {
      final pin =
          nearestOnLines((lat: ongoing.lat, lng: ongoing.lng), lines) ??
          (lat: ongoing.lat, lng: ongoing.lng);
      newObjects.add(
        CircleMapObject(
          mapId: const MapObjectId('staff_stop_ongoing_area'),
          circle: Circle(
            center: Point(latitude: ongoing.lat, longitude: ongoing.lng),
            radius: stopRadiusM,
          ),
          strokeColor: _ongoingColor.withValues(alpha: 0.7),
          strokeWidth: 1.5,
          fillColor: _ongoingColor.withValues(alpha: 0.12),
          zIndex: 4,
        ),
      );
      newObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('staff_stop_ongoing'),
          point: Point(latitude: pin.lat, longitude: pin.lng),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(ongoingIcon),
              anchor: const Offset(0.5, 0.95),
            ),
          ),
          opacity: 1.0,
          zIndex: 13.0,
          consumeTapEvents: true,
          onTap: (object, point) => _showStopSheet(
            StaffStop(
              lat: ongoing.lat,
              lng: ongoing.lng,
              from: ongoing.from,
              to: DateTime.now(),
              nom: ongoing.nom,
              manzil: ongoing.manzil,
              rasmUrl: ongoing.rasmUrl,
            ),
            _historyStops.length + 1,
            ongoing: true,
          ),
        ),
      );
    }

    _mapObjects = List<MapObject<dynamic>>.unmodifiable(newObjects);
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
      final staffWithCoords = _filteredStaff
          .where((s) => s.lat != 0.0 && s.lng != 0.0)
          .toList();
      if (staffWithCoords.isNotEmpty) {
        final firstStaff = staffWithCoords.first;
        _controller?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: Point(
                latitude: firstStaff.lat,
                longitude: firstStaff.lng,
              ),
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

  Future<void> _loadStaffHistory(_StaffMapItem staff, {DateTime? date}) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    setState(() => _loadingHistory = true);
    final tsw = Stopwatch()..start();
    void t(String stage) =>
        debugPrint('⏱️ [TARIX VAQT] $stage: ${tsw.elapsedMilliseconds} ms');
    final now = DateTime.now();
    final day = date ?? now;
    final bool isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final today = day.toIso8601String().substring(0, 10);
    debugPrint(
      '════════════════════════════════════════════════════════════════',
    );
    debugPrint('🚀 [HARAKAT TARIXI] So\'rov boshlandi');
    debugPrint('👤 Xodim: ${staff.name} (ID: ${staff.id})');
    debugPrint('📅 Sana: $today');
    debugPrint(
      '🌐 Endpoint: ${ApiConstants.baseUrl}${ApiConstants.rahbarLokatsiyaTarix}/${staff.id}?sana=$today',
    );
    // Uzilishlar nuqtalar bilan parallel so'raladi; xato bo'lsa — yo'q.
    final outagesFuture = sl<RahbarRemoteDataSource>()
        .getLocationOutages(xodimId: staff.id, sana: today)
        .then<List<LocationOutage>?>((v) => v, onError: (_) => null);
    try {
      final data = await sl<RahbarRemoteDataSource>().getStaffLocationHistory(
        xodimId: staff.id,
        sana: today,
      );
      t('nuqtalar keldi');

      final dynamic rawList =
          data['nuqtalar'] ??
          data['data'] ??
          data['points'] ??
          data['locations'] ??
          data['history'] ??
          data['tracks'] ??
          data['harakatlar'];

      final List<_LocationHistoryPoint> points = [];
      // Kelgan har bir nuqta vaqti (aniqligidan qat'i nazar) — signal bor
      // edi; uzilishlar shu bo'yicha kesiladi.
      final signalTimes = <DateTime>[];
      if (rawList is List) {
        for (int i = 0; i < rawList.length; i++) {
          final item = rawList[i];
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final lat = _parseDouble(m['lat'] ?? m['latitude']);
            final lng = _parseDouble(m['lng'] ?? m['longitude']);
            if (parseStopTime(m['recorded_at'] ?? m['vaqt'], day)
                case final t?) {
              signalTimes.add(t);
            }
            // Aniqligi past (bino ichi/yonida 50 m+) nuqta chizilmaydi.
            if (_parseDouble(m['accuracy']) > trackDrawAccuracy) continue;
            // Server sakrab-qaytgan deb belgilagan nuqta chizilmaydi.
            if (m['shubhali'] == true) continue;
            if (lat != 0.0 && lng != 0.0) {
              points.add(
                _LocationHistoryPoint(
                  lat: lat,
                  lng: lng,
                  // To'liq vaqt (sana + soniya) birinchi.
                  vaqt:
                      (m['recorded_at'] ??
                              m['vaqt'] ??
                              m['time'] ??
                              m['created_at'] ??
                              '')
                          .toString(),
                  holat: m['holat']?.toString() ?? m['status']?.toString(),
                  inside: (m['inside'] ?? m['is_inside']) as bool?,
                  distanceM: _parseDouble(m['distance_m'] ?? m['distance']),
                ),
              );
            }
          }
        }
      }

      debugPrint(
        '📊 Jami qabul qilingan GPS nuqtalar soni: ${points.length} ta',
      );

      // To'xtash joylari: backend hisoblagan bo'lsa (manzil va rasm bilan)
      // o'shani, aks holda GPS nuqtalaridan shu yerda aniqlaymiz.
      List<StaffStop>? stops;
      try {
        stops = await sl<RahbarRemoteDataSource>().getStaffStops(
          xodimId: staff.id,
          sana: today,
        );
      } catch (e) {
        debugPrint('⚠️ [TO\'XTASH JOYLARI] backend xatosi: $e');
      }
      t('to\'xtashlar keldi');
      // Faqat "Keldim" → "Ketdim" oralig'idagi GPS: undan tashqaridagi
      // (masalan tungi) nuqtalar chizilmaydi va to'xtash bo'lmaydi.
      final window = await _workWindowFor(staff, day, isToday);
      t('ish oynasi');
      bool inWindow(DateTime t) =>
          window == null ||
          (window.$1 != null &&
              !t.isBefore(window.$1!.from) &&
              !t.isAfter(window.$1!.to));
      // Zonadan bir-ikki daqiqaga "chiqib-kirish" (GPS sakrashi) chizilmaydi
      // va to'xtash hisobiga ham kirmaydi.
      final timed = <TimedPoint>[
        for (final p in dropShortZoneExits([
          for (final p in points)
            if (parseStopTime(p.vaqt, day) case final t? when inWindow(t))
              (lat: p.lat, lng: p.lng, time: t, inside: p.inside),
        ]))
          (lat: p.lat, lng: p.lng, time: p.time),
      ];
      // Backend yurib aylanib kelgan joyni ham to'xtash deb berishi mumkin
      // (masalan, ko'chaning u tomoniga o'tib qaytganda) — o'sha oraliqdagi
      // GPS nuqtalari harakatni ko'rsatsa, bunday to'xtash ko'rsatilmaydi.
      stops = stops
          ?.where(
            (st) =>
                inWindow(st.from) &&
                inWindow(st.to) &&
                isStationaryBetween(timed, st.from, st.to),
          )
          .toList();
      // Server tarixdan bir joyda turgandagi nuqtalarni (titrash, 20 s lik
      // "shu yerdaman") olib tashlaydi — xodim hozir turgan joyda faqat
      // kelgan nuqtasi qoladi. Sessiya ochiq va xodim hali o'sha joyda
      // (jonli joylashuvi 100 m ichida, filial zonasidan tashqarida) bo'lsa,
      // to'xtashni aniqlash uchun "hozir shu yerda" nuqtasi qo'shiladi.
      final detect = [...timed]..sort((a, b) => a.time.compareTo(b.time));
      final w = window?.$1;
      final now = DateTime.now();
      if (isToday &&
          detect.isNotEmpty &&
          w != null &&
          now.difference(w.to).abs() < const Duration(minutes: 2)) {
        final last = detect.last;
        final live = _allStaff.where((e) => e.id == staff.id).firstOrNull;
        final stillThere =
            live != null &&
            live.lat != 0.0 &&
            distanceMeters(live.lat, live.lng, last.lat, last.lng) <= 100;
        final inBranch = _branches.any(
          (b) =>
              b.lat != 0.0 &&
              distanceMeters(b.lat, b.lng, last.lat, last.lng) <= b.radius,
        );
        if (stillThere && !inBranch && now.isAfter(last.time)) {
          detect.add((lat: last.lat, lng: last.lng, time: now));
        }
      } else if (detect.isNotEmpty && w != null) {
        // Sessiya yopilgan ("Ketdim"/avto-ketdi), oxirgi nuqta zonadan
        // tashqarida. Bir joyda turganda telefon har 20 s o'sha koordinatani
        // yuboradi, lekin tarix ularni "titrash" deb tashlaydi — shuning
        // uchun oxirgi joyda sessiya tugaguncha turgani ko'rinmay qolardi.
        final last = detect.last;
        final inBranch = _branches.any(
          (b) =>
              b.lat != 0.0 &&
              distanceMeters(b.lat, b.lng, last.lat, last.lng) <= b.radius,
        );
        final stay = w.to.difference(last.time);
        if (!inBranch &&
            stay >= const Duration(minutes: 2) &&
            stay <= const Duration(hours: 4)) {
          detect.add((lat: last.lat, lng: last.lng, time: w.to));
        }
      }
      if (stops == null) {
        stops = detectStaffStops(detect);
      } else if (isToday) {
        // Backend to'xtashlarni faqat sessiya yopilganda hisoblaydi — hali
        // ochiq sessiyadagilarini oxirgi metkadan keyingi nuqtalardan
        // shu yerda topamiz.
        final after = stops.isEmpty ? null : stops.last.to;
        stops = [
          ...stops,
          ...detectStaffStops([
            for (final p in detect)
              if (after == null || p.time.isAfter(after)) p,
          ]),
        ];
      }
      debugPrint('📍 [TO\'XTASH JOYLARI]: ${stops.length} ta');
      // Zonic backendidagi kabi: sakrash va titrash tashlanadi.
      final route = cleanTrack(
        [...timed]..sort((a, b) => a.time.compareTo(b.time)),
      );
      debugPrint('🧭 [MARSHRUT]: ${route.length} ta real nuqta');
      // 25 m ichida 10 daqiqadan ko'p turilgan, lekin to'xtash ro'yxatida
      // yo'q joylar ham raqamli metka bo'ladi — bosganda qancha turgani
      // ko'rinadi.
      final allStops = [...stops];
      for (final w in detectDwells(detect, radiusM: stopRadiusM)) {
        if (w.duration < stopMinDuration) continue;
        final covered = allStops.any(
          (st) => !st.to.isBefore(w.from) && !st.from.isAfter(w.to),
        );
        if (!covered) allStops.add(w);
      }
      // Metka turgan joyning o'rtasida (100 m aylana markazi) bo'lsin.
      // Chiziqda shu oraliq bitta nuqtaga yig'ilgan bo'lsa — aynan o'sha
      // nuqtaga, shunda metka chiziq ustida turadi.
      final routeDwells = detectDwells(route);
      for (var k = 0; k < allStops.length; k++) {
        final st = allStops[k];
        final dwell = routeDwells
            .where((w) => !w.to.isBefore(st.from) && !w.from.isAfter(st.to))
            .fold<StaffStop?>(
              null,
              (b, w) => b == null || w.duration > b.duration ? w : b,
            );
        allStops[k] = dwell == null
            ? centerStop(st, route)
            : StaffStop(
                lat: dwell.lat,
                lng: dwell.lng,
                from: st.from,
                to: st.to,
                nom: st.nom,
                manzil: st.manzil,
                rasmUrl: st.rasmUrl,
              );
      }
      // Xodimning O'Z filiali zonasi ichida turilgan vaqt ko'rsatilmaydi.
      // Boshqa filialga borib turgani — bu zonadan tashqaridagi to'xtash,
      // u ko'rsatiladi.
      final ownZone = _branches
          .where((b) => b.id == staff.filialId && b.lat != 0.0)
          .firstOrNull;
      if (ownZone != null) {
        allStops.removeWhere((st) {
          final d = distanceMeters(ownZone.lat, ownZone.lng, st.lat, st.lng);
          final inside = d <= ownZone.radius;
          if (inside) {
            debugPrint(
              '🏢 [TO\'XTASH] o\'z zonasi ichida, yashirildi: '
              '${_hm(st.from)}–${_hm(st.to)} (${d.round()} m / '
              '${ownZone.radius.round()} m)',
            );
          }
          return inside;
        });
      }
      allStops.sort((a, b) => a.from.compareTo(b.from));
      stops = allStops;
      for (var i = 1; i <= stops.length; i++) {
        _stopMarkerCache[i] ??= await AvatarMarkerHelper.generateNumberPinBytes(
          label: '$i',
          color: _stopColor,
          pixelRatio: dpr,
        );
      }

      // Uzilgandan qayta ulanguncha — bitta uzilish (server bo'lib bergan
      // ketma-ket yozuvlar alohida belgi bo'lmaydi), lekin GPS nuqtalari
      // kelib turgan vaqt uzilish emas.
      final rawOutages =
          await outagesFuture.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          ) ??
          const <LocationOutage>[];
      final outages = outagesFromPoints(rawOutages, signalTimes);
      final marks = outageMarks(
        outages,
        route,
        inZone: (lat, lng) => _branches.any(
          (b) =>
              b.lat != 0.0 &&
              b.radius > 0 &&
              distanceMeters(b.lat, b.lng, lat, lng) <= b.radius,
        ),
      );
      final markIcons = [
        for (final m in marks)
          await AvatarMarkerHelper.generateOutageMarkerBytes(
            time: _markLabel(m),
            color: _markViolation(m) ? _outageColor : _signalLostColor,
            start: m.start,
            pixelRatio: dpr,
          ),
      ];

      if (!mounted) return;
      final String? checkInTime = w != null
          ? _hm(w.from)
          : (isToday &&
                    staff.checkIn.trim().isNotEmpty &&
                    !staff.checkIn.contains('--')
                ? staff.checkIn.trim()
                : null);
      final String? emptyReason = (timed.isEmpty && checkInTime == null)
          ? _historyEmptyReasonFor(staff, isToday)
          : null;

      setState(() {
        _historyStops = stops!;
        _historyOutages = outages;
        _outageMarks = marks;
        _outageMarkIcons = markIcons;
        _baseStops = stops;
        _ongoingStop = null;
        _historyRoute = route;
        _historyStaffName = staff.name;
        _historyStaffId = staff.id;
        _matchedRoute = null;
        _serverRoute = !_phoneRouting || _pureBackendRoute;
        _matchedStamp = null;
        _historyStaff = staff;
        _historyDate = day;
        _historyCheckIn = checkInTime;
        _historyEmptyReason = emptyReason;
      });
      // Xodim hozir yurayotgan bo'lsa marker birinchi soniyadanoq tarix
      // nuqtalarini o'ynaydi — chiziq bilan bir vaqtda turadi.
      if (isToday && route.isNotEmpty) {
        final now = DateTime.now();
        final last = route.last.time;
        if (now.difference(last) < const Duration(minutes: 2)) {
          _playback.clear(staff.id);
          _playback.push(
            staff.id,
            [
              for (final p in route)
                if (last.difference(p.time) <= const Duration(seconds: 30)) p,
            ],
            source: 'tail',
            now: now,
          );
        }
      }
      t('hisob-kitob (${route.length} nuqta, ${stops.length} to\'xtash)');
      await _updateLiveStops(redraw: false);
      // Chiziqlar to'liq tayyor bo'lgach bir marta ko'rsatiladi.
      await _prepareHistoryLines();
      if (!mounted || _historyStaffId != staff.id) return;
      setState(() => _loadingHistory = false);
      _buildMapObjects();
      t('XARITADA KO\'RINDI');

      // Kamera butun marshrutga (bo'lmasa GPS nuqtalariga) qaratiladi.
      final focus = [for (final p in route) (lat: p.lat, lng: p.lng)];
      if (focus.isEmpty) return;

      if (focus.length == 1) {
        unawaited(
          _controller?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: Point(
                  latitude: focus.first.lat,
                  longitude: focus.first.lng,
                ),
                zoom: 16.0,
              ),
            ),
            animation: const MapAnimation(
              type: MapAnimationType.smooth,
              duration: 0.8,
            ),
          ),
        );
      } else {
        double minLat = focus.first.lat;
        double maxLat = focus.first.lat;
        double minLng = focus.first.lng;
        double maxLng = focus.first.lng;

        for (final p in focus) {
          if (p.lat < minLat) minLat = p.lat;
          if (p.lat > maxLat) maxLat = p.lat;
          if (p.lng < minLng) minLng = p.lng;
          if (p.lng > maxLng) maxLng = p.lng;
        }
        final latDelta = (maxLat - minLat).abs();
        final lngDelta = (maxLng - minLng).abs();
        final latPadding = latDelta > 0.0001 ? latDelta * 0.18 : 0.003;
        final lngPadding = lngDelta > 0.0001 ? lngDelta * 0.18 : 0.003;

        unawaited(
          _controller?.moveCamera(
            CameraUpdate.newGeometry(
              Geometry.fromBoundingBox(
                BoundingBox(
                  southWest: Point(
                    latitude: minLat - latPadding,
                    longitude: minLng - lngPadding,
                  ),
                  northEast: Point(
                    latitude: maxLat + latPadding,
                    longitude: maxLng + lngPadding,
                  ),
                ),
              ),
            ),
            animation: const MapAnimation(
              type: MapAnimationType.smooth,
              duration: 1.0,
            ),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ [HISTORY ERROR]: $e\n$stack');
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  /// Serverda nuqta bo'lmaganda rahbarga sababini tushuntiradi. Xodim
  /// ilovasi ofis ichida GPS yubormaydi, tashqarida esa har daqiqada
  /// yuboradi — shuning uchun "bo'sh" har doim ham xato emas.
  String _historyEmptyReasonFor(_StaffMapItem staff, bool isToday) {
    if (!isToday) return context.tr('rahbar_history_reason_none');
    if (staff.lat == 0.0 || staff.lng == 0.0) {
      return context.tr('rahbar_history_reason_no_gps');
    }
    if (staff.isInside) return context.tr('rahbar_history_reason_in_office');
    if ((staff.agoMin ?? 0) > 30) {
      return context.tr('rahbar_history_reason_stale', {
        'time': staff.lastUpdated ?? '-',
      });
    }
    return context.tr('rahbar_history_reason_none');
  }

  Future<void> _pickHistoryDate() async {
    final staff = _historyStaff;
    if (staff == null || _loadingHistory) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _historyDate,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    await _loadStaffHistory(staff, date: picked);
  }

  void _clearStaffHistory() {
    debugPrint('🧹 [HARAKAT TARIXI] Tozalandi va filialga qaytildi');
    setState(() {
      _historyStaffName = null;
      _historyStaffId = null;
      _historyStaff = null;
      _historyCheckIn = null;
      _historyEmptyReason = null;
      _historyDate = DateTime.now();
      _historyStops = [];
      _historyOutages = [];
      _outageMarks = [];
      _outageMarkIcons = [];
      _baseStops = [];
      _ongoingStop = null;
      _historyRoute = [];
      _matchedRoute = null;
      _serverRoute = !_phoneRouting || _pureBackendRoute;
      _matchedStamp = null;
    });
    _buildMapObjects();
    _moveCameraToBranch();
  }

  /// Xodimning shu kundagi ish oynasi. Natija `null` — davomat ma'lumoti
  /// olinmadi (nuqtalar filtrlanmaydi); `(null,)` — xodim "Keldim" bosmagan.
  Future<(({DateTime from, DateTime to})?,)?> _workWindowFor(
    _StaffMapItem staff,
    DateTime day,
    bool isToday,
  ) async {
    final now = DateTime.now();
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty || v.contains('--')) ? null : v;
    if (isToday && clean(staff.checkIn) != null) {
      return (
        workWindow(
          checkIn: clean(staff.checkIn),
          checkOut: staff.isInside ? null : clean(staff.checkOut),
          day: day,
          now: now,
        ),
      );
    }
    try {
      final list = await sl<RahbarRemoteDataSource>().getKundalik(
        date: day.toIso8601String().substring(0, 10),
      );
      final s = list.where((e) => e.id == staff.id).firstOrNull;
      if (s == null) return null;
      return (
        workWindow(
          checkIn: clean(s.checkIn),
          checkOut: clean(s.checkOut),
          day: day,
          now: now,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [ISH OYNASI] davomat olinmadi: $e');
      return null;
    }
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Backend manzil bermasa, Yandex teskari geokodlash orqali olinadi.
  Future<String?> _stopAddress(StaffStop stop) async {
    if (stop.manzil != null) return stop.manzil;
    final key = '${stop.lat.toStringAsFixed(5)},${stop.lng.toStringAsFixed(5)}';
    final cached = _stopAddressCache[key];
    if (cached != null) return cached;
    try {
      final (session, result) = await YandexSearch.searchByPoint(
        point: Point(latitude: stop.lat, longitude: stop.lng),
        zoom: 17,
        searchOptions: const SearchOptions(
          searchType: SearchType.geo,
          resultPageSize: 1,
        ),
      );
      final res = await result.timeout(const Duration(seconds: 8));
      unawaited(session.close());
      final items = res.items;
      if (items == null || items.isEmpty) return null;
      final address =
          items.first.toponymMetadata?.address.formattedAddress ??
          items.first.name;
      _stopAddressCache[key] = address;
      return address;
    } catch (e) {
      debugPrint('⚠️ [TO\'XTASH MANZILI] olinmadi: $e');
      return null;
    }
  }

  /// Backend joy nomini bermasa — to'xtash nuqtasidan [_placeRadius]
  /// ichidagi eng yaqin tashkilot (do'kon, mehmonxona, kafe...) nomi
  /// Yandex qidiruvidan olinadi. Yaqinda tashkilot bo'lmasa — `null`.
  static const _placeRadius = 50.0;

  Future<String?> _stopPlaceName(StaffStop stop) async {
    if (stop.nom != null) return stop.nom;
    final key = '${stop.lat.toStringAsFixed(5)},${stop.lng.toStringAsFixed(5)}';
    final cached = _stopPlaceCache[key];
    if (cached != null) return cached.isEmpty ? null : cached;
    try {
      final (session, result) = await YandexSearch.searchByPoint(
        point: Point(latitude: stop.lat, longitude: stop.lng),
        zoom: 18,
        searchOptions: const SearchOptions(
          searchType: SearchType.biz,
          resultPageSize: 5,
        ),
      );
      final res = await result.timeout(const Duration(seconds: 8));
      unawaited(session.close());
      String? best;
      var bestDist = double.infinity;
      for (final item in res.items ?? const <SearchItem>[]) {
        final p = item.geometry
            .map((g) => g.point)
            .whereType<Point>()
            .firstOrNull;
        if (p == null || item.businessMetadata == null) continue;
        final d = distanceMeters(stop.lat, stop.lng, p.latitude, p.longitude);
        if (d <= _placeRadius && d < bestDist) {
          bestDist = d;
          best = item.businessMetadata!.shortName ?? item.name;
        }
      }
      _stopPlaceCache[key] = best ?? '';
      return best;
    } catch (e) {
      debugPrint('⚠️ [TO\'XTASH JOYI] tashkilot topilmadi: $e');
      return null;
    }
  }

  /// Uzilish belgisiga kamera suriladi (ro'yxatdan tanlanganda).
  void _focusOutage(LocationOutage o) {
    final at = _outageMarks.where((m) => m.outages.contains(o)).firstOrNull?.at;
    if (at == null) return;
    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: at.lat, longitude: at.lng),
          zoom: 17,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.8,
      ),
    );
  }

  Widget _sheetFrame({required Widget child}) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: SafeArea(top: false, child: child),
  );

  /// Bitta uzilish: vaqti, sababi, davomiyligi.
  void _showOutageSheet(LocationOutage o) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('rahbar_outage_sheet_title'),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _OutageRow(outage: o),
            const SizedBox(height: 6),
            Text(
              context.tr(
                o.violation
                    ? 'rahbar_outage_violation'
                    : 'rahbar_outage_not_violation',
              ),
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: o.violation
                    ? context.colors.error
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarix kunidagi barcha uzilishlar; bosilganda xarita o'sha joyga.
  void _showOutagesList([List<LocationOutage>? only]) {
    final items = [...(only ?? _historyOutages)]
      ..sort((a, b) => a.from.compareTo(b.from));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: _sheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('rahbar_history_outages_title'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _outagesSummary(items),
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in items)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _focusOutage(o);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _OutageRow(outage: o),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _outagesSummary(List<LocationOutage> items) =>
      context.tr('rahbar_history_outages', {
        'count': '${items.length}',
        'min': '${items.fold<int>(0, (a, e) => a + e.minutes)}',
      });

  void _showStopSheet(StaffStop stop, int number, {bool ongoing = false}) {
    final minutes = stop.duration.inMinutes;
    final durationText = minutes >= 60
        ? context.tr('rahbar_stop_duration_hm', {
            'h': '${minutes ~/ 60}',
            'm': '${minutes % 60}',
          })
        : context.tr('rahbar_stop_duration_m', {'m': '$minutes'});
    final addressFuture = _stopAddress(stop);
    final placeFuture = _stopPlaceName(stop);
    final photo = stop.rasmUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.surface,
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
                Icon(
                  Icons.location_on_rounded,
                  color: ongoing ? _ongoingColor : const Color(0xFF16A34A),
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FutureBuilder<String?>(
                    future: placeFuture,
                    initialData: stop.nom,
                    builder: (context, snap) => Text(
                      snap.data ??
                          (ongoing
                              ? context.tr('rahbar_stop_still_here')
                              : context.tr('rahbar_stop_title', {
                                  'n': '$number',
                                })),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<String?>(
              future: addressFuture,
              builder: (context, snap) {
                final text =
                    snap.data ??
                    (snap.connectionState == ConnectionState.done
                        ? '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}'
                        : context.tr('rahbar_stop_address_loading'));
                return Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  ongoing
                      ? '${_hm(stop.from)} – ${context.tr('rahbar_stop_now')}'
                      : '${_hm(stop.from)} – ${_hm(stop.to)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($durationText)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            if (photo != null &&
                (photo.startsWith('http://') ||
                    photo.startsWith('https://'))) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: photo,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, {double radius = 26}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.primary.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
          color: context.colors.primary,
        ),
      ),
    );
  }

  /// Zonic app style: smoothly flies the map camera to the staff's exact location,
  /// selects their branch if needed, and opens their bottom sheet details.
  /// `/live` dan kelgan joylar. Vaqt rahbar soati bo'yicha (`ago_sec`):
  /// telefon soati noto'g'ri bo'lsa ham marker to'g'ri tezlikda yuradi.
  /// Tarixi ochiq xodimga zich nuqtalar `_pollHistoryTail` dan beriladi.
  void _feedLive(List<Map<String, dynamic>> live) {
    final now = DateTime.now();
    final ids = <int>{};
    for (final item in live) {
      final id = _parseInt(item['id'] ?? item['staff_id']);
      if (id <= 0) continue;
      ids.add(id);
      if (id == _historyStaffId && DateUtils.isSameDay(_historyDate, now)) {
        continue;
      }
      final loc = item['location'];
      final m = loc is Map ? loc : item;
      final lat = _parseDouble(m['lat'] ?? m['latitude'] ?? m['location_lat']);
      final lng = _parseDouble(m['lng'] ?? m['longitude'] ?? m['location_lng']);
      if (lat == 0.0 || lng == 0.0) continue;
      // Aniqligi yomon nuqtada marker sakramaydi — oxirgi yaxshi joyida.
      final acc = m['accuracy'] ?? item['accuracy'];
      if (acc != null && _parseDouble(acc) > trackDrawAccuracy) continue;
      final ago = item['ago_sec'] != null
          ? _parseInt(item['ago_sec'])
          : (item['ago_min'] != null ? _parseInt(item['ago_min']) * 60 : 0);
      _playback.push(
        id,
        [(lat: lat, lng: lng, time: now.subtract(Duration(seconds: ago)))],
        source: 'live',
        now: now,
      );
    }
    if (_historyStaffId != null) ids.add(_historyStaffId!);
    _playback.retain(ids);
  }

  /// Sekundiga 5 marta: faqat xodim markerlari va tarixi ochiq xodim
  /// chizig'ining boshi yangilanadi (qolgan obyektlar — zona, marshrut —
  /// o'sha nusxa, xarita ularni qayta chizmaydi). Xodimlar ortida iz
  /// qoldirilmaydi: chiziq faqat "Harakat tarixi" ochilganda. Hech kim
  /// harakatlanmasa hech narsa qilinmaydi.
  void _animTick() {
    if (!mounted || !_mapReady) return;
    final now = DateTime.now();
    final moving = _playback.anyMoving(now);
    if (!moving && !_animWasMoving) return;
    _animWasMoving = moving;
    final objects = <MapObject<dynamic>>[];
    var changed = false;
    for (final o in _mapObjects) {
      final id = o.mapId.value;
      if (id == 'history_head') {
        changed = true;
        continue;
      }
      if (o is PlacemarkMapObject && id.startsWith('staff_')) {
        final staffId = int.tryParse(id.substring(6));
        final p = staffId == null ? null : _playback.position(staffId, now);
        if (p != null &&
            (p.lat != o.point.latitude || p.lng != o.point.longitude)) {
          objects.add(
            o.copyWith(
              point: Point(latitude: p.lat, longitude: p.lng),
            ),
          );
          changed = true;
          continue;
        }
      }
      objects.add(o);
    }
    final head = _historyHead(now);
    if (!changed && head == null) return;
    setState(() => _mapObjects = [...objects, ?head]);
  }

  /// Bildirishnomadan kelgan xodim: ro'yxatda bo'lmasa (yoki holati
  /// eskirgan bo'lsa) ma'lumot yangilanadi, keyin karta ochiladi.
  void _onFocusRequest() {
    if (rahbarMapFocusStaff.value == null) return;
    if (!_tryFocusPending()) unawaited(_loadAllBackendData(silent: true));
  }

  /// Kutilayotgan xodimni xaritada ochadi. Xarita yoki ro'yxat hali tayyor
  /// bo'lmasa `false` (keyin qayta chaqiriladi).
  bool _tryFocusPending() {
    final id = rahbarMapFocusStaff.value;
    if (id == null || !mounted || _controller == null) return false;
    final staff = _allStaff.where((s) => s.id == id).firstOrNull;
    if (staff == null) return false;
    rahbarMapFocusStaff.value = null;
    _focusOnStaff(staff);
    return true;
  }

  void _focusOnStaff(_StaffMapItem staff) {
    // 1. If staff belongs to another branch, switch to that branch
    if (staff.filialId != null && staff.filialId! > 0) {
      for (int i = 0; i < _branches.length; i++) {
        if (_branches[i].id == staff.filialId) {
          if (_selectedBranchIndex != i) {
            _onBranchSelected(i);
          }
          break;
        }
      }
    }

    // 2. Clear search text and close keyboard
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _filterStaff('');
      _buildMapObjects();
    });

    // 3. Move camera smoothly to the staff member's exact GPS location
    Point targetPoint;
    double targetZoom;
    if (staff.lat != 0.0 && staff.lng != 0.0) {
      targetPoint = Point(latitude: staff.lat, longitude: staff.lng);
      targetZoom = 17.5;
    } else {
      // Fallback to branch coordinates if staff doesn't have live coordinates yet
      final branch = _branches.isNotEmpty
          ? _branches[_selectedBranchIndex.clamp(0, _branches.length - 1)]
          : null;
      if (branch != null && branch.lat != 0.0 && branch.lng != 0.0) {
        targetPoint = Point(latitude: branch.lat, longitude: branch.lng);
        targetZoom = 16.0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${staff.name}ning jonli koordinatasi hozircha yo\'q (filial hududi ko\'rsatilmoqda)',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        return;
      }
    }

    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: targetPoint, zoom: targetZoom),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.0,
      ),
    );

    // 4. Open staff details bottom sheet (Zonic style)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _showStaffBottomSheet(staff, targetPoint);
      }
    });
  }

  Widget _buildSearchResultsDropdown() {
    final query = _searchController.text.trim().toLowerCase();
    final results = _allStaff.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.bolim.toLowerCase().contains(query) ||
          s.lavozim.toLowerCase().contains(query) ||
          (s.filialName != null && s.filialName!.toLowerCase().contains(query));
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 270),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: results.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Center(
                  child: Text(
                    context.tr('rahbar_search_no_staff', {
                      'query': _searchController.text.trim(),
                    }),
                    style: GoogleFonts.outfit(
                      color: context.colors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: results.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 58,
                  endIndent: 12,
                  color: context.colors.surfaceStrong,
                ),
                itemBuilder: (ctx, i) {
                  final staff = results[i];
                  return _buildStaffListTile(staff, () => _focusOnStaff(staff));
                },
              ),
      ),
    );
  }

  Widget _buildStaffListTile(_StaffMapItem s, VoidCallback onTap) {
    Color statusColor;
    String statusText;
    final att = s.attendanceStatus.toLowerCase();
    if (s.isInside) {
      statusColor = context.colors.success;
      statusText = s.checkIn != '--:--' && s.checkIn.isNotEmpty
          ? 'Hududda (${s.checkIn})'
          : 'Hududda';
    } else if (s.lat != 0.0 && s.lng != 0.0) {
      statusColor = att == 'ishda'
          ? const Color(0xFFEA580C)
          : (att == 'kechikkan'
                ? const Color(0xFFD97706)
                : context.colors.error);
      statusText = s.distanceMeters > 0
          ? 'Tashqarida: ${s.distanceMeters.toStringAsFixed(0)}m'
          : 'Tashqarida';
    } else if (att == 'ishda') {
      statusColor = context.colors.success;
      statusText = s.checkIn != '--:--' && s.checkIn.isNotEmpty
          ? 'Ishda (${s.checkIn})'
          : 'Ishda';
    } else if (att == 'kelmagan') {
      statusColor = context.colors.error;
      statusText = 'Kelmagan';
    } else {
      statusColor = context.colors.textHint;
      statusText = s.checkIn.isNotEmpty && s.checkIn != '--:--'
          ? s.checkIn
          : 'Belgilanmagan';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          if (s.photo != null &&
              s.photo!.isNotEmpty &&
              !s.photo!.contains('localhost') &&
              (s.photo!.startsWith('http://') ||
                  s.photo!.startsWith('https://')))
            CachedNetworkImage(
              imageUrl: s.photo!,
              imageBuilder: (context, imageProvider) =>
                  CircleAvatar(radius: 20, backgroundImage: imageProvider),
              placeholder: (_, _) => _buildFallbackAvatar(s.name, radius: 20),
              errorWidget: (_, _, _) =>
                  _buildFallbackAvatar(s.name, radius: 20),
            )
          else
            _buildFallbackAvatar(s.name, radius: 20),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        s.name,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: context.colors.textPrimary,
        ),
      ),
      subtitle: Text(
        '${s.bolim}${s.lavozim.isNotEmpty ? " • ${s.lavozim}" : ""}${s.filialName != null ? " (${s.filialName})" : ""}',
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: context.colors.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.near_me_rounded, color: context.colors.primary, size: 18),
        ],
      ),
    );
  }

  void _showStaffListModal() {
    final currentBranch = _branches.isNotEmpty
        ? _branches[_selectedBranchIndex.clamp(0, _branches.length - 1)]
        : null;
    final staffList = _filteredStaff;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (context, scrollController) => DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentBranch != null
                                ? '${currentBranch.name} (${staffList.length} nafar)'
                                : 'Xodimlar (${staffList.length})',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Xodimni tanlang — xaritada uning joyiga olib boradi',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: staffList.isEmpty
                    ? Center(
                        child: Text(
                          'Bu filialda xodimlar mavjud emas',
                          style: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        itemCount: staffList.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 58,
                          endIndent: 12,
                          color: context.colors.surfaceStrong,
                        ),
                        itemBuilder: (context, i) {
                          final s = staffList[i];
                          return _buildStaffListTile(s, () {
                            Navigator.pop(ctx);
                            _focusOnStaff(s);
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffBottomSheet(_StaffMapItem staff, Point point) {
    debugPrint(
      '════════════════════════════════════════════════════════════════',
    );
    debugPrint('👤 [XARITA - XODIM BOSILDI]: ${staff.name} (ID: ${staff.id})');
    debugPrint('🏢 Bo\'lim: ${staff.bolim}, Lavozim: ${staff.lavozim}');
    debugPrint('📍 Joriy koordinata: lat=${staff.lat}, lng=${staff.lng}');
    debugPrint(
      '⏰ Kelgan: ${staff.checkIn}, Ketgan: ${staff.checkOut}, Holati: ${staff.attendanceStatus}',
    );
    debugPrint(
      '🏢 Hudud ichidami: ${staff.isInside ? "HA (Hududda)" : "YO'Q (Tashqarida)"}',
    );
    debugPrint(
      '════════════════════════════════════════════════════════════════',
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
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
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${staff.bolim}${staff.lavozim.isNotEmpty ? " · ${staff.lavozim}" : ""}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: context.colors.textSecondary,
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
                      badgeColor = context.colors.success;
                      badgeLabel = context.tr('rahbar_badge_at_work');
                    } else if (att == 'kechikkan') {
                      badgeColor = const Color(0xFFEA580C);
                      badgeLabel = context.tr('rahbar_kpi_late');
                    } else if (att == 'kelmagan') {
                      badgeColor = context.colors.error;
                      badgeLabel = context.tr('attendance_absent');
                    } else if (att == 'ketgan') {
                      badgeColor = context.colors.textSecondary;
                      badgeLabel = context.tr('rahbar_badge_left');
                    } else {
                      badgeColor = staff.isInside
                          ? context.colors.success
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
                                color: context.colors.textHint,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            if (staff.signal != null) ...[
              const SizedBox(height: 14),
              _SignalLostBanner(staffId: staff.id, signal: staff.signal!),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, color: context.colors.divider),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeDetail(
                  context.tr('rahbar_checkin_time_label'),
                  staff.checkIn,
                  Icons.login_rounded,
                  context.colors.primary,
                ),
                _buildTimeDetail(
                  context.tr('rahbar_checkout_time_label'),
                  staff.checkOut,
                  Icons.logout_rounded,
                  context.colors.accent,
                ),
                _buildTimeDetail(
                  context.tr('rahbar_status_label'),
                  staff.status,
                  Icons.verified_user_rounded,
                  Colors.green,
                ),
              ],
            ),
            ?_zoneTimeRow(staff),
            _LocationOutagesSection(staffId: staff.id),
            const SizedBox(height: 18),

            // Action 1: Load & draw the staff's GPS movement history trail (Zonic app logic)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _loadingHistory
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _loadStaffHistory(staff);
                      },
                icon: const Icon(Icons.route_rounded, color: Colors.white),
                label: Text(
                  context.tr('rahbar_view_history_button'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Action 2: Assign In-App Work Geofence Zone for this staff
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  side: BorderSide(color: context.colors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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

  /// "Zonada: 3:42:10" — bugun "Keldim" dan beri o'z zonasi ichida
  /// o'tgan vaqt (sekundomer). Kelmagan yoki zonasi yo'q xodimda — `null`.
  Widget? _zoneTimeRow(_StaffMapItem staff) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final start = parseStopTime(staff.checkIn, day);
    final zone = _branches
        .where((b) => b.id == staff.filialId && b.lat != 0.0)
        .firstOrNull;
    if (start == null || zone == null || start.isAfter(now)) return null;
    final end = parseStopTime(staff.checkOut, day);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _ZoneTimeRow(
        start: start,
        end: end != null && end.isAfter(start) ? end : null,
        zone: zone,
        isOutsideNow: () {
          final live = _allStaff.where((s) => s.id == staff.id).firstOrNull;
          return (live ?? staff).holat == 'tashqarida';
        },
        loadHistory: () => sl<RahbarRemoteDataSource>().getStaffLocationHistory(
          xodimId: staff.id,
          sana: day.toIso8601String().substring(0, 10),
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
            color: context.colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('rahbar_map_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
            fontSize: 18,
          ),
        ),
        actions: [
          // "Yangi hudud" button placed on top in AppBar replacing manual refresh icon
          Container(
            margin: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
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
          // 1. Yandex Map Widget (isolated in RepaintBoundary with 2D & fastTap for 120fps)
          RepaintBoundary(
            child: YandexMap(
              mapType: _mapType,
              mode2DEnabled: true,
              fastTapEnabled: true,
              tiltGesturesEnabled: false,
              nightModeEnabled: context.isDarkMode,
              mapObjects: _mapReady ? _mapObjects : const [],
              onMapCreated: (controller) async {
                _controller = controller;
                if (mounted) setState(() => _mapReady = true);
                _moveCameraToBranch();
                _tryFocusPending();
              },
            ),
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
                    color: context.colors.surface,
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
                                  decoration: BoxDecoration(
                                    color: context.colors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  context.tr('rahbar_live_badge'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _showStaffListModal,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.tr('rahbar_total_count', {
                                      'count': '$totalCount',
                                    }),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('rahbar_inside_count', {
                                      'count': '$insideCount',
                                    }),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: context.colors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: context.colors.textSecondary,
                                  ),
                                ],
                              ),
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
                                  selectedColor: context.colors.primary,
                                  labelStyle: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : context.colors.textPrimary,
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

                // If a staff GPS history trail is showing, display a clean dismiss bar
                if (_historyStaffId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.route_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _historyStaffName ??
                                    context.tr('rahbar_staff_fallback'),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_historyCheckIn != null)
                                Text(
                                  '${context.tr('rahbar_checkin_time_label')}: $_historyCheckIn',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else if (_historyEmptyReason != null)
                                Text(
                                  _historyEmptyReason!,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (_historyOutages.isNotEmpty &&
                                  !_loadingHistory)
                                GestureDetector(
                                  onTap: _showOutagesList,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.gps_off_rounded,
                                          color: Color(0xFFFECACA),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _outagesSummary(_historyOutages),
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFFFECACA),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: const Color(
                                                0xFFFECACA,
                                              ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _pickHistoryDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_loadingHistory)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_historyDate.day.toString().padLeft(2, '0')}.${_historyDate.month.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _clearStaffHistory,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Yopish',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                    color: context.colors.surface,
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
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: context.colors.primary,
                    decoration: InputDecoration(
                      hintText: context.tr('rahbar_search_staff_plural'),
                      hintStyle: GoogleFonts.outfit(
                        color: context.colors.textHint,
                        fontSize: 13.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: context.colors.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: context.colors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _filterStaff('');
                                  _buildMapObjects();
                                });
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.people_alt_rounded,
                                size: 20,
                                color: context.colors.primary,
                              ),
                              tooltip: 'Xodimlar ro\'yxati',
                              onPressed: _showStaffListModal,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Floating search results dropdown (tap to fly directly to staff location Zonic style)
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildSearchResultsDropdown(),
                ],
              ],
            ),
          ),

          // 3. Floating action buttons on bottom right (Staff List, Layers, Center, My Location)
          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'staff_list_btn',
                  backgroundColor: context.colors.surface,
                  foregroundColor: context.colors.primary,
                  tooltip: 'Xodimlar ro\'yxati',
                  onPressed: _showStaffListModal,
                  child: const Icon(Icons.people_alt_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_layer_toggle',
                  backgroundColor: context.colors.surface,
                  foregroundColor: context.colors.primary,
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
                  backgroundColor: context.colors.surface,
                  foregroundColor: context.colors.primary,
                  onPressed: _moveCameraToBranch,
                  child: const Icon(Icons.center_focus_strong_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'my_location',
                  backgroundColor: context.colors.primary,
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
              child: Center(
                child: CircularProgressIndicator(color: context.colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Zona ichidagi vaqt sekundomeri: har soniyada yangilanadi, xodim
/// zonadan chiqqanda to'xtaydi, qaytganda davom etadi.
///
/// Backend tarix javobida `zonada_sek` (+ `zonada_hozir`, `hisoblangan_at`)
/// bersa — o'sha (kirish/chiqish hodisalaridan aniq hisob) ishlatiladi; aks
/// holda GPS tarixidan ([timeInZone]) hisoblanadi.
class _ZoneTimeRow extends StatefulWidget {
  final DateTime start;
  final DateTime? end;
  final _BranchLocation zone;
  final bool Function() isOutsideNow;
  final Future<Map<String, dynamic>> Function() loadHistory;

  const _ZoneTimeRow({
    required this.start,
    required this.end,
    required this.zone,
    required this.isOutsideNow,
    required this.loadHistory,
  });

  @override
  State<_ZoneTimeRow> createState() => _ZoneTimeRowState();
}

class _ZoneTimeRowState extends State<_ZoneTimeRow> {
  Timer? _timer;
  List<ZoneSample>? _samples;

  /// Backend hisobi: shu paytgacha zonada o'tgan vaqt.
  ({Duration value, DateTime at, bool inside})? _backend;
  DateTime? _loadedAt;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Yangi chiqish/kirishlar ham hisobga kirsin (bugun, ochiq sessiya).
      final last = _loadedAt;
      if (widget.end == null &&
          last != null &&
          DateTime.now().difference(last) > const Duration(seconds: 15)) {
        _load();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await widget.loadHistory();
      final day = DateTime(
        widget.start.year,
        widget.start.month,
        widget.start.day,
      );
      final sek = data['zonada_sek'];
      if (sek is num) {
        _backend = (
          value: Duration(seconds: sek.toInt()),
          at: parseStopTime(data['hisoblangan_at'], day) ?? DateTime.now(),
          inside: data['zonada_hozir'] == true,
        );
      }
      final raw = data['nuqtalar'] ?? data['data'] ?? data['points'];
      final z = widget.zone;
      _samples = [
        if (raw is List)
          for (final m in raw.whereType<Map<dynamic, dynamic>>())
            if (parseStopTime(m['recorded_at'] ?? m['vaqt'], day) case final t?)
              if (_num(m['lat'] ?? m['latitude']) case final lat
                  when lat != 0.0 &&
                      _num(m['accuracy'] ?? 0) <= trackMaxAccuracy)
                (
                  time: t,
                  outside:
                      distanceMeters(
                        z.lat,
                        z.lng,
                        lat,
                        _num(m['lng'] ?? m['longitude']),
                      ) >
                      z.radius,
                ),
      ];
      _loadedAt = DateTime.now();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('⚠️ [ZONADA VAQT] tarix olinmadi: $e');
      _loadedAt = DateTime.now();
    } finally {
      _loading = false;
    }
  }

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final end = widget.end ?? now;
    final closed = widget.end != null;
    final outside = !closed && widget.isOutsideNow();
    Duration? value;
    final b = _backend;
    if (b != null) {
      value = b.value;
      if (!closed && b.inside && !outside && end.isAfter(b.at)) {
        value += end.difference(b.at);
      }
    } else if (_samples != null) {
      value = timeInZone(
        start: widget.start,
        end: end,
        samples: _samples!,
        outsideNow: outside,
      );
    }
    final running = !closed && !outside && value != null;
    final color = running ? c.success : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            running ? Icons.timer_rounded : Icons.pause_circle_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              outside
                  ? '${context.tr('rahbar_zone_time_label')} · '
                        '${context.tr('rahbar_zone_time_paused')}'
                  : context.tr('rahbar_zone_time_label'),
              style: GoogleFonts.outfit(fontSize: 13, color: c.textSecondary),
            ),
          ),
          Text(
            value == null ? '…' : _fmt(value),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Xodim kartasidagi davom etayotgan uzilish davomiyligi (daqiqa) —
/// [_LocationOutagesSection] hisoblaydi (GPS nuqtalari bilan tozalangan).
/// Banner va uzilishlar ro'yxati bir xil raqam ko'rsatishi uchun.
final _ongoingOutageMinutes = <int, ValueNotifier<int?>>{};

ValueNotifier<int?> _ongoingOutageFor(int staffId) =>
    _ongoingOutageMinutes.putIfAbsent(staffId, () => ValueNotifier(null));

/// Xodim kartasida: ish vaqtida signal yo'q — qancha vaqtdan beri va nima
/// sababdan. Daqiqa — uzilishlar ro'yxatidagi davom etayotgan uzilishdan
/// (bo'lmasa serverning `signal_yoq_min`i): server bir lahzalik nuqtadan
/// keyin sanashni qaytadan boshlaydi, ro'yxat esa uni uzilish deb sanaydi.
class _SignalLostBanner extends StatelessWidget {
  const _SignalLostBanner({required this.staffId, required this.signal});

  final int staffId;
  final SignalLoss signal;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: _ongoingOutageFor(staffId),
      builder: (context, ongoing, _) => _build(context, ongoing),
    );
  }

  Widget _build(BuildContext context, int? ongoing) {
    final minutes = ongoing ?? signal.minutes;
    final soft =
        signal.reason == 'phone_died' || signal.reason == 'no_internet';
    final color = soft ? const Color(0xFF64748B) : context.colors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_disabled_rounded, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  minutes != null
                      ? context.tr('rahbar_signal_lost_for', {
                          'min': '$minutes',
                        })
                      : context.tr('rahbar_signal_lost'),
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  context.tr('loc_reason_${signal.reason}'),
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
}

/// Xodim kartasida bugungi lokatsiya uzilishlari. Backend endpointni hali
/// bermasa yoki uzilish bo'lmasa — hech narsa ko'rsatilmaydi.
class _LocationOutagesSection extends StatefulWidget {
  const _LocationOutagesSection({required this.staffId});

  final int staffId;

  @override
  State<_LocationOutagesSection> createState() =>
      _LocationOutagesSectionState();
}

class _LocationOutagesSectionState extends State<_LocationOutagesSection> {
  static const _shown = 4;
  List<LocationOutage>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Server uzilishlari bugungi GPS nuqtalari bilan kesiladi — nuqtalar
  /// kelib turgan vaqt uzilish sanalmaydi (tarix bilan bir xil hisob).
  Future<void> _load() async {
    final ds = sl<RahbarRemoteDataSource>();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final history = ds
        .getStaffLocationHistory(xodimId: widget.staffId)
        .then<Map<String, dynamic>?>((v) => v, onError: (_) => null);
    try {
      final raw = await ds.getLocationOutages(xodimId: widget.staffId);
      if (raw == null) return;
      final list = (await history)?['nuqtalar'];
      final times = <DateTime>[
        if (list is List)
          for (final m in list.whereType<Map<dynamic, dynamic>>())
            ?parseStopTime(m['recorded_at'] ?? m['vaqt'], day),
      ];
      final items = outagesFromPoints(raw, times);
      if (!mounted) return;
      _ongoingOutageFor(widget.staffId).value = items
          .where((o) => o.ongoing)
          .lastOrNull
          ?.minutes;
      setState(() => _items = items);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final violations = items.where((e) => e.violation).toList();
    final total = violations.fold<int>(0, (a, e) => a + e.minutes);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('rahbar_outages_title'),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              if (violations.isNotEmpty)
                Text(
                  context.tr('rahbar_outages_summary', {
                    'count': '${violations.length}',
                    'min': '$total',
                  }),
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final o in items.take(_shown))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _OutageRow(outage: o),
            ),
          if (items.length > _shown)
            Text(
              context.tr('rahbar_outages_more', {
                'count': '${items.length - _shown}',
              }),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: context.colors.textHint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bitta uzilish qatori: vaqt oralig'i, sababi, davomiyligi.
class _OutageRow extends StatelessWidget {
  const _OutageRow({required this.outage});

  final LocationOutage outage;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final o = outage;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: o.violation ? context.colors.error : context.colors.textHint,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          o.ongoing
              ? '${_OutageRow._hm(o.from)} – ${context.tr('rahbar_outage_now')}'
              : '${_OutageRow._hm(o.from)} – ${_OutageRow._hm(o.to!)}',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('loc_reason_${o.reason}'),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Text(
          context.tr('rahbar_outage_min', {'min': '${o.minutes}'}),
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
