import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
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

      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 15),
      );
    } catch (e) {
      return Future.error('SYSTEM_ERROR: $e');
    }
  }

  static Future<Map<String, double>> getLocationCoordinates() async {
    Position position = await getCurrentLocation();
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }

  static Stream<Position> getLiveLocationStream() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  static Future<String> getFormattedLocation() async {
    try {
      Position position = await getCurrentLocation();
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      return "Location Unavailable";
    }
  }

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

  static Future<void> openGoogleMapsApp(double latitude, double longitude) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  /// Uses the geocoding package to return a human-readable formatted address from coordinates.
  /// Falls back to coordinate string if geocoding fails.
  static Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final List<String> addressParts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  /// Geocodes an address string back into latitude and longitude coordinates.
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      final List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Generates a standard base32 geohash string for spatial indexing.
  static String generateGeohash(double latitude, double longitude, {int precision = 9}) {
    const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    double minLat = -90.0, maxLat = 90.0;
    double minLng = -180.0, maxLng = 180.0;

    final StringBuffer geohash = StringBuffer();
    bool isEvenBit = true;
    int bit = 0;
    int ch = 0;

    while (geohash.length < precision) {
      if (isEvenBit) {
        final double midLng = (minLng + maxLng) / 2.0;
        if (longitude > midLng) {
          ch |= (1 << (4 - bit));
          minLng = midLng;
        } else {
          maxLng = midLng;
        }
      } else {
        final double midLat = (minLat + maxLat) / 2.0;
        if (latitude > midLat) {
          ch |= (1 << (4 - bit));
          minLat = midLat;
        } else {
          maxLat = midLat;
        }
      }

      isEvenBit = !isEvenBit;

      if (bit < 4) {
        bit++;
      } else {
        geohash.write(base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return geohash.toString();
  }

  /// Saves or updates the student's home location under Firestore `students/$studentId/savedLocations/home`.
  static Future<void> saveStudentHomeLocation({
    required String studentId,
    required String locationName,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final String hash = generateGeohash(latitude, longitude);
    final String resolvedAddress = address ?? await getAddressFromCoordinates(latitude, longitude);

    await FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .collection('savedLocations')
        .doc('home')
        .set({
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'address': resolvedAddress,
      'geohash': hash,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetches the student's saved home location from Firestore.
  static Future<Map<String, dynamic>?> getStudentHomeLocation(String studentId) async {
    try {
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('savedLocations')
          .doc('home')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Launches Google Maps turn-by-turn navigation with fallback to web directions.
  static Future<void> launchNavigationDirections({
    required double destLat,
    required double destLng,
    String travelMode = 'driving',
  }) async {
    String navMode = 'd';
    if (travelMode == 'walking') {
      navMode = 'w';
    } else if (travelMode == 'transit') {
      navMode = 'r';
    } else if (travelMode == 'bicycling') {
      navMode = 'b';
    }

    final Uri nativeUri = Uri.parse('google.navigation:q=$destLat,$destLng&mode=$navMode');
    final Uri webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=$travelMode',
    );

    try {
      final bool canLaunchNative = await canLaunchUrl(nativeUri);
      if (canLaunchNative) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final bool launchedWeb = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!launchedWeb) {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(webUri);
      } catch (_) {}
    }
  }
}