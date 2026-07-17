import 'dart:async';
import 'dart:math' as math;
// ফিক্সড: বিল্ড লগের ১ম এরর অনুযায়ী ইমপোর্টের শেষে সঠিকভাবে .dart যুক্ত করা হলো
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  /// Get Current Location
  static Future<Position> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('GPS_DISABLED');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('PERMISSION_DENIED');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return Future.error('PERMISSION_PERMANENTLY_DENIED');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 12),
      );
    } catch (e) {
      return Future.error('SYSTEM_ERROR: $e');
    }
  }

  /// Get Only Latitude & Longitude
  /// For Teacher / Student Registration
  static Future<Map<String, double>> getLocationCoordinates() async {
    Position position = await getCurrentLocation();
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }

  /// Live Location Tracking
  /// Future use for live map tracking
  static Stream<Position> getLiveLocationStream() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  /// Get Latitude Longitude String
  static Future<String> getFormattedLocation() async {
    try {
      Position position = await getCurrentLocation();
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      return "Location Unavailable";
    }
  }

  /// Distance Calculation using Geolocator
  /// Returns distance in meters
  static double getDistanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }

  /// Haversine Formula Implementation
  /// Returns distance in Kilometers (KM)
  /// Used for strict Radius verification in Search Logic
  static double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Distance KM Format for UI display
  static String getDistanceInKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    double distance = getDistanceBetween(startLat, startLng, endLat, endLng);

    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)}m away";
    }

    return "${(distance / 1000).toStringAsFixed(1)}km away";
  }

  /// Open external Google Maps Application with Teacher Location
  /// Launches direct navigation/view for the student
  static Future<void> openGoogleMapsApp(double latitude, double longitude) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch Google Maps Application";
      }
    } catch (e) {
      // Fallback fallback if external app launch fails
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
