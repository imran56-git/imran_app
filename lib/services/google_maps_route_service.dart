import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Result container holding distance, travel duration, polyline points, and fallback status.
class RouteCalculationResult {
  final double roadDistanceKm;
  final int estimatedTravelMinutes;
  final String formattedDistance;
  final String formattedDuration;
  final List<Map<String, double>> polylinePoints;
  final String travelMode;
  final bool isFallback;

  const RouteCalculationResult({
    required this.roadDistanceKm,
    required this.estimatedTravelMinutes,
    required this.formattedDistance,
    required this.formattedDuration,
    required this.polylinePoints,
    required this.travelMode,
    required this.isFallback,
  });

  Map<String, dynamic> toMap() {
    return {
      'roadDistanceKm': roadDistanceKm,
      'estimatedTravelMinutes': estimatedTravelMinutes,
      'formattedDistance': formattedDistance,
      'formattedDuration': formattedDuration,
      'polylinePoints': polylinePoints,
      'travelMode': travelMode,
      'isFallback': isFallback,
    };
  }

  @override
  String toString() {
    return 'RouteCalculationResult(distance: $formattedDistance, duration: $formattedDuration, mode: $travelMode, isFallback: $isFallback)';
  }
}

class _RouteCacheEntry {
  final RouteCalculationResult result;
  final DateTime timestamp;

  _RouteCacheEntry({required this.result, required this.timestamp});

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 30);
}

class GoogleMapsRouteService {
  // 30-minute in-memory cache to prevent redundant billable Google API requests
  static final Map<String, _RouteCacheEntry> _cache = {};

  /// Clears in-memory cached routes
  static void clearCache() {
    _cache.clear();
  }

  /// Calculates route details between two points.
  /// Uses cached result if available. Calls Google Directions API if [apiKey] is provided.
  /// Gracefully falls back to curvature-adjusted Haversine calculations if offline,
  /// request fails, or no API key is provided.
  static Future<RouteCalculationResult> calculateRoadRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String travelMode = 'driving',
    String? apiKey,
  }) async {
    final String normalizedMode = travelMode.toLowerCase().trim();
    final String cacheKey =
        '${originLat.toStringAsFixed(4)}_${originLng.toStringAsFixed(4)}_${destLat.toStringAsFixed(4)}_${destLng.toStringAsFixed(4)}_$normalizedMode';

    // 1. Check in-memory cache
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }

    // 2. Attempt Google Directions API if apiKey is present
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final Uri url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destLat,$destLng'
          '&mode=$normalizedMode'
          '&key=${apiKey.trim()}',
        );

        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'OK' && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0] as Map<String, dynamic>;
            final legs = route['legs'] as List<dynamic>;

            if (legs.isNotEmpty) {
              final leg = legs[0] as Map<String, dynamic>;
              final int meters = (leg['distance']?['value'] as num?)?.toInt() ?? 0;
              final int seconds = (leg['duration']?['value'] as num?)?.toInt() ?? 0;

              final double distanceKm = meters / 1000.0;
              final int minutes = (seconds / 60.0).round();

              final String? overviewPolyline =
                  route['overview_polyline']?['points'] as String?;
              final List<Map<String, double>> points = overviewPolyline != null
                  ? decodePolyline(overviewPolyline)
                  : [
                      {'latitude': originLat, 'longitude': originLng},
                      {'latitude': destLat, 'longitude': destLng},
                    ];

              final result = RouteCalculationResult(
                roadDistanceKm: double.parse(distanceKm.toStringAsFixed(2)),
                estimatedTravelMinutes: minutes > 0 ? minutes : 1,
                formattedDistance: '${distanceKm.toStringAsFixed(1)} KM',
                formattedDuration: _formatMinutes(minutes > 0 ? minutes : 1),
                polylinePoints: points,
                travelMode: normalizedMode,
                isFallback: false,
              );

              _cache[cacheKey] = _RouteCacheEntry(
                result: result,
                timestamp: DateTime.now(),
              );

              return result;
            }
          }
        }
      } catch (_) {
        // Fall back gracefully below
      }
    }

    // 3. Fallback calculation using Haversine distance and real-world detour factor
    final fallbackResult = _calculateFallbackRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      travelMode: normalizedMode,
    );

    _cache[cacheKey] = _RouteCacheEntry(
      result: fallbackResult,
      timestamp: DateTime.now(),
    );

    return fallbackResult;
  }

  /// Estimates travel distance and duration when API is unreachable or omitted
  static RouteCalculationResult _calculateFallbackRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String travelMode,
  }) {
    final double straightLineDistanceKm = _calculateHaversineDistance(
      originLat,
      originLng,
      destLat,
      destLng,
    );

    // Detour coefficient for road curves in urban/suburban routes
    const double roadCurvatureFactor = 1.35;
    final double estimatedRoadDistanceKm =
        straightLineDistanceKm * roadCurvatureFactor;

    // Average speeds in km/h based on travel mode
    double averageSpeedKmPerHour;
    switch (travelMode) {
      case 'walking':
        averageSpeedKmPerHour = 4.5;
        break;
      case 'bicycling':
        averageSpeedKmPerHour = 15.0;
        break;
      case 'transit':
        averageSpeedKmPerHour = 20.0;
        break;
      case 'driving':
      default:
        averageSpeedKmPerHour = 25.0;
        break;
    }

    int minutes =
        ((estimatedRoadDistanceKm / averageSpeedKmPerHour) * 60).round();
    if (minutes < 1 && estimatedRoadDistanceKm > 0.05) {
      minutes = 1;
    }

    return RouteCalculationResult(
      roadDistanceKm: double.parse(estimatedRoadDistanceKm.toStringAsFixed(2)),
      estimatedTravelMinutes: minutes,
      formattedDistance: '${estimatedRoadDistanceKm.toStringAsFixed(1)} KM',
      formattedDuration: _formatMinutes(minutes),
      polylinePoints: [
        {'latitude': originLat, 'longitude': originLng},
        {'latitude': destLat, 'longitude': destLng},
      ],
      travelMode: travelMode,
      isFallback: true,
    );
  }

  /// Decodes Google's encoded polyline format string into a list of latitude/longitude pairs
  static List<Map<String, double>> decodePolyline(String encoded) {
    final List<Map<String, double>> poly = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add({
        'latitude': lat / 1e5,
        'longitude': lng / 1e5,
      });
    }

    return poly;
  }

  static double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  static String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    }
    final int hours = minutes ~/ 60;
    final int remainingMins = minutes % 60;
    return remainingMins == 0 ? '$hours hr' : '$hours hr $remainingMins mins';
  }
}