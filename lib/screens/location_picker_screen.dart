import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  List<LatLng> selectedLocations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Multiple Locations'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, selectedLocations);
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(23.777176, 90.399452), // Default Dhaka
          zoom: 13,
        ),
        onTap: (LatLng pos) {
          setState(() {
            selectedLocations.add(pos);
          });
        },
        markers: selectedLocations
            .asMap()
            .entries
            .map(
              (entry) => Marker(
                markerId: MarkerId('loc_${entry.key}'),
                position: entry.value,
              ),
            )
            .toSet(),
      ),
      bottomNavigationBar: selectedLocations.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Selected: ${selectedLocations.length} location(s)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}