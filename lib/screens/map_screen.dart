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
  late GoogleMapController mapController;

  final LatLng _center = const LatLng(23.8103, 90.4125); // Dhaka, Bangladesh

  final List<Teacher> teachers = [
    Teacher(id: '1', name: 'Mr. Rahim', lat: 23.8103, lng: 90.4125),
    Teacher(id: '2', name: 'Ms. Karim', lat: 23.8125, lng: 90.4147),
    Teacher(id: '3', name: 'Dr. Anika', lat: 23.8150, lng: 90.4100),
  ];

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Set<Marker> _buildMarkers() {
    return teachers.map((teacher) {
      return Marker(
        markerId: MarkerId(teacher.id),
        position: LatLng(teacher.lat, teacher.lng),
        infoWindow: InfoWindow(
          title: teacher.name,
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
        title: const Text('Find Your Best Teacher'),
        backgroundColor: Colors.green[700],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 12.0,
        ),
        markers: _buildMarkers(),
      ),
    );
  }
}