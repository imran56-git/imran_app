import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

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

  // টেক্সট দিয়ে লোকেশন সার্চ এবং ম্যাপে পিন ড্রপ
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final position = LatLng(locations.first.latitude, locations.first.longitude);
        
        // ক্যামেরা অ্যানিমেশন
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(position, 15),
        );

        // সার্চ করা লোকেশনটিকে সরাসরি অ্যাড করার অপশন বা ট্যাপ ট্রিগার
        await _onMapTap(position);
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found. Please try another name.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ম্যাপ ট্যাপ এবং রিভার্স জিওকোডিং (অ্যাড্রেস বের করা)
  Future<void> _onMapTap(LatLng position) async {
    String address = "Pinned Location";
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
        
        address = "$name, $subLocality, $locality".replaceAll(RegExp(r', ,|,,'), ',').trim();
        if (address.startsWith(',') || address.isEmpty) {
          address = "${place.subLocality ?? ''} ${place.locality ?? ''}".trim();
        }
        if (address.isEmpty) address = "Area ${selectedLocations.length + 1}";
      }
    } catch (e) {
      address = "Location ${selectedLocations.length + 1}";
    }

    if (mounted) {
      setState(() {
        // ডুপ্লিকেট লোকেশন এড়াতে চেক
        bool exists = selectedLocations.any((loc) => 
          (loc['lat'] as double).toStringAsFixed(4) == position.latitude.toStringAsFixed(4) &&
          (loc['lng'] as double).toStringAsFixed(4) == position.longitude.toStringAsFixed(4)
        );
        
        if (!exists) {
          selectedLocations.add({
            'lat': position.latitude,
            'lng': position.longitude,
            'address': address,
          });
        }
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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Select Teaching Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.check_circle_rounded, size: 28, color: Colors.greenAccent),
              onPressed: () => Navigator.pop(context, selectedLocations),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // গুগল ম্যাপ উইজেট
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(22.5726, 88.3639), // কোলকাতা/পশ্চিমবঙ্গ রিজিয়ন ডিফল্ট
              zoom: 12,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: selectedLocations.asMap().entries.map((entry) {
              int idx = entry.key;
              var data = entry.value;
              return Marker(
                markerId: MarkerId('loc_${idx}_${data['lat']}'),
                position: LatLng(data['lat'], data['lng']),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(
                  title: data['address'],
                  snippet: "Tap info window to remove",
                  onTap: () => _removeLocation(idx),
                ),
              );
            }).toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // কাস্টম জায়গায় বসানোর জন্য অফ করা
            zoomControlsEnabled: false,
          ),

          // প্রিমিয়াম ফ্লোটিং সার্চ বার
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _searchLocation,
                decoration: InputDecoration(
                  hintText: "Search area (e.g. Salt Lake, Sector 5)",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.location_on_rounded, color: Colors.blue[800]),
                  suffixIcon: _isSearching 
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: Icon(Icons.search_rounded, color: Colors.blue[800]),
                          onPressed: () => _searchLocation(_searchController.text),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
              ),
            ),
          ),

          // ইউজার গাইডেন্স পপআপ অ্যানিমেশন
          if (selectedLocations.isEmpty)
            Positioned(
              bottom: 30,
              left: 40,
              right: 40,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Tap on map to pin your teaching locations",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      
      // ডাইনামিক বটম শীট (সিলেক্টেড লোকেশন লিস্ট দেখানোর জন্য)
      bottomNavigationBar: selectedLocations.isNotEmpty
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: selectedLocations.length == 1 ? 140 : 210,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                children: [
                  // হেডার প্যানেল
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${selectedLocations.length} Areas Selected',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B1B1B)),
                            ),
                            const Text("These areas will show on your profile", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => selectedLocations.clear()),
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                          label: const Text("CLEAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // সিলেক্টেড লোকেশনের হরাইজন্টাল কারোসেল লিস্ট
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: selectedLocations.length,
                      itemBuilder: (context, index) {
                        final item = selectedLocations[index];
                        return Container(
                          width: 220,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50]!.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade100, width: 1),
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
                                    Icon(Icons.location_on, color: Colors.blue[800], size: 18),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item['address'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B1B1B)),
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: InkWell(
                                    onTap: () => _removeLocation(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                      child: Icon(Icons.close, size: 14, color: Colors.red[700]),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
