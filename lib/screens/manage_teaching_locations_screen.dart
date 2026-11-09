import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/teacher_location_model.dart';
import '../services/teacher_location_service.dart';
import 'location_picker_screen.dart';
import 'location_batch_schedule_screen.dart';

class ManageTeachingLocationsScreen extends StatefulWidget {
  final String currentTeacherId;

  const ManageTeachingLocationsScreen({
    super.key,
    required this.currentTeacherId,
  });

  @override
  State<ManageTeachingLocationsScreen> createState() =>
      _ManageTeachingLocationsScreenState();
}

class _ManageTeachingLocationsScreenState
    extends State<ManageTeachingLocationsScreen>
    with SingleTickerProviderStateMixin {
  // Brand Palette FYBTT 2.0
  static const Color kDeepNavy = Color(0xFF0F172A);
  static const Color kBrandBlue = Color(0xFF1E4C7A);
  static const Color kAccentBlue = Color(0xFF2563EB);
  static const Color kAccentAmber = Color(0xFFF59E0B);
  static const Color kSlateSurface = Color(0xFFF8FAFC);
  static const Color kCardBorder = Color(0xFFE2E8F0);
  static const Color kTextSecondary = Color(0xFF64748B);

  late final TeacherLocationService _locationService;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _locationService = TeacherLocationService();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION & FLOWS
  // ---------------------------------------------------------------------------

  Future<void> _navigateToAddLocation() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      int addedCount = 0;
      for (final item in result) {
        try {
          final String resolvedAddress =
              (item['fullAddress'] ?? item['address'] ?? '').toString();
          final double resolvedRadius =
              (item['radiusKm'] as num?)?.toDouble() ?? 10.0;

          final newLoc = TeacherLocationModel(
            id: '',
            teacherId: widget.currentTeacherId,
            locationName: (item['locationName'] ?? item['address'] ?? 'Teaching Hub')
                .toString(),
            locationType: (item['locationType'] ?? 'Tuition Centre').toString(),
            teachingMode: (item['teachingMode'] ?? 'offline').toString().toLowerCase(),
            address: resolvedAddress,
            fullAddress: resolvedAddress,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            geohash: (item['geohash'] ?? '').toString(),
            radiusKm: resolvedRadius,
            serviceRadiusKm: resolvedRadius,
            isActive: true,
            isDeleted: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _locationService.createTeachingLocation(newLoc);
          addedCount++;
        } catch (_) {}
      }

      if (mounted && addedCount > 0) {
        _showSnackBar(
          '$addedCount teaching centre${addedCount > 1 ? 's' : ''} added successfully!',
          isSuccess: true,
        );
      }
    }
  }

  Future<void> _moveOrEditPin(TeacherLocationModel location) async {
    final double radius = location.serviceRadiusKm ?? location.radiusKm ?? 10.0;
    final String currentAddress = location.fullAddress.isNotEmpty
        ? location.fullAddress
        : location.address;

    final initialList = [
      {
        'id': location.id,
        'locationName': location.locationName,
        'locationType': location.locationType,
        'teachingMode': location.teachingMode,
        'address': location.address,
        'fullAddress': currentAddress,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radiusKm': radius,
      }
    ];

    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocations: initialList,
          initialLatitude: location.latitude,
          initialLongitude: location.longitude,
          initialAddress: currentAddress,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final updated = result.first;
      try {
        final double newRad = (updated['radiusKm'] as num?)?.toDouble() ?? radius;
        final String newAddr =
            (updated['fullAddress'] ?? updated['address'] ?? currentAddress).toString();

        final updatedModel = location.copyWith(
          locationName: updated['locationName']?.toString() ?? location.locationName,
          locationType: updated['locationType']?.toString() ?? location.locationType,
          teachingMode: updated['teachingMode']?.toString() ?? location.teachingMode,
          address: newAddr,
          fullAddress: newAddr,
          latitude: (updated['latitude'] as num).toDouble(),
          longitude: (updated['longitude'] as num).toDouble(),
          radiusKm: newRad,
          serviceRadiusKm: newRad,
          updatedAt: DateTime.now(),
        );

        await _locationService.updateTeachingLocation(updatedModel);
        if (mounted) {
          _showSnackBar("Pin coordinates and address updated successfully!", isSuccess: true);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar("Failed to update location pin.", isError: true);
        }
      }
    }
  }

  void _navigateToBatchesAndSchedule(TeacherLocationModel location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationBatchScheduleScreen(location: location),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS: POPUP MENU & DUPLICATE & DELETE
  // ---------------------------------------------------------------------------

  Future<void> _handleDuplicateLocation(TeacherLocationModel location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Duplicate Teaching Centre?",
          style: TextStyle(fontWeight: FontWeight.w800, color: kDeepNavy),
        ),
        content: Text(
          'This will duplicate "${location.locationName}" as a new centre entry. Batches and schedules will not be cloned automatically.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Duplicate"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final duplicated = location.copyWith(
          id: '',
          locationName: '${location.locationName} (Copy)',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _locationService.createTeachingLocation(duplicated);
        if (mounted) {
          _showSnackBar("Centre duplicated successfully!", isSuccess: true);
        }
      } catch (_) {
        if (mounted) {
          _showSnackBar("Could not duplicate centre.", isError: true);
        }
      }
    }
  }

  Future<void> _handleDeleteLocation(TeacherLocationModel location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              "Delete Centre?",
              style: TextStyle(fontWeight: FontWeight.w800, color: kDeepNavy),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "${location.locationName}"?',
              style: const TextStyle(fontWeight: FontWeight.w600, color: kDeepNavy, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Any ongoing batches at this location will be paused. You can recover this centre anytime from the Recently Deleted archive.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Centre"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _locationService.softDeleteTeachingLocation(
          widget.currentTeacherId,
          location.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${location.locationName}"'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: kDeepNavy,
              action: SnackBarAction(
                label: 'UNDO',
                textColor: kAccentAmber,
                onPressed: () async {
                  await _locationService.restoreTeachingLocation(
                    widget.currentTeacherId,
                    location.id,
                  );
                },
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          _showSnackBar("Failed to delete location.", isError: true);
        }
      }
    }
  }

  void _openEditDetailsSheet(TeacherLocationModel location) {
    final nameCtrl = TextEditingController(text: location.locationName);
    final String currentAddress = location.fullAddress.isNotEmpty
        ? location.fullAddress
        : location.address;
    final addressCtrl = TextEditingController(text: currentAddress);
    String currentType = location.locationType;
    String currentMode = location.teachingMode;

    final locationTypes = ['Tuition Centre', 'Institute', 'Home Tuition', 'School', 'Other'];
    final modes = ['offline', 'hybrid', 'online'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  const SizedBox(height: 16),
                  const Text(
                    "Edit Centre Details",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kDeepNavy),
                  ),
                  const SizedBox(height: 16),
                  const Text("Centre Name", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kDeepNavy),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("Address", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontWeight: FontWeight.w500, color: kDeepNavy, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("Location Type", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: locationTypes.map((type) {
                      final sel = currentType == type;
                      return ChoiceChip(
                        label: Text(type, style: TextStyle(color: sel ? Colors.white : kDeepNavy, fontSize: 12)),
                        selected: sel,
                        selectedColor: kBrandBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) setModalState(() => currentType = type);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text("Teaching Mode", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: modes.map((m) {
                      final sel = currentMode == m;
                      return ChoiceChip(
                        label: Text(m.toUpperCase(), style: TextStyle(color: sel ? Colors.white : kDeepNavy, fontSize: 11)),
                        selected: sel,
                        selectedColor: kAccentAmber,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) setModalState(() => currentMode = m);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDeepNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final updated = location.copyWith(
                          locationName: nameCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          fullAddress: addressCtrl.text.trim(),
                          locationType: currentType,
                          teachingMode: currentMode,
                          updatedAt: DateTime.now(),
                        );
                        await _locationService.updateTeachingLocation(updated);
                        if (mounted) {
                          Navigator.pop(modalCtx);
                          _showSnackBar("Centre details updated successfully!", isSuccess: true);
                        }
                      },
                      child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RECENTLY DELETED / RECOVERY MODAL SHEET
  // ---------------------------------------------------------------------------

  void _openRecentlyDeletedSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Recovery & Archive",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kDeepNavy,
                        ),
                      ),
                      Text(
                        "Restore or permanently remove deleted centres",
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFF1F5F9)),
              Expanded(
                child: StreamBuilder<List<TeacherLocationModel>>(
                  stream: _locationService.getDeletedTeacherLocationsStream(
                    widget.currentTeacherId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final deletedItems = snapshot.data ?? [];

                    if (deletedItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_delete_outlined, size: 54, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              "No Deleted Centres",
                              style: TextStyle(fontWeight: FontWeight.bold, color: kDeepNavy, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Teaching locations you delete will appear here for recovery.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: kTextSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: deletedItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = deletedItems[index];
                        final deletedDate = item.updatedAt;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kSlateSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kCardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.locationName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kDeepNavy,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Deleted ${_formatDate(deletedDate)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: kTextSecondary),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFDC2626),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                                    label: const Text("Delete Permanently"),
                                    onPressed: () => _confirmPermanentDelete(item),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kBrandBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    icon: const Icon(Icons.restore_rounded, size: 16),
                                    label: const Text("Restore"),
                                    onPressed: () async {
                                      await _locationService.restoreTeachingLocation(
                                        widget.currentTeacherId,
                                        item.id,
                                      );
                                      if (mounted) {
                                        _showSnackBar('Restored "${item.locationName}"', isSuccess: true);
                                      }
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmPermanentDelete(TeacherLocationModel location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Permanently Delete?",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
        ),
        content: Text(
          'This action cannot be undone. "${location.locationName}" and its related spatial indexing will be permanently removed.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Destroy Permanently"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _locationService.permanentlyDeleteTeachingLocation(
        widget.currentTeacherId,
        location.id,
      );
      if (mounted) {
        _showSnackBar("Location permanently erased.");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlateSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: kDeepNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Teaching Locations",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kDeepNavy,
              ),
            ),
            Text(
              "Physical hubs & smart matching radii",
              style: TextStyle(fontSize: 11, color: kTextSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Recently Deleted Archive",
            icon: const Icon(Icons.auto_delete_rounded, color: kBrandBlue),
            onPressed: _openRecentlyDeletedSheet,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))
                ],
              ),
              labelColor: kDeepNavy,
              unselectedLabelColor: kTextSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: "Active Locations"),
                Tab(text: "Inactive / Paused"),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<TeacherLocationModel>>(
        stream: _locationService.getTeacherLocationsStream(
          widget.currentTeacherId,
          includeInactive: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Unable to load locations: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allLocations = snapshot.data ?? [];
          final activeLocations = allLocations.where((loc) => loc.isActive && !loc.isDeleted).toList();
          final inactiveLocations = allLocations.where((loc) => !loc.isActive && !loc.isDeleted).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLocationList(activeLocations, isActiveTab: true),
              _buildLocationList(inactiveLocations, isActiveTab: false),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAccentAmber,
        foregroundColor: kDeepNavy,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.add_location_alt_rounded, size: 20),
        label: const Text(
          "Add New Centre",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: _navigateToAddLocation,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LIST VIEW & CARDS
  // ---------------------------------------------------------------------------

  Widget _buildLocationList(List<TeacherLocationModel> locations, {required bool isActiveTab}) {
    if (locations.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: kBrandBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  size: 46,
                  color: kBrandBlue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isActiveTab ? "No Active Teaching Centres" : "No Paused Locations",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kDeepNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActiveTab
                    ? "Add your physical tuition classes or study hubs so nearby students can discover your schedule."
                    : "Centres you toggle off will appear here and won't match live search queries.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kTextSecondary),
              ),
              if (isActiveTab) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: const Text("Add Your First Location", style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _navigateToAddLocation,
                ),
              ]
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: locations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final loc = locations[index];
        return _buildLocationCard(loc);
      },
    );
  }

  Widget _buildLocationCard(TeacherLocationModel location) {
    bool isVerified = false;
    try {
      final dynamic l = location;
      if (l.isVerified != null && l.isVerified is bool) {
        isVerified = l.isVerified as bool;
      } else if (l.verificationStatus != null) {
        isVerified = l.verificationStatus == 'verified';
      }
    } catch (_) {}

    final teachingMode = location.teachingMode.toUpperCase();
    final double radius = location.serviceRadiusKm ?? location.radiusKm ?? 10.0;
    final String displayAddress = location.fullAddress.isNotEmpty
        ? location.fullAddress
        : location.address;

    List<String> subjects = [];
    try {
      final dynamic l = location;
      if (l.subjects != null) {
        subjects = List<String>.from(l.subjects);
      } else if (l.subjectSpecialties != null) {
        subjects = List<String>.from(l.subjectSpecialties);
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                // Location Type Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: kBrandBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    location.locationType,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kBrandBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Verification status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVerified ? Icons.verified_rounded : Icons.pending_rounded,
                        size: 13,
                        color: isVerified
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? "Verified" : "Active Centre",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isVerified
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // 3-Dot Options Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: kTextSecondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        _openEditDetailsSheet(location);
                        break;
                      case 'batches':
                      case 'schedule':
                        _navigateToBatchesAndSchedule(location);
                        break;
                      case 'duplicate':
                        _handleDuplicateLocation(location);
                        break;
                      case 'delete':
                        _handleDeleteLocation(location);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: kDeepNavy),
                          SizedBox(width: 10),
                          Text("Edit Details"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'batches',
                      child: Row(
                        children: [
                          Icon(Icons.class_outlined, size: 18, color: kDeepNavy),
                          SizedBox(width: 10),
                          Text("Manage Batches"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'schedule',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 18, color: kDeepNavy),
                          SizedBox(width: 10),
                          Text("Manage Schedule"),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 18, color: kDeepNavy),
                          SizedBox(width: 10),
                          Text("Duplicate Centre"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Text("Delete Centre", style: TextStyle(color: Colors.red.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Centre Title & Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.locationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kDeepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.place_rounded, size: 15, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTextSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Teaching Mode & Radius Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kAccentAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    teachingMode,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Coverage: ${radius.toStringAsFixed(0)} KM",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                    ),
                  ),
                ),
                if (subjects.isNotEmpty)
                  ...subjects.take(2).map(
                        (sub) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sub,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: kAccentBlue,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Bar: Active Toggle + Quick Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // Active status switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: location.isActive,
                        activeColor: kBrandBlue,
                        onChanged: (val) async {
                          await _locationService.toggleLocationActiveStatus(
                            widget.currentTeacherId,
                            location.id,
                            val,
                          );
                        },
                      ),
                    ),
                    Text(
                      location.isActive ? "Active" : "Paused",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: location.isActive ? kDeepNavy : kTextSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Action: Move / Edit Pin
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDeepNavy,
                    side: const BorderSide(color: kCardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 14),
                  label: const Text("Edit Pin"),
                  onPressed: () => _moveOrEditPin(location),
                ),
                const SizedBox(width: 8),

                // Action: Batches & Schedule
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 13),
                  label: const Text("Batches"),
                  onPressed: () => _navigateToBatchesAndSchedule(location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : isSuccess
                ? const Color(0xFF16A34A)
                : kDeepNavy,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}