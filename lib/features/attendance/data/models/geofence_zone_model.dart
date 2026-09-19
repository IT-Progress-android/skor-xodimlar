import 'package:equatable/equatable.dart';

class GeofenceZoneModel extends Equatable {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final int radiusMeter;
  final String? wifiBssid;
  final String? wifiSsid;

  const GeofenceZoneModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radiusMeter = 200,
    this.wifiBssid,
    this.wifiSsid,
  });

  factory GeofenceZoneModel.fromJson(Map<String, dynamic> json) {
    double parseCoordinate(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseRadius(dynamic val) {
      if (val == null) return 200;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 200;
    }

    return GeofenceZoneModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      lat: parseCoordinate(json['lat'] ?? json['latitude']),
      lng: parseCoordinate(json['lng'] ?? json['longitude']),
      radiusMeter: parseRadius(json['radius_meter'] ?? json['radius']),
      wifiBssid: json['wifi_bssid']?.toString(),
      wifiSsid: json['wifi_ssid']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius_meter': radiusMeter,
      'wifi_bssid': wifiBssid,
      'wifi_ssid': wifiSsid,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    lat,
    lng,
    radiusMeter,
    wifiBssid,
    wifiSsid,
  ];
}
