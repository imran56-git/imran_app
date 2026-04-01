import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches the current geographic position of the device.
  /// Handles service status, permissions, and potential errors.
  Future<Position> getCurrentLocation() async {
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Location services are disabled. Please enable GPS.');
      }

      // 2. Check and handle location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied.');
        }
      }

      // 3. Handle permanent denial
      if (permission == LocationPermission.deniedForever) {
        return Future.error(
          'Location permissions are permanently denied. We cannot request permissions.'
        );
      }

      // 4. Fetch position with high accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Added timeout for better UX
      );
      
    } catch (e) {
      return Future.error('Error occurred while fetching location: $e');
    }
  }

  /// Returns a formatted string of "Latitude, Longitude"
  Future<String> getFormattedLocation() async {
    try {
      Position position = await getCurrentLocation();
      return '${position.latitude}, ${position.longitude}';
    } catch (e) {
      return "Location unavailable";
    }
  }

  /// Advanced Feature: Check distance between two points (Useful for Teacher-Student proximity)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
