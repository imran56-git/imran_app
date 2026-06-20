import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {

  /// Get Current Location
  static Future<Position> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return Future.error('GPS_DISABLED');
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          return Future.error('PERMISSION_DENIED');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return Future.error(
            'PERMISSION_PERMANENTLY_DENIED');
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


  /// Live Location Tracking
  static Stream<Position> getLiveLocationStream() {

    const LocationSettings settings =
        LocationSettings(
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

      Position position =
          await getCurrentLocation();

      return
      '${position.latitude.toStringAsFixed(6)}, '
      '${position.longitude.toStringAsFixed(6)}';

    } catch (e) {

      return "Location Unavailable";

    }
  }


  /// Distance Calculation
  static double getDistanceBetween(
      double startLat,
      double startLng,
      double endLat,
      double endLng) {

    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }


  /// Distance KM Format
  static String getDistanceInKm(
      double startLat,
      double startLng,
      double endLat,
      double endLng) {

    double distance =
        getDistanceBetween(
          startLat,
          startLng,
          endLat,
          endLng,
        );


    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)}m away";
    }

    return
    "${(distance / 1000).toStringAsFixed(1)}km away";
  }
}