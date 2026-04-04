import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  
  /// --- Core Feature: Get Single Current Position ---
  /// Optimized with a timeout to prevent infinite loading.
  Future<Position> getCurrentLocation() async {
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

      // Advanced: Using LocationSettings for better platform-specific behavior
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Updates only if moved 10 meters
      );

      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      ).timeout(const Duration(seconds: 12));

    } catch (e) {
      return Future.error('SYSTEM_ERROR: $e');
    }
  }

  /// --- Advanced Feature: Live Location Tracking ---
  /// This is essential for "Live Classes" or seeing teachers moving on a map.
  Stream<Position> getLiveLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Triggers update every 5 meters
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// --- Professional Helper: Get Formatted String ---
  Future<String> getFormattedLocation() async {
    try {
      Position position = await getCurrentLocation();
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      return "Location Unavailable";
    }
  }

  /// --- Distance Calculation (Teacher-Student Proximity) ---
  /// Returns distance in Meters
  double getDistanceBetween(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// --- Advanced Feature: Distance in KM Helper ---
  String getDistanceInKm(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = getDistanceBetween(startLat, startLng, endLat, endLng);
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.toStringAsFixed(0)}m away";
    } else {
      double distanceInKm = distanceInMeters / 1000;
      return "${distanceInKm.toStringAsFixed(1)}km away";
    }
  }
}