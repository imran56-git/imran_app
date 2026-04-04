import 'dart:async';
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
  Completer<GoogleMapController> _controller = Completer();
  final Map<MarkerId, Marker> _markers = {};
  
  // Default position (e.g., City Center) if location is denied
  LatLng _initialPosition = const LatLng(23.8103, 90.4125); 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  // --- Main Initialization ---
  Future<void> _initializeMap() async {
    await _determineUserPosition();
    await _loadTeachersFromFirestore();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Fetch User Location with Error Handling ---
  Future<void> _determineUserPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar("Permissions are permanently denied. Enable them in settings.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      _initialPosition = LatLng(position.latitude, position.longitude);
      
      // Animate camera to user position
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 14.0));

    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  // --- Optimized Teacher Loader ---
  Future<void> _loadTeachersFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teachers').get();
      Map<MarkerId, Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String teacherId = doc.id;
        final String name = data['name'] ?? 'Teacher';

        if (data['locations'] != null && data['locations'] is List) {
          List locations = data['locations'];
          for (int i = 0; i < locations.length; i++) {
            var loc = locations[i];
            final markerId = MarkerId('$teacherId-$i');

            final marker = Marker(
              markerId: markerId,
              position: LatLng(loc['latitude'], loc['longitude']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: name,
                snippet: "Click to view profile",
                onTap: () => _navigateToProfile(teacherId),
              ),
            );
            newMarkers[markerId] = marker;
          }
        }
      }

      if (mounted) {
        setState(() {
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      debugPrint("Firestore load error: $e");
    }
  }

  void _navigateToProfile(String teacherId) {
    Navigator.pushNamed(
      context,
      '/teacherProfile',
      arguments: {'teacherId': teacherId},
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers Map', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 12.0,
            ),
            markers: Set<Marker>.from(_markers.values),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false, // Custom UI often hides these
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
          if (_isLoading)
            const Center(
              child: Card(
                elevation: 5,
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Color(0xFF128C7E)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.black),
        onPressed: _determineUserPosition,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
