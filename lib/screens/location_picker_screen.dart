import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Maintaining your original list of selected locations
  final List<LatLng> selectedLocations = [];

  // This handles the tap event from your original logic
  void _onMapTap(LatLng position) {
    setState(() {
      selectedLocations.add(position);
    });
  }

  // Added this to allow users to fix mistakes by tapping the marker
  void _removeLocation(int index) {
    setState(() {
      selectedLocations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Multiple Locations'),
        centerTitle: true,
        actions: [
          // Keeping your original logic to return the list to the previous screen
          IconButton(
            icon: const Icon(Icons.check, size: 30),
            onPressed: () {
              Navigator.pop(context, selectedLocations);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(22.5726, 88.3639), // Focused on your region
              zoom: 13,
            ),
            onTap: _onMapTap,
            // Your original marker mapping logic, now with a removal feature
            markers: selectedLocations.asMap().entries.map((entry) {
              int idx = entry.key;
              LatLng pos = entry.value;
              return Marker(
                markerId: MarkerId('loc_$idx'),
                position: pos,
                infoWindow: InfoWindow(
                  title: "Location ${idx + 1}",
                  snippet: "Tap here to remove",
                  onTap: () => _removeLocation(idx),
                ),
              );
            }).toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          // Helpful guide for the user
          if (selectedLocations.isEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Tap on the map to select your teaching areas.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      // Your original bottom counter logic
      bottomNavigationBar: selectedLocations.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected: ${selectedLocations.length} location(s)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Click check to save",
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
