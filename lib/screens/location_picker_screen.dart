import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> selectedLocations = [];
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  bool _isSearching = false;
  bool _isLoadingLocation = false;

  LatLng _currentCenterPosition = const LatLng(22.5726, 88.3639); // Default Kolkata
  String _draggedAddress = "Loading address...";
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _getUserCurrentLocation(moveToPosition: true);
  }

  /// Get user's active device location automatically
  Future<void> _getUserCurrentLocation({bool moveToPosition = false}) async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (moveToPosition && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(currentLatLng, 14),
        );
      }
      _currentCenterPosition = currentLatLng;
      _updateAddressFromPosition(currentLatLng);
    } catch (e) {
      _showSnackBar("Could not detect location: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  /// Search Location using Geocoding
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final position = LatLng(locations.first.latitude, locations.first.longitude);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(position, 14),
        );
        _currentCenterPosition = position;
        await _updateAddressFromPosition(position);
      }
    } catch (e) {
      _showSnackBar('Location not found. Please try another specific name.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Reverse Geocode Address Update
  Future<void> _updateAddressFromPosition(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String name = place.name ?? "";
        String subLocality = place.subLocality ?? "";
        String locality = place.locality ?? "";
        String subAdministrativeArea = place.subAdministrativeArea ?? "";

        String formatted = "$name, $subLocality, $locality, $subAdministrativeArea"
            .replaceAll(RegExp(r', ,|,,'), ',')
            .trim();

        if (formatted.startsWith(',') || formatted.isEmpty) {
          formatted = "${place.subLocality ?? ''} ${place.locality ?? ''}".trim();
        }

        setState(() {
          _draggedAddress = formatted.isEmpty ? "Unknown Location" : formatted;
        });
      }
    } catch (e) {
      setState(() {
        _draggedAddress = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      });
    }
  }

  /// Single Pin Tapping Logic
  void _addCurrentPositionAsArea() {
    // ডাটাবেজ আর্কিটেকচারের সাথে মিলিয়ে 'latitude' এবং 'longitude' করা হয়েছে
    bool exists = selectedLocations.any((loc) => 
      (loc['latitude'] as double).toStringAsFixed(4) == _currentCenterPosition.latitude.toStringAsFixed(4) &&
      (loc['longitude'] as double).toStringAsFixed(4) == _currentCenterPosition.longitude.toStringAsFixed(4)
    );

    if (!exists) {
      setState(() {
        selectedLocations.add({
          'latitude': _currentCenterPosition.latitude,
          'longitude': _currentCenterPosition.longitude,
          'address': _draggedAddress,
          'locationName': _draggedAddress.split(',').first, // কাস্টম জোন নেম জেনারেট করার জন্য
        });
      });
      _showSnackBar("Area Added Successfully!");
    } else {
      _showSnackBar("This area is already added!");
    }
  }

  void _removeLocation(int index) {
    setState(() {
      selectedLocations.removeAt(index);
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.blueGrey[900],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Circle> mapCircles = selectedLocations.map((loc) {
      return Circle(
        circleId: CircleId('circle_${loc['latitude']}_${loc['longitude']}'),
        center: LatLng(loc['latitude'], loc['longitude']),
        radius: 10000, // 10 KM Radius
        fillColor: Colors.blue.withOpacity(0.12),
        strokeColor: Colors.blue[700]!,
        strokeWidth: 2,
      );
    }).toSet();

    mapCircles.add(
      Circle(
        circleId: const CircleId('current_center_radius'),
        center: _currentCenterPosition,
        radius: 10000, // 10 KM
        fillColor: Colors.amber.withOpacity(0.06),
        strokeColor: Colors.amber[700]!.withOpacity(0.4),
        strokeWidth: 1,
      )
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          /// 1. Google Maps SDK Widget
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenterPosition,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _getUserCurrentLocation(moveToPosition: true);
            },
            onCameraMoveStarted: () {
              setState(() {
                _isDragging = true;
              });
            },
            onCameraMove: (CameraPosition position) {
              _currentCenterPosition = position.target;
            },
            onCameraIdle: () async {
              setState(() {
                _isDragging = false;
              });
              await _updateAddressFromPosition(_currentCenterPosition);
            },
            markers: selectedLocations.asMap().entries.map((entry) {
              int idx = entry.key;
              var data = entry.value;
              return Marker(
                markerId: MarkerId('teaching_idx_$idx'),
                position: LatLng(data['latitude'], data['longitude']),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: data['address'],
                  snippet: "Tap to view options",
                ),
              );
            }).toSet(),
            circles: mapCircles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          /// 2. Custom Center Floating Pointer (Pin)
          Center(
            child: Padding(
              padding: const EdgeInsets.bottom: 40.0,
              child: Icon(
                Icons.location_on_rounded, 
                size: 46, 
                color: _isDragging ? Colors.amber[800] : Colors.blue[900]
              )
              .animate(target: _isDragging ? 1 : 0)
              .scaleXY(end: 1.2, curve: Curves.easeOut)
              .view(),
            ),
          ),

          /// 3. Top Floating Search Box Widget
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black80),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _searchLocation,
                      decoration: InputDecoration(
                        hintText: "Search teaching hub area...",
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                  _isSearching 
                      ? const Padding(
                          padding: EdgeInsets.all(14.0),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search_rounded, color: Colors.black80),
                          onPressed: () => _searchLocation(_searchController.text),
                        ),
                ],
              ),
            ),
          ),

          /// 4. Center-Right Quick Floating Controls
          Positioned(
            right: 16,
            bottom: selectedLocations.isNotEmpty ? 240 : 200,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "my_loc_btn",
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[900],
                  elevation: 6,
                  mini: true,
                  onPressed: () => _getUserCurrentLocation(moveToPosition: true),
                  child: _isLoadingLocation 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 20),
                ),
              ],
            ),
          ),

          /// 5. Live Address Feedback & Active Action Bottom Sheet Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.streetview_rounded, color: Colors.amber[700], size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Target Area Selection Pointer", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              _isDragging ? "Locating..." : _draggedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isDragging ? null : _addCurrentPositionAsArea,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          elevation: 0,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_location_alt_rounded, size: 16),
                            SizedBox(width: 4),
                            Text("Pin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 1.0, duration: 300.ms, curve: Curves.easeOut),

                if (selectedLocations.isNotEmpty)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 25, offset: const Offset(0, -6))],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${selectedLocations.length} Custom Hub Areas',
                                    style: const TextStyle(fontWeight: FontWeight.extrabold, fontSize: 16, color: Color(0xFF1E293B)),
                                  ),
                                  const Text("10 KM covers student matching automatically", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              TextButton(
                                onPressed: () => setState(() => selectedLocations.clear()),
                                child: const Text("Clear All", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: selectedLocations.length,
                            itemBuilder: (context, index) {
                              final item = selectedLocations[index];
                              return Container(
                                width: 230,
                                margin: const EdgeInsets.only(right: 12, bottom: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue.shade50, width: 1.5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.blue[700], size: 18),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              item['address'].toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("📍 Radius: 10 KM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey)),
                                          InkWell(
                                            onTap: () => _removeLocation(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                              child: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[700]),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[600],
                                foregroundColor: Colors.black, // টাইপো ফিক্সড
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.pop(context, selectedLocations);
                              },
                              child: const Text("Save Active Teaching Areas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        )
                      ],
                    ),
                  ).animate().slideY(begin: 0.5, duration: 250.ms),
              ],
            ),
          )
        ],
      ),
    );
  }
}