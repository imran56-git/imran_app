import 'package:geolocator/geolocator.dart';

class LocationService {
  
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // সহজে latitude ও longitude স্ট্রিং হিসেবে ফেরত দেয়
  Future<String> getFormattedLocation() async {
    Position position = await getCurrentLocation();
    return '${position.latitude}, ${position.longitude}';
  }
}