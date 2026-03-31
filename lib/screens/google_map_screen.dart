import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? mapController;
  final Map<MarkerId, Marker> _markers = {};
  LatLng? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  Future<void> _initializeMapData() async {
    await _fetchUserLocation();
    await _loadTeacherMarkers();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          
          // Adding User's own marker
          const markerId = MarkerId('me');
          _markers[markerId] = Marker(
            markerId: markerId,
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  Future<void> _loadTeacherMarkers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teachers').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final teacherId = doc.id;
        final teacherName = data['name'] ?? 'Teacher';

        if (data.containsKey('locations') && data['locations'] is List) {
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
                    if (mounted) {
                      Navigator.pushNamed(
                        context,
                        '/teacherProfile',
                        arguments: {'teacherId': teacherId},
                      );
                    }
                  },
                ),
              );

              if (mounted) {
                setState(() {
                  _markers[markerId] = marker;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading markers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Teachers Nearby'),
        centerTitle: true,
      ),
      body: _isLoading || _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 14.0,
              ),
              markers: Set<Marker>.from(_markers.values),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
            ),
    );
  }
}
