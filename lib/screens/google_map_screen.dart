import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({Key? key}) : super(key: key);

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  late GoogleMapController mapController;
  final Map<MarkerId, Marker> _markers = {};
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    _loadTeacherMarkers();
  }

  Future<void> _fetchUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _loadTeacherMarkers() async {
  final snapshot = await FirebaseFirestore.instance.collection('teachers').get();

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final teacherId = doc.id;
    final teacherName = data['name'] ?? 'Unnamed Teacher';

    if (data.containsKey('locations')) {
      final List locations = data['locations'];

      for (int i = 0; i < locations.length; i++) {
        final loc = locations[i];
        if (loc['latitude'] != null && loc['longitude'] != null) {
          final markerId = MarkerId('$teacherId-$i');

          final marker = Marker(
            markerId: markerId,
            position: LatLng(loc['latitude'], loc['longitude']),
            infoWindow: InfoWindow(
              title: teacherName,
              snippet: 'Tap to view profile',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/teacherProfile',
                  arguments: {'teacherId': teacherId},
                );
              },
            ),
          );

          setState(() {
            _markers[markerId] = marker;
          });
        }
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Teachers')),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 14.0,
              ),
              markers: Set<Marker>.of(_markers.values)
                ..add(
                  Marker(
                    markerId: const MarkerId('me'),
                    position: _currentPosition!,
                    infoWindow: const InfoWindow(title: 'You are here'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  ),
                ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}