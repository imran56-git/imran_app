import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  
  // কাস্টম ইন্টারফেস অ্যানিমেশনের জন্য সিলেক্টেড মার্কার ডেটা হোল্ডার
  Map<String, dynamic>? _selectedLocationData;
  bool _showDetailsCard = false;

  // ডিফল্ট সেন্টার পজিশন (ইন্ডিয়া/ওয়েস্ট বেঙ্গল বেস জোন যদি ডেটা মিসিং থাকে)
  final LatLng _defaultCenter = const LatLng(22.5726, 88.3639); 

  @override
  void initState() {
    super.initState();
    _fetchTeacherTeachingAreas();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ফায়ারবেস থেকে ডায়নামিক লোকেশন ও এরিয়া মার্কার ফেচিং মেকানিজম (#11, #16)
  Future<void> _fetchTeacherTeachingAreas() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (!doc.exists || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};
      // ফায়ারবেস থেকে 'teachingAreas' লিস্ট রিড করা হচ্ছে
      final List<dynamic> areas = data['teachingAreas'] ?? [];

      _markers.clear();
      List<LatLng> points = [];

      for (var index = 0; index < areas.length; index++) {
        final area = areas[index] as Map<String, dynamic>;
        
        // ফায়ারবেস ফিল্ড থেকে ল্যাটিটিউড এবং লঙ্গিটিউড এক্সট্রাক্ট করা (Null-Safe)
        final double? lat = double.tryParse(area['latitude']?.toString() ?? '');
        final double? lng = double.tryParse(area['longitude']?.toString() ?? '');
        final String locationName = area['locationName'] ?? 'Teaching Zone ${index + 1}';
        final String address = area['address'] ?? 'Address not specified';

        if (lat != null && lng != null) {
          final LatLng position = LatLng(lat, lng);
          points.add(position);

          _markers.add(
            Marker(
              markerId: MarkerId('zone_$index'),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueTeal),
              onTap: () {
                setState(() {
                  _selectedLocationData = {
                    'name': locationName,
                    'address': address,
                    'lat': lat,
                    'lng': lng,
                  };
                  _showDetailsCard = true;
                });
              },
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });

      // সব মার্কার স্ক্রিনের সেন্টারে ফিট করার জন্য ক্যামেরা অ্যানিমেশন বাউন্স হুক
      if (points.isNotEmpty && _mapController != null) {
        _animateToFitPoints(points);
      }
    } catch (e) {
      debugPrint("Firestore Map Data Fetch Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // ম্যাপ রেডি হওয়ার পর যদি ডেটা আগে লোড হয়ে থাকে তবে ফিট করা হবে
    if (_markers.isNotEmpty) {
      List<LatLng> points = _markers.map((m) => m.position).toList();
      _animateToFitPoints(points);
    }
  }

  void _animateToFitPoints(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60, // ম্যাপ প্যাডিং চারপাশ থেকে যেন কেটে না যায়
      ),
    );
  }

  // এক্সটার্নাল অফিশিয়াল গুগল ম্যাপস অ্যাপ ওপেন এবং ডিরেকশন মেকানিজম (#12)
  Future<void> _launchGoogleMapsNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    final Uri fallbackWebUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      if (await launchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else if (await launchUrl(fallbackWebUrl, mode: LaunchMode.externalApplication)) {
        await launchUrl(fallbackWebUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps application.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Could not open Google Maps App!"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialPos = _markers.isNotEmpty ? _markers.first.position : _defaultCenter;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Teaching Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            Text(widget.teacherName, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3.5))
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: initialPos, zoom: 12),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: (_) => setState(() => _showDetailsCard = false), // ফাঁকা জায়গায় ট্যাপ করলে কার্ড হাইড হবে
                ),

          // অ্যাডভান্সড ইউআই অ্যানিমেটেড লোকেশন ডিটেইলস কার্ড মেকানিজম (#11, #15)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.antiClockwiseLinear,
            bottom: _showDetailsCard ? 20 : -180,
            left: 16,
            right: 16,
            child: _selectedLocationData == null
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Colors.teal, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedLocationData!['name'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Teacher: ${widget.teacherName}",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedLocationData!['address'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        // প্রফেশনাল গুগল ম্যাপস নেভিগেট বাটন (#11, #12)
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E4C7A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _launchGoogleMapsNavigation(
                              _selectedLocationData!['lat'],
                              _selectedLocationData!['lng'],
                            ),
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            label: const Text("START NAVIGATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
