import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/teacher_location_model.dart';
import '../services/google_maps_route_service.dart';
import '../services/location_service.dart';
import 'location_batch_schedule_screen.dart';

class MapScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const MapScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _emerald = Color(0xFF059669);
  static const Color _slateBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final List<TeacherLocationModel> _locationsList = [];

  bool _isLoading = true;
  TeacherLocationModel? _selectedLocation;
  bool _showDetailsCard = false;

  // Real-time Road Distance & Commute
  String? _roadDistanceText;
  String? _travelTimeText;
  bool _isCalculatingRoute = false;

  MapType _currentMapType = MapType.normal;

  // Default Position (Kolkata Center fallback)
  LatLng _userPosition = const LatLng(22.5726, 88.3639);

  final GoogleMapsRouteService _routeService = GoogleMapsRouteService();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMapData() async {
    await _getUserCurrentLocationSafely();
    await _fetchTeacherLocations();
  }

  Future<void> _getUserCurrentLocationSafely() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          _userPosition = LatLng(loc.latitude, loc.longitude);
        });
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () async {
          return await Geolocator.getLastKnownPosition() ??
              Position(
                latitude: _userPosition.latitude,
                longitude: _userPosition.longitude,
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

      if (mounted) {
        setState(() {
          _userPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint("MapScreen location initialization: $e");
    }
  }

  Future<void> _fetchTeacherLocations() async {
    try {
      _locationsList.clear();
      _markers.clear();

      // 1. Primary: Sub-collection 'teachingLocations'
      final subColSnapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .collection('teachingLocations')
          .where('isDeleted', isNotEqualTo: true)
          .get();

      if (subColSnapshot.docs.isNotEmpty) {
        for (final doc in subColSnapshot.docs) {
          final data = doc.data();
          final loc = _parseLocationModel(data, doc.id);
          if (loc.latitude != 0.0 && loc.longitude != 0.0) {
            _locationsList.add(loc);
          }
        }
      }

      // 2. Fallback: Main teacher doc 'locations' dynamic array
      if (_locationsList.isEmpty) {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.teacherId)
            .get();

        if (teacherDoc.exists) {
          final data = teacherDoc.data() ?? {};
          final List<dynamic> legacyLocs = data['locations'] ?? [];

          for (int i = 0; i < legacyLocs.length; i++) {
            final item = legacyLocs[i];
            if (item is Map<String, dynamic>) {
              final loc = _parseLocationModel(item, 'legacy_$i');
              if (loc.latitude != 0.0 && loc.longitude != 0.0) {
                _locationsList.add(loc);
              }
            }
          }
        }
      }

      // 3. Build Interactive Markers
      for (int i = 0; i < _locationsList.length; i++) {
        final loc = _locationsList[i];
        final LatLng markerPos = LatLng(loc.latitude, loc.longitude);

        _markers.add(
          Marker(
            markerId: MarkerId(loc.id.isNotEmpty ? loc.id : 'loc_$i'),
            position: markerPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              loc.locationType == 'home_tuition'
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: loc.locationName,
              snippet: loc.address,
            ),
            onTap: () => _onMarkerTapped(loc),
          ),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (_locationsList.isNotEmpty && _mapController != null) {
          _fitAllLocationsBounds();
        }
      }
    } catch (e) {
      debugPrint("Error fetching teaching locations for map: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TeacherLocationModel _parseLocationModel(Map<String, dynamic> data, String id) {
    try {
      return TeacherLocationModel.fromMap(data, id: id);
    } catch (_) {
      return TeacherLocationModel(
        id: id,
        teacherId: widget.teacherId,
        locationName: (data['locationName'] ?? data['name'] ?? 'Teaching Centre').toString(),
        locationType: (data['locationType'] ?? 'tuition_centre').toString(),
        address: (data['address'] ?? 'Address not specified').toString(),
        latitude: double.tryParse(data['latitude']?.toString() ?? '') ??
            double.tryParse(data['lat']?.toString() ?? '') ??
            0.0,
        longitude: double.tryParse(data['longitude']?.toString() ?? '') ??
            double.tryParse(data['lng']?.toString() ?? '') ??
            0.0,
        teachingMode: (data['teachingMode'] ?? 'offline').toString(),
        verificationStatus: data['verificationStatus']?.toString(),
        createdAt: DateTime.now(),
      );
    }
  }

  void _onMarkerTapped(TeacherLocationModel location) async {
    setState(() {
      _selectedLocation = location;
      _showDetailsCard = true;
      _isCalculatingRoute = true;
      _roadDistanceText = null;
      _travelTimeText = null;
    });

    // Center camera smoothly on tapped marker
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.latitude, location.longitude),
          zoom: 15.0,
        ),
      ),
    );

    // Calculate real road distance and driving duration
    try {
      final routeDetails = await _routeService.getRouteDetails(
        originLat: _userPosition.latitude,
        originLng: _userPosition.longitude,
        destLat: location.latitude,
        destLng: location.longitude,
      );

      if (mounted && _selectedLocation?.id == location.id) {
        if (routeDetails != null) {
          setState(() {
            _roadDistanceText = '${routeDetails.distanceKm.toStringAsFixed(1)} KM';
            _travelTimeText = '${routeDetails.durationMinutes} mins driving';
            _isCalculatingRoute = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback: Haversine computation
    if (mounted && _selectedLocation?.id == location.id) {
      final straightKm = _calculateHaversine(
        _userPosition.latitude,
        _userPosition.longitude,
        location.latitude,
        location.longitude,
      );
      final roadKm = straightKm * 1.25;
      final minutes = (roadKm / 24.0 * 60).round().clamp(2, 180);

      setState(() {
        _roadDistanceText = '${roadKm.toStringAsFixed(1)} KM';
        _travelTimeText = '$minutes mins road travel';
        _isCalculatingRoute = false;
      });
    }
  }

  double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_locationsList.isNotEmpty) {
      _fitAllLocationsBounds();
    }
  }

  void _fitAllLocationsBounds() {
    if (_locationsList.isEmpty || _mapController == null) return;

    if (_locationsList.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_locationsList.first.latitude, _locationsList.first.longitude),
          14.5,
        ),
      );
      return;
    }

    double minLat = _locationsList.first.latitude;
    double maxLat = _locationsList.first.latitude;
    double minLng = _locationsList.first.longitude;
    double maxLng = _locationsList.first.longitude;

    for (var loc in _locationsList) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLng) minLng = loc.longitude;
      if (loc.longitude > maxLng) maxLng = loc.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  void _centerOnUserPosition() {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_userPosition, 14.5),
    );
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  Future<void> _launchGoogleMapsNavigation(double lat, double lng) async {
    final Uri googleMapsAppUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    final Uri googleMapsWebUrl =
        Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    try {
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(googleMapsWebUrl)) {
        await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps application.';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Could not open navigation application"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  String _formatLocationType(String type) {
    switch (type.toLowerCase()) {
      case 'tuition_centre':
        return 'Tuition Centre';
      case 'institute':
        return 'Institute';
      case 'home_tuition':
        return 'Home Tuition Base';
      case 'school':
        return 'School Campus';
      default:
        return 'Teaching Zone';
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = _locationsList.isNotEmpty
        ? LatLng(_locationsList.first.latitude, _locationsList.first.longitude)
        : _userPosition;

    return Scaffold(
      backgroundColor: _slateBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Teaching Centres & Map',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${widget.teacherName} • ${_locationsList.length} Venue${_locationsList.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_navy, Color(0xFF1E3A8A), _brandBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _brandBlue,
                    strokeWidth: 3,
                  ),
                )
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: initialTarget, zoom: 12.5),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  mapType: _currentMapType,
                  onTap: (_) {
                    if (_showDetailsCard) {
                      setState(() => _showDetailsCard = false);
                    }
                  },
                ),

          // Floating Control Buttons (Top Right Stack)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                _buildMapControlButton(
                  icon: _currentMapType == MapType.normal
                      ? Icons.layers_outlined
                      : Icons.map_outlined,
                  tooltip: 'Toggle Map Mode',
                  onTap: _toggleMapType,
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.crop_free_rounded,
                  tooltip: 'Fit All Locations',
                  onTap: _fitAllLocationsBounds,
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My Location',
                  onTap: _centerOnUserPosition,
                ),
              ],
            ),
          ),

          // Interactive Sliding Bottom Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            bottom: _showDetailsCard ? 20 : -320,
            left: 16,
            right: 16,
            child: _selectedLocation == null
                ? const SizedBox.shrink()
                : _buildBottomLocationCard(_selectedLocation!),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: _navy, size: 20),
        ),
      ),
    );
  }

  Widget _buildBottomLocationCard(TeacherLocationModel loc) {
    final bool isVerified = loc.verificationStatus == 'verified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            offset: Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _brandBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _brandBlue.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      _formatLocationType(loc.locationType),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _brandBlue,
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, size: 12, color: _emerald),
                          SizedBox(width: 3),
                          Text(
                            'Verified Venue',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: () => setState(() => _showDetailsCard = false),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: _mutedSlate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            loc.locationName,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: _navy,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_outlined, size: 14, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  loc.address,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _mutedSlate,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route and Commute Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _slateBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 14, color: _accentBlue),
                const SizedBox(width: 6),
                _isCalculatingRoute
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _brandBlue,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Estimating road distance...',
                            style: TextStyle(fontSize: 11.5, color: _mutedSlate),
                          ),
                        ],
                      )
                    : Expanded(
                        child: Text(
                          _roadDistanceText != null && _travelTimeText != null
                              ? '$_roadDistanceText • $_travelTimeText'
                              : 'Distance estimation ready',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationBatchScheduleScreen(location: loc),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('View Timetable'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandBlue,
                    side: const BorderSide(color: _brandBlue, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchGoogleMapsNavigation(loc.latitude, loc.longitude),
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: const Text('Start Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}