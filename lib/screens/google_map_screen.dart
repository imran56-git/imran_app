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
  final Completer<GoogleMapController> _controller = Completer();
  final Map<MarkerId, Marker> _markers = {};

  // Default position (Kolkata Center default fallback)
  LatLng _initialPosition = const LatLng(22.5726, 88.3639); 
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

  // --- Fetch User Location with Safe 2-Minute Timeout & Fallback ---
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
      // ১২ সেকেন্ডের জায়গায় ২ মিনিট (120 sec) টাইমআউট সেট করা হলো
      Position? position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () async {
          // টাইমআউট হলে লাস্ট নোউন লোকেশন ট্রাই করবে
          return await Geolocator.getLastKnownPosition() ??
              Position(
                longitude: _initialPosition.longitude,
                latitude: _initialPosition.latitude,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
        },
      );

      _initialPosition = LatLng(position.latitude, position.longitude);

      // Animate camera to user position safely
      if (_controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 14.0));
      }

    } catch (e) {
      debugPrint("Location detection handled safely: $e");
    }
  }

  // --- Optimized Crash-Proof Teacher Loader ---
  Future<void> _loadTeachersFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teachers').get();
      Map<MarkerId, Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String teacherId = doc.id;
        final String name = data['name'] ?? data['displayName'] ?? 'Teacher';

        if (data['locations'] != null && data['locations'] is List) {
          List locations = data['locations'];
          for (int i = 0; i < locations.length; i++) {
            var loc = locations[i];
            
            final double? lat = double.tryParse(loc['latitude']?.toString() ?? '');
            final double? lng = double.tryParse(loc['longitude']?.toString() ?? '');

            if (lat != null && lng != null) {
              final markerId = MarkerId('$teacherId-$i');

              final marker = Marker(
                markerId: markerId,
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: loc['address'] ?? "Click to view profile",
                  onTap: () => _navigateToProfile(teacherId),
                ),
              );
              newMarkers[markerId] = marker;
            }
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
    if (!mounted) return;
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
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
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
