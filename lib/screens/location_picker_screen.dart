import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialLocations;

  const LocationPickerScreen({
    super.key,
    this.initialLocations,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with TickerProviderStateMixin {
  // Brand Palette FYBTT 2.0
  static const Color kDeepNavy = Color(0xFF0F172A);
  static const Color kBrandBlue = Color(0xFF1E4C7A);
  static const Color kAccentAmber = Color(0xFFF59E0B);
  static const Color kSlateSurface = Color(0xFFF8FAFC);
  static const Color kCardBorder = Color(0xFFE2E8F0);

  final List<Map<String, dynamic>> selectedLocations = [];
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  bool _isSearching = false;
  bool _isLoadingLocation = false;
  MapType _currentMapType = MapType.normal;

  LatLng _currentCenterPosition = const LatLng(22.5726, 88.3639); // Kolkata fallback
  String _draggedAddress = "Locating area...";
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocations != null && widget.initialLocations!.isNotEmpty) {
      selectedLocations.addAll(widget.initialLocations!);
      final first = widget.initialLocations!.first;
      if (first['latitude'] != null && first['longitude'] != null) {
        _currentCenterPosition = LatLng(
          (first['latitude'] as num).toDouble(),
          (first['longitude'] as num).toDouble(),
        );
      }
    }

    _updateAddressFromPosition(_currentCenterPosition);
    _getUserCurrentLocation(moveToPosition: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // METHOD C: GPS LOCATION ACQUISITION
  // ---------------------------------------------------------------------------
  Future<void> _getUserCurrentLocation({bool moveToPosition = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      final position = await LocationService.getCurrentLocation();
      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _currentCenterPosition = currentLatLng;
      });

      if (_mapController != null && moveToPosition) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLatLng, zoom: 15.5),
          ),
        );
      }

      await _updateAddressFromPosition(currentLatLng);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Could not retrieve live GPS coordinates. Check location permissions.',
          isError: true,
        );
        await _updateAddressFromPosition(_currentCenterPosition);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // METHOD A: SEARCH & SELECT VIA GEOCODING
  // ---------------------------------------------------------------------------
  Future<void> _searchLocation(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    try {
      final List<Location> locations = await locationFromAddress(cleaned);
      if (locations.isNotEmpty) {
        final position = LatLng(locations.first.latitude, locations.first.longitude);
        if (!mounted) return;

        setState(() {
          _currentCenterPosition = position;
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: position, zoom: 15.5),
          ),
        );

        await _updateAddressFromPosition(position);
      } else {
        _showSnackBar('Location not found. Try a specific landmark or road.', isError: true);
      }
    } catch (_) {
      _showSnackBar('Unable to resolve address. Please adjust your query.', isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ---------------------------------------------------------------------------
  // METHOD B & D: REVERSE GEOCODING & MAP LONG-PRESS
  // ---------------------------------------------------------------------------
  Future<void> _updateAddressFromPosition(LatLng position) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final name = (place.name ?? "").trim();
        final subLocality = (place.subLocality ?? "").trim();
        final locality = (place.locality ?? "").trim();
        final subAdmin = (place.subAdministrativeArea ?? "").trim();
        final postalCode = (place.postalCode ?? "").trim();

        final parts = [name, subLocality, locality, subAdmin, postalCode]
            .where((p) => p.isNotEmpty)
            .toSet()
            .toList();

        final formatted = parts.join(', ');
        setState(() {
          _draggedAddress = formatted.isEmpty ? "Unknown Location" : formatted;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _draggedAddress =
              "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
        });
      }
    }
  }

  void _onMapLongPress(LatLng tappedPosition) async {
    setState(() {
      _currentCenterPosition = tappedPosition;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(tappedPosition),
    );

    await _updateAddressFromPosition(tappedPosition);
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.hybrid
          : MapType.normal;
    });
  }

  // ---------------------------------------------------------------------------
  // ENHANCED MODAL BOTTOM SHEET ON PINNING
  // ---------------------------------------------------------------------------
  void _openPinDetailsModal() {
    // Duplicate check
    final isDuplicate = selectedLocations.any((loc) =>
        (loc['latitude'] as double).toStringAsFixed(4) ==
            _currentCenterPosition.latitude.toStringAsFixed(4) &&
        (loc['longitude'] as double).toStringAsFixed(4) ==
            _currentCenterPosition.longitude.toStringAsFixed(4));

    if (isDuplicate) {
      _showSnackBar("This area has already been pinned!", isError: true);
      return;
    }

    final initialName = _draggedAddress.contains(',')
        ? _draggedAddress.split(',').first.trim()
        : _draggedAddress;

    final nameController = TextEditingController(text: initialName);
    String selectedType = 'Tuition Centre';
    String selectedMode = 'Offline';

    final List<String> locationTypes = [
      'Tuition Centre',
      'Institute',
      'Home Tuition',
      'School',
      'Other',
    ];

    final List<String> teachingModes = [
      'Offline',
      'Hybrid',
      'Online',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 30,
                    offset: Offset(0, -6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kBrandBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_location_alt_rounded,
                          color: kBrandBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Configure Teaching Area",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kDeepNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kSlateSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kCardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_rounded, color: kAccentAmber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _draggedAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Hub / Location Name",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kDeepNavy,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText: "e.g., Apex Physics Hub",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Location Type",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: locationTypes.map((type) {
                      final isSelected = selectedType == type;
                      return ChoiceChip(
                        label: Text(type),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : kDeepNavy,
                        ),
                        selected: isSelected,
                        selectedColor: kBrandBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? kBrandBlue : Colors.transparent,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => selectedType = type);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Teaching Mode",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: teachingModes.map((mode) {
                      final isSelected = selectedMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : kDeepNavy,
                        ),
                        selected: isSelected,
                        selectedColor: kAccentAmber.withOpacity(0.95),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? kAccentAmber : Colors.transparent,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => selectedMode = mode);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDeepNavy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final hubName = nameController.text.trim().isNotEmpty
                            ? nameController.text.trim()
                            : initialName;

                        setState(() {
                          selectedLocations.add({
                            'id': 'loc_${DateTime.now().millisecondsSinceEpoch}',
                            'locationName': hubName,
                            'locationType': selectedType,
                            'teachingMode': selectedMode.toLowerCase(),
                            'address': _draggedAddress,
                            'latitude': _currentCenterPosition.latitude,
                            'longitude': _currentCenterPosition.longitude,
                            'radiusKm': 10.0,
                          });
                        });

                        Navigator.pop(modalContext);
                        _showSnackBar("Area successfully added to list!");
                      },
                      child: const Text(
                        "Confirm & Add Location",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeLocation(int index) {
    setState(() {
      selectedLocations.removeAt(index);
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? const Color(0xFFBE123C) : kDeepNavy,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circles = selectedLocations.map((loc) {
      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();
      final radKm = (loc['radiusKm'] as num?)?.toDouble() ?? 10.0;
      return Circle(
        circleId: CircleId('circle_${lat}_$lng'),
        center: LatLng(lat, lng),
        radius: radKm * 1000,
        fillColor: kBrandBlue.withOpacity(0.12),
        strokeColor: kBrandBlue,
        strokeWidth: 2,
      );
    }).toSet();

    circles.add(
      Circle(
        circleId: const CircleId('current_center_active_radius'),
        center: _currentCenterPosition,
        radius: 10000,
        fillColor: kAccentAmber.withOpacity(0.08),
        strokeColor: kAccentAmber.withOpacity(0.5),
        strokeWidth: 1,
      ),
    );

    final markers = selectedLocations.asMap().entries.map((entry) {
      final idx = entry.key;
      final data = entry.value;
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final name = data['locationName'] ?? data['address'];

      return Marker(
        markerId: MarkerId('teaching_idx_$idx'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: name.toString(),
          snippet: data['address'].toString(),
        ),
      );
    }).toSet();

    return Scaffold(
      backgroundColor: kSlateSurface,
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // GOOGLE MAP
          // -------------------------------------------------------------------
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenterPosition,
              zoom: 14,
            ),
            mapType: _currentMapType,
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _currentCenterPosition, zoom: 15),
                ),
              );
            },
            onCameraMoveStarted: () {
              setState(() => _isDragging = true);
            },
            onCameraMove: (CameraPosition position) {
              _currentCenterPosition = position.target;
            },
            onCameraIdle: () async {
              setState(() => _isDragging = false);
              await _updateAddressFromPosition(_currentCenterPosition);
            },
            onLongPress: _onMapLongPress,
            markers: markers,
            circles: circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // -------------------------------------------------------------------
          // CENTER POINTER PIN WITH SPRING SCALE ANIMATION
          // -------------------------------------------------------------------
          Center(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kDeepNavy.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        _isDragging ? "Moving pointer..." : "Selected Target",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.location_pin,
                      size: 48,
                      color: _isDragging ? kAccentAmber : const Color(0xFFEF4444),
                    )
                        .animate(target: _isDragging ? 1.0 : 0.0)
                        .scaleXY(
                          end: 1.25,
                          duration: 180.ms,
                          curve: Curves.elasticOut,
                        ),
                  ],
                ),
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // FLOATING SEARCH BAR (EXECUTIVE BLUR-LIKE CONTAINER)
          // -------------------------------------------------------------------
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: kDeepNavy,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kDeepNavy,
                          ),
                          onSubmitted: _searchLocation,
                          onChanged: (val) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: "Search tuition hubs, areas, landmarks...",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                      _isSearching
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kBrandBlue,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search_rounded, color: kBrandBlue),
                              onPressed: () => _searchLocation(_searchController.text),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // MAP UTILITY CONTROLS (Map Type & GPS Position)
          // -------------------------------------------------------------------
          Positioned(
            right: 16,
            bottom: selectedLocations.isNotEmpty ? 270 : 180,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "map_type_toggle_btn",
                  backgroundColor: Colors.white,
                  foregroundColor: kDeepNavy,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _toggleMapType,
                  child: Icon(
                    _currentMapType == MapType.normal
                        ? Icons.layers_outlined
                        : Icons.layers_rounded,
                    color: kBrandBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "my_gps_location_btn",
                  backgroundColor: Colors.white,
                  foregroundColor: kBrandBlue,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () => _getUserCurrentLocation(moveToPosition: true),
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kBrandBlue,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 20),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // BOTTOM FLOATING ACTION DOCK & CAROUSEL
          // -------------------------------------------------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick pin strip
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 14,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kAccentAmber.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: kAccentAmber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Target Pointer Position",
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isDragging ? "Updating location..." : _draggedAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kDeepNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isDragging ? null : _openPinDetailsModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDeepNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_location_alt_rounded, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Pin Area",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.6, duration: 250.ms, curve: Curves.easeOut),

                // Horizontal Carousel of Added Areas
                if (selectedLocations.isNotEmpty)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${selectedLocations.length} Teaching Hub${selectedLocations.length > 1 ? 's' : ''} Selected',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: kDeepNavy,
                                    ),
                                  ),
                                  const Text(
                                    "10 KM radius student matching coverage",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => setState(() => selectedLocations.clear()),
                                child: const Text(
                                  "Clear All",
                                  style: TextStyle(
                                    color: Color(0xFFE11D48),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        SizedBox(
                          height: 124,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            itemCount: selectedLocations.length,
                            itemBuilder: (context, index) {
                              final item = selectedLocations[index];
                              final locName = item['locationName'] ?? 'Teaching Hub';
                              final locType = item['locationType'] ?? 'Centre';
                              final teachMode =
                                  (item['teachingMode'] ?? 'Offline').toString().toUpperCase();

                              return Container(
                                width: 240,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kSlateSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kCardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: kBrandBlue.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: kBrandBlue,
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                locName.toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: kDeepNavy,
                                                ),
                                              ),
                                              Text(
                                                item['address'].toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _removeLocation(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            locType.toString(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: kDeepNavy,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kAccentAmber.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            teachMode,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Text(
                                          "10 KM",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccentAmber,
                                foregroundColor: kDeepNavy,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context, selectedLocations);
                              },
                              child: const Text(
                                "Save Active Teaching Areas",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().slideY(begin: 0.4, duration: 250.ms),
              ],
            ),
          )
        ],
      ),
    );
  }
}