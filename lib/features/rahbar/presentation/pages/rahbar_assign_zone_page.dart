import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skore_hodimlar/core/constants/app_colors.dart';
import 'package:skore_hodimlar/core/di/injection_container.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/utils/avatar_marker_helper.dart';
import 'package:skore_hodimlar/features/rahbar/data/datasources/rahbar_remote_datasource.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

/// In-app Interactive Map to pick a point and assign a circular geofence work zone for staff / branch
class RahbarAssignZonePage extends StatefulWidget {
  final String? staffName;
  final int? staffId;
  final double? initialLat;
  final double? initialLng;

  const RahbarAssignZonePage({
    super.key,
    this.staffName,
    this.staffId,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<RahbarAssignZonePage> createState() => _RahbarAssignZonePageState();
}

class _RahbarAssignZonePageState extends State<RahbarAssignZonePage> {
  YandexMapController? _controller;
  late Point _selectedPoint;
  double _radius = 100.0;
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;
  final List<MapObject<dynamic>> _mapObjects = [];
  Uint8List? _centerDotBytes;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLat ?? 41.311081;
    final lng = widget.initialLng ?? 69.240562;
    _selectedPoint = Point(latitude: lat, longitude: lng);

    if (widget.staffName != null && widget.staffName!.isNotEmpty) {
      _nameController.text = context.tr('assign_zone_default_name_staff', {
        'name': widget.staffName!,
      });
    } else {
      _nameController.text = context.tr('assign_zone_default_name_new');
    }

    _loadMarkerAndBuild();
    _fetchCurrentLocationIfDefault();
  }

  Future<void> _loadMarkerAndBuild() async {
    _centerDotBytes = await AvatarMarkerHelper.generateOfficePinBytes();
    _buildMapObjects();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocationIfDefault() async {
    if (widget.initialLat != null && widget.initialLng != null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
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
            _selectedPoint = Point(
              latitude: pos.latitude,
              longitude: pos.longitude,
            );
            _buildMapObjects();
          });
          unawaited(
            _controller?.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _selectedPoint, zoom: 16.5),
              ),
              animation: const MapAnimation(
                type: MapAnimationType.smooth,
                duration: 0.8,
              ),
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _buildMapObjects() {
    _mapObjects.clear();

    // 1. Dynamic circular geofence boundary around selected point
    _mapObjects.add(
      CircleMapObject(
        mapId: const MapObjectId('zone_circle'),
        circle: Circle(center: _selectedPoint, radius: _radius),
        strokeColor: const Color(0xFF0D6E6E),
        strokeWidth: 3.0,
        fillColor: const Color(0xFF0D6E6E).withValues(alpha: 0.18),
      ),
    );

    // 2. Clean Center Dot Marker (Oddiy nuqta)
    if (_centerDotBytes != null) {
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('zone_center_pin'),
          point: _selectedPoint,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(_centerDotBytes!),
              scale: 0.85,
            ),
          ),
          opacity: 1.0,
        ),
      );
    }

    if (mounted) setState(() {});
  }

  void _onMapTap(Point point) {
    setState(() {
      _selectedPoint = point;
      _buildMapObjects();
    });
  }

  Future<void> _saveZone() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('assign_zone_name_required'))),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final remoteDs = sl<RahbarRemoteDataSource>();
      await remoteDs.addBranchLocation(
        nom: name,
        lat: _selectedPoint.latitude,
        lng: _selectedPoint.longitude,
        radius: _radius.round(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('assign_zone_saved_success', {
              'name': name,
              'radius': '${_radius.round()}',
            }),
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('assign_zone_error', {
              'error': e.toString().replaceAll('Exception:', ''),
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        iconTheme: const IconThemeData(color: Color(0xFF0D6E6E)),
        title: Column(
          children: [
            Text(
              context.tr('assign_zone_title'),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D6E6E),
                fontSize: 17,
              ),
            ),
            if (widget.staffName != null)
              Text(
                context.tr('assign_zone_staff_label', {
                  'name': widget.staffName!,
                }),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. In-App Yandex Map
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (controller) async {
              _controller = controller;
              unawaited(
                _controller?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _selectedPoint, zoom: 16.5),
                  ),
                ),
              );
            },
            onMapTap: _onMapTap,
          ),

          // 2. Top Instruction Pill
          Positioned(
            top: 14,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFF0D6E6E),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('assign_zone_instruction'),
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Configuration & Save Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name Field
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('assign_zone_name_field_label'),
                      labelStyle: GoogleFonts.outfit(
                        color: const Color(0xFF0D6E6E),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.business_rounded,
                        color: Color(0xFF0D6E6E),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0D6E6E),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Radius Slider Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('assign_zone_radius_label'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6E6E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr('assign_zone_radius_value', {
                            'radius': '${_radius.round()}',
                          }),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D6E6E),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF0D6E6E),
                      thumbColor: const Color(0xFF0D6E6E),
                      overlayColor: const Color(
                        0xFF0D6E6E,
                      ).withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _radius,
                      min: 30.0,
                      max: 500.0,
                      divisions: 47,
                      onChanged: (val) {
                        setState(() {
                          _radius = val;
                          _buildMapObjects();
                        });
                      },
                    ),
                  ),

                  // Coordinates Text
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Save Button
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
                      onPressed: _saving ? null : _saveZone,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(
                        _saving
                            ? context.tr('assign_zone_saving')
                            : context.tr('assign_zone_save_button'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
