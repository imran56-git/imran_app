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

  /// Pure math formulation to calculate real-world distance between coordinates
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
    // Extracting passed dynamic boundaries from the search panel context
    final String targetId = (filters['teacherId'] ?? '').toString().toLowerCase();
    final String targetName = (filters['name'] ?? '').toString().toLowerCase();
    final String targetSubject = (filters['subject'] ?? '').toString().toLowerCase();
    final String targetLocation = (filters['location'] ?? '').toString().toLowerCase();
    final String targetExpStr = (filters['experience'] ?? '').toString();
    final int minExperience = int.tryParse(targetExpStr) ?? 0;

    final double minRadius = filters['minRadius'] ?? 1.0;
    final double maxRadius = filters['maxRadius'] ?? 10.0;

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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoResultsView();
          }

          // Strict Client-Side Multiplex Filtering Logic
          final matchedDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final docId = doc.id.toLowerCase();

            final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
            final location = (data['location'] ?? '').toString().toLowerCase();
            final List subjects = data['subjects'] is List ? data['subjects'] : [];
            final int exp = data['experience'] is int 
                ? data['experience'] 
                : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

            // Conditional Checks based on user inputs
            bool matchesId = targetId.isEmpty || docId.contains(targetId);
            bool matchesName = targetName.isEmpty || name.contains(targetName);
            bool matchesLocation = targetLocation.isEmpty || location.contains(targetLocation);
            bool matchesSubject = targetSubject.isEmpty || 
                subjects.any((s) => s.toString().toLowerCase().contains(targetSubject));
            bool matchesExperience = exp >= minExperience;

            // Strict Haversine Radius Range Filtering Logic
            bool matchesRadius = true;
            if (data.containsKey('latitude') && data.containsKey('longitude')) {
              double tLat = double.tryParse(data['latitude'].toString()) ?? 0.0;
              double tLng = double.tryParse(data['longitude'].toString()) ?? 0.0;

              double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);
              matchesRadius = distance >= minRadius && distance <= maxRadius;
            } else {
              // If teacher has no coordinates, exclude them from radius queries safely
              if (targetLocation.isEmpty) matchesRadius = false;
            }

            return matchesId && matchesName && matchesLocation && matchesSubject && matchesExperience && matchesRadius;
          }).toList();

          if (matchedDocs.isEmpty) {
            return _buildNoResultsView();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            physics: const BouncingScrollPhysics(),
            itemCount: matchedDocs.length,
            itemBuilder: (context, index) {
              final doc = matchedDocs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              double tLat = double.tryParse(data['latitude']?.toString() ?? '0.0') ?? 0.0;
              double tLng = double.tryParse(data['longitude']?.toString() ?? '0.0') ?? 0.0;
              double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);

              final List subjectsList = data['subjects'] is List ? data['subjects'] : [];
              final String subjectText = subjectsList.isNotEmpty ? subjectsList.join(', ') : 'General';

              return TeacherCardWidget(
                teacherId: doc.id,
                name: data['name'] ?? data['displayName'] ?? 'No Name',
                subject: subjectText,
                profileImageUrl: data['photoUrl'] ?? '',
                latitude: tLat,
                longitude: tLng,
                studentCount: data['studentCount'] is int ? data['studentCount'] : 0,
                experienceYears: data['experience'] is int ? data['experience'] : 0,
                followersCount: data['followersCount'] is int ? data['followersCount'] : 0,
                rating: double.tryParse(data['rating']?.toString() ?? '5.0') ?? 5.0,
                locationText: data['location'] ?? 'Location N/A',
                calculatedDistance: "${distance.toStringAsFixed(1)} KM",
                onChatPressed: () {
                  // Direct actions or routing config can trigger here
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
              "We couldn't find any teacher matching your precise filters and radius settings. Try broadening your range.",
              textAlign: TextAlign.center, // ফিক্সড: Center উইজেটের বদলে TextAlign.center ব্যবহার করা হয়েছে
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
