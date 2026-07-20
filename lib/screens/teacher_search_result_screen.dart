import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/teacher_card_widget.dart';

class TeacherSearchResultScreen extends StatelessWidget {
  final Map<String, dynamic> filters;

  const TeacherSearchResultScreen({super.key, required this.filters});

  // Student's baseline coordinate parameters (Kolkata Center as default)
  final double _studentLat = 22.5726;
  final double _studentLng = 88.3639;

  /// Haversine formula for coordinate distance calculation
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // In Kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180.0);
  }

  @override
  Widget build(BuildContext context) {
    // Extract search query options cleanly
    final String targetId = (filters['teacherId'] ?? '').toString().trim().toLowerCase();
    final String targetName = (filters['name'] ?? '').toString().trim().toLowerCase();
    final String targetSubject = (filters['subject'] ?? '').toString().trim().toLowerCase();
    final String targetLocation = (filters['location'] ?? '').toString().trim().toLowerCase();
    
    final int minExperience = int.tryParse(filters['experience']?.toString() ?? '0') ?? 0;
    final double minRadius = double.tryParse(filters['minRadius']?.toString() ?? '0.0') ?? 0.0;
    final double maxRadius = double.tryParse(filters['maxRadius']?.toString() ?? '500.0') ?? 500.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Matching Teachers',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E4C7A),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching teachers: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoResultsView();
          }

          // Smart & Resilient Multiplex Filtering Logic
          final matchedDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final docId = doc.id.toLowerCase();

            final String name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
            final String location = (data['location'] ?? data['address'] ?? '').toString().toLowerCase();
            
            // Flexibly extract subject list or string
            List<String> subjects = [];
            if (data['subjects'] is List) {
              subjects = (data['subjects'] as List).map((s) => s.toString().toLowerCase()).toList();
            } else if (data['subjects'] is String) {
              subjects = [data['subjects'].toString().toLowerCase()];
            }

            final int exp = data['experience'] is int
                ? data['experience']
                : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

            // 1. Text & ID Match Condition
            bool matchesId = targetId.isEmpty || docId.contains(targetId);
            bool matchesName = targetName.isEmpty || name.contains(targetName);
            bool matchesLocation = targetLocation.isEmpty || location.contains(targetLocation);
            bool matchesSubject = targetSubject.isEmpty ||
                subjects.any((s) => s.contains(targetSubject));
            bool matchesExperience = exp >= minExperience;

            // 2. Safe Coordinates & Radius Match Condition
            bool matchesRadius = true;
            double? tLat = double.tryParse(data['latitude']?.toString() ?? '');
            double? tLng = double.tryParse(data['longitude']?.toString() ?? '');

            // Only apply strict radius check if user explicitly requested radius filtering AND coordinates exist
            if (tLat != null && tLng != null && tLat != 0.0 && tLng != 0.0) {
              double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);
              matchesRadius = distance >= minRadius && distance <= maxRadius;
            }

            return matchesId && matchesName && matchesLocation && matchesSubject && matchesExperience && matchesRadius;
          }).toList();

          if (matchedDocs.isEmpty) {
            return _buildNoResultsView();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            physics: const BouncingScrollPhysics(),
            itemCount: matchedDocs.length,
            itemBuilder: (context, index) {
              final doc = matchedDocs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              double tLat = double.tryParse(data['latitude']?.toString() ?? '0.0') ?? 0.0;
              double tLng = double.tryParse(data['longitude']?.toString() ?? '0.0') ?? 0.0;
              
              String distanceText = "N/A";
              if (tLat != 0.0 && tLng != 0.0) {
                double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);
                distanceText = "${distance.toStringAsFixed(1)} KM";
              }

              List<String> subjectsList = [];
              if (data['subjects'] is List) {
                subjectsList = List<String>.from(data['subjects'].map((x) => x.toString()));
              } else if (data['subjects'] is String) {
                subjectsList = [data['subjects'].toString()];
              }
              final String subjectText = subjectsList.isNotEmpty ? subjectsList.join(', ') : 'General';

              return TeacherCardWidget(
                teacherId: doc.id,
                name: data['name'] ?? data['displayName'] ?? 'Unknown Teacher',
                subject: subjectText,
                profileImageUrl: data['photoUrl'] ?? data['profilePic'] ?? '',
                latitude: tLat,
                longitude: tLng,
                studentCount: data['studentCount'] is int ? data['studentCount'] : int.tryParse(data['studentCount']?.toString() ?? '0') ?? 0,
                experienceYears: data['experience'] is int ? data['experience'] : int.tryParse(data['experience']?.toString() ?? '0') ?? 0,
                followersCount: data['followersCount'] is int ? data['followersCount'] : int.tryParse(data['followersCount']?.toString() ?? '0') ?? 0,
                rating: double.tryParse(data['rating']?.toString() ?? '5.0') ?? 5.0,
                locationText: data['location'] ?? data['address'] ?? 'Location N/A',
                calculatedDistance: distanceText,
                onChatPressed: () {
                  // Navigation/Action callback
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Teachers Found",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Text(
              "We couldn't find any teacher matching your precise filters and radius settings. Try broadening your search criteria.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
