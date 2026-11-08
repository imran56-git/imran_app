import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/google_maps_route_service.dart';
import '../services/location_service.dart';

class DirectionsNavigationScreen extends StatefulWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String destinationName;
  final String destinationAddress;
  final String teacherName;
  final String? teacherPhotoUrl;

  const DirectionsNavigationScreen({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.destinationName,
    required this.destinationAddress,
    required this.teacherName,
    this.teacherPhotoUrl,
  });

  @override
  State<DirectionsNavigationScreen> createState() =>
      _DirectionsNavigationScreenState();
}

class _DirectionsNavigationScreenState
    extends State<DirectionsNavigationScreen> {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _slateBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final GoogleMapsRouteService _routeService = GoogleMapsRouteService();

  // Travel Mode: 'driving', 'walking', 'bicycling'
  String _selectedMode = 'driving';
  bool _isLoadingRoute = true;
  bool _isDirectEstimation = false;

  double? _routeDistanceKm;
  int? _travelTimeMinutes;

  @override
  void initState() {
    super.initState();
    _initMarkers();
    _fetchAndDrawRoute();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _initMarkers() {
    _markers.clear();

    // Origin Marker (Student)
    _markers.add(
      Marker(
        markerId: const MarkerId('origin_marker'),
        position: LatLng(widget.originLat, widget.originLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Starting point',
        ),
      ),
    );

    // Destination Marker (Teaching Centre)
    _markers.add(
      Marker(
        markerId: const MarkerId('dest_marker'),
        position: LatLng(widget.destLat, widget.destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.destinationName,
          snippet: widget.destinationAddress,
        ),
      ),
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
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

  Future<void> _fetchAndDrawRoute() async {
    setState(() {
      _isLoadingRoute = true;
      _isDirectEstimation = false;
    });

    List<LatLng> polylinePoints = [];
    double distanceKm = 0.0;
    int durationMins = 0;

    try {
      final routeDetails = await _routeService.getRouteDetails(
        originLat: widget.originLat,
        originLng: widget.originLng,
        destLat: widget.destLat,
        destLng: widget.destLng,
      );

      if (routeDetails != null) {
        distanceKm = routeDetails.distanceKm;

        // Scale duration based on selected mode
        if (_selectedMode == 'walking') {
          durationMins = (distanceKm / 4.6 * 60).round().clamp(1, 300);
        } else if (_selectedMode == 'bicycling') {
          durationMins = (distanceKm / 14.0 * 60).round().clamp(1, 300);
        } else {
          durationMins = routeDetails.durationMinutes;
        }

        // Draw polyline if points available
        if (routeDetails.polylinePoints.isNotEmpty) {
          polylinePoints = routeDetails.polylinePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback if network or service returns no polyline
    if (polylinePoints.isEmpty) {
      final directKm = _haversine(
        widget.originLat,
        widget.originLng,
        widget.destLat,
        widget.destLng,
      );
      final roadFactor = _selectedMode == 'walking' ? 1.15 : 1.28;
      distanceKm = directKm * roadFactor;

      final avgSpeed = _selectedMode == 'walking'
          ? 4.6
          : _selectedMode == 'bicycling'
              ? 14.0
              : 25.0;
      durationMins = (distanceKm / avgSpeed * 60).round().clamp(2, 360);

      // Simple two-point fallback polyline
      polylinePoints = [
        LatLng(widget.originLat, widget.originLng),
        LatLng(widget.destLat, widget.destLng),
      ];
      _isDirectEstimation = true;
    }

    if (mounted) {
      setState(() {
        _routeDistanceKm = distanceKm;
        _travelTimeMinutes = durationMins;
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline'),
            points: polylinePoints,
            color: _accentBlue,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
        _isLoadingRoute = false;
      });

      _fitCameraToBounds();
    }
  }

  void _fitCameraToBounds() {
    if (_mapController == null) return;

    final double southWestLat =
        math.min(widget.originLat, widget.destLat);
    final double southWestLng =
        math.min(widget.originLng, widget.destLng);
    final double northEastLat =
        math.max(widget.originLat, widget.destLat);
    final double northEastLng =
        math.max(widget.originLng, widget.destLng);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(southWestLat, southWestLng),
          northeast: LatLng(northEastLat, northEastLng),
        ),
        84.0,
      ),
    );
  }

  Future<void> _startTurnByTurnNavigation() async {
    final modeCode = _selectedMode == 'walking'
        ? 'w'
        : _selectedMode == 'bicycling'
            ? 'b'
            : 'd';

    final Uri nativeAppUrl = Uri.parse(
        "google.navigation:q=${widget.destLat},${widget.destLng}&mode=$modeCode");
    final Uri webFallbackUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&origin=${widget.originLat},${widget.originLng}&destination=${widget.destLat},${widget.destLng}&travelmode=$_selectedMode");

    try {
      if (await canLaunchUrl(nativeAppUrl)) {
        await launchUrl(nativeAppUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webFallbackUrl)) {
        await launchUrl(webFallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps app.';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to launch maps navigation"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _shareLocationDetails() {
    final shareText =
        'Teaching Centre: ${widget.destinationName}\nEducator: ${widget.teacherName}\nAddress: ${widget.destinationAddress}\nCoordinates: ${widget.destLat}, ${widget.destLng}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Venue address and details copied!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = LatLng(
      (widget.originLat + widget.destLat) / 2,
      (widget.originLng + widget.destLng) / 2,
    );

    return Scaffold(
      backgroundColor: _slateBg,
      body: Stack(
        children: [
          // Full-Screen Interactive Google Map Canvas
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 13),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitCameraToBounds();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),

          // Top HUD Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHud(),
          ),

          // Bottom Floating Route Summary Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildBottomRouteSummaryCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHud() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xCC0F172A),
            Color(0x770F172A),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button with Blur
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),

              // Centre and Teacher Preview Badge
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _navy.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  _brandBlue.withValues(alpha: 0.4),
                              backgroundImage: (widget.teacherPhotoUrl !=
                                          null &&
                                      widget.teacherPhotoUrl!.isNotEmpty)
                                  ? NetworkImage(widget.teacherPhotoUrl!)
                                  : null,
                              child: (widget.teacherPhotoUrl == null ||
                                      widget.teacherPhotoUrl!.isEmpty)
                                  ? Text(
                                      widget.teacherName.isNotEmpty
                                          ? widget.teacherName[0].toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.destinationName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    widget.teacherName,
                                    style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 10.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Recenter Button
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.crop_free_rounded,
                          size: 20, color: Colors.white),
                      onPressed: _fitCameraToBounds,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Live Travel Mode Selector
          _buildTravelModeSelector(),
        ],
      ),
    );
  }

  Widget _buildTravelModeSelector() {
    final modes = [
      {'key': 'driving', 'label': 'Driving', 'icon': Icons.directions_car_rounded},
      {'key': 'bicycling', 'label': 'Bike / Ride', 'icon': Icons.two_wheeler_rounded},
      {'key': 'walking', 'label': 'Walking', 'icon': Icons.directions_walk_rounded},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: modes.map((m) {
              final isSelected = _selectedMode == m['key'];
              return GestureDetector(
                onTap: () {
                  if (_selectedMode != m['key']) {
                    setState(() => _selectedMode = m['key'] as String);
                    _fetchAndDrawRoute();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6.5),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        m['label'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRouteSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E0F172A),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDirectEstimation) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 13, color: _accentAmber),
                  SizedBox(width: 5),
                  Text(
                    'Direct road distance estimation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Metrics Row (Duration & Distance)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _isLoadingRoute
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brandBlue,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Computing road route...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _mutedSlate,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _travelTimeMinutes != null
                              ? '$_travelTimeMinutes mins'
                              : '--',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _navy,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _routeDistanceKm != null
                              ? '(${_routeDistanceKm!.toStringAsFixed(1)} KM)'
                              : '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _mutedSlate,
                          ),
                        ),
                      ],
                    ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedMode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _emerald,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Destination Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on, size: 16, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.destinationAddress,
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
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_navy, _brandBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _startTurnByTurnNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.navigation_rounded,
                        size: 18, color: Colors.white),
                    label: const Text(
                      'Start Google Navigation',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: _slateBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined,
                      size: 20, color: _navy),
                  tooltip: 'Share Route',
                  onPressed: _shareLocationDetails,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}