import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Store location data as Objects for profile integration
  final List<Map<String, dynamic>> selectedLocations = [];
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  // Search location by text
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(locations.first.latitude, locations.first.longitude),
            14,
          ),
        );
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  // Handle Map Tap and Reverse Geocoding
  Future<void> _onMapTap(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = "Unknown Area";
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        address = "${place.subLocality ?? ''} ${place.locality ?? ''}".trim();
        if (address.isEmpty) address = place.name ?? "Point ${selectedLocations.length + 1}";
      }

      setState(() {
        selectedLocations.add({
          'lat': position.latitude,
          'lng': position.longitude,
          'address': address,
        });
      });
    } catch (e) {
      setState(() {
        selectedLocations.add({
          'lat': position.latitude,
          'lng': position.longitude,
          'address': "Location ${selectedLocations.length + 1}",
        });
      });
    }
  }

  void _removeLocation(int index) {
    setState(() {
      selectedLocations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Teaching Areas'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle, size: 28),
            onPressed: () => Navigator.pop(context, selectedLocations),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(22.5726, 88.3639), // Default: Kolkata region
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: selectedLocations.asMap().entries.map((entry) {
              int idx = entry.key;
              var data = entry.value;
              return Marker(
                markerId: MarkerId('loc_$idx'),
                position: LatLng(data['lat'], data['lng']),
                infoWindow: InfoWindow(
                  title: data['address'],
                  snippet: "Tap to remove",
                  onTap: () => _removeLocation(idx),
                ),
              );
            }).toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          
          // Floating Search Bar
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(30),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search area (e.g. Salt Lake)",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _searchLocation(_searchController.text),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: _searchLocation,
              ),
            ),
          ),

          // Selection Guide
          if (selectedLocations.isEmpty)
            Positioned(
              bottom: 100,
              left: 50,
              right: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Tap map to pin teaching locations",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: selectedLocations.isNotEmpty
          ? Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedLocations.length} Locations Selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Text("Addresses mapped successfully", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => selectedLocations.clear()),
                    child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          : null,
    );
  }
}
