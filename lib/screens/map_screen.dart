import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/teacher.dart';
import 'teacher_profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController; // Nullable for safety

  // Dhaka, Bangladesh as default center
  final LatLng _initialCenter = const LatLng(23.8103, 90.4125); 

  // Dummy Data (In future, fetch this from Firestore)
  final List<Teacher> teachers = [
    Teacher(id: '1', name: 'Mr. Rahim', lat: 23.8103, lng: 90.4125),
    Teacher(id: '2', name: 'Ms. Karim', lat: 23.8125, lng: 90.4147),
    Teacher(id: '3', name: 'Dr. Anika', lat: 23.8150, lng: 90.4100),
  ];

  @override
  void dispose() {
    _mapController?.dispose(); // Clean up controller memory
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Optional: Auto-zoom to fit all teachers on screen
    _fitAllMarkers();
  }

  void _fitAllMarkers() {
    if (teachers.isEmpty || _mapController == null) return;

    // Logic to calculate bounds (so all teachers are visible)
    // For now, let's keep it simple.
  }

  Set<Marker> _buildMarkers() {
    return teachers.map((teacher) {
      return Marker(
        markerId: MarkerId(teacher.id),
        position: LatLng(teacher.lat, teacher.lng),
        // Customizing the marker feel
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), 
        infoWindow: InfoWindow(
          title: teacher.name,
          snippet: "Tap to view profile", // Added helpful text
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeacherProfileScreen(teacher: teacher),
              ),
            );
          },
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find Nearby Teachers',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent, // More modern color
        elevation: 2,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialCenter,
          zoom: 13.0,
        ),
        markers: _buildMarkers(),
        myLocationEnabled: true, // Show user's own location
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false, // Cleaner UI
        mapType: MapType.normal,
      ),
      // Floating button to reset view to center
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_initialCenter, 13),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
