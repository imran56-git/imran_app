import 'package:flutter/material.dart';

class TeacherCardWidget extends StatelessWidget {
  final String teacherId;
  final String name;
  final String subject;
  final String profileImageUrl;
  final double latitude;
  final double longitude;
  final int studentCount;
  final int experienceYears;       
  final int followersCount;        
  final double rating;             
  final String locationText;       
  final String calculatedDistance; 
  final VoidCallback onChatPressed;
  final VoidCallback? onProfilePressed; 
  final VoidCallback? onMapPressed;     

  const TeacherCardWidget({
    super.key,
    required this.teacherId,
    required this.name,
    required this.subject,
    required this.profileImageUrl,
    required this.latitude,
    required this.longitude,
    required this.studentCount,
    required this.experienceYears,
    required this.followersCount,
    required this.rating,
    required this.locationText,
    required this.calculatedDistance,
    required this.onChatPressed,
    this.onProfilePressed,
    this.onMapPressed,
  });

  // ইমেজ ফুল-স্ক্রিন প্রিভিউ করার ডায়ালগ উইজেট (Smooth scale animation সহ)
  void _openFullImage(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Image',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              child: profileImageUrl.isNotEmpty
                  ? Image.network(
                      profileImageUrl, 
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
        ),
      ),
      transitionsBuilder: (_, animation, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  // ফিক্সড: এখান থেকে const কেটে দেওয়া হয়েছে এবং চাইল্ডে const যুক্ত করা হয়েছে
  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(40),
      child: const Icon(Icons.person_rounded, size: 80, color: Color(0xFF1E4C7A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF1E4C7A); // const ঠিক করা হয়েছে

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfilePressed,
            splashColor: themeColor.withOpacity(0.03),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // উপরের সেকশন: ছবি, ভেরিফাইড ব্যাজ, নাম ও ম্যাপ আইকন
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullImage(context),
                        child: Hero(
                          tag: 'teacher_avatar_$teacherId',
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: themeColor.withOpacity(0.1),
                                    width: 2.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 32,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  backgroundImage: profileImageUrl.isNotEmpty 
                                      ? NetworkImage(profileImageUrl) 
                                      : null,
                                  child: profileImageUrl.isEmpty 
                                      ? const Icon(Icons.person_rounded, size: 36, color: themeColor) 
                                      : null,
                                ),
                              ),
                              // Verified Badge
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // মিডল টেক্সট ইনফরমেশন
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                // গুগল ম্যাপস আইকন বাটন
                                if (onMapPressed != null)
                                  Material(
                                    color: Colors.teal.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: onMapPressed,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.map_rounded,
                                          color: Colors.teal,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // লোকেশন ও এক্সপেরিয়েন্স মেটালাইন
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: Colors.grey, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "•  $experienceYears Yrs Exp.",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // স্ট্যাটাস বা ড্যাশবোর্ড বার: দূরত্ব, রেটিং, ফলোয়ারস এবং স্টুডেন্টস কাউন্ট
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetaInfoItem(Icons.radar_rounded, calculatedDistance, "Distance", iconColor: Colors.deepOrange),
                        _buildMetaInfoDivider(),
                        _buildMetaInfoItem(Icons.star_rounded, rating.toStringAsFixed(1), "Rating", iconColor: const Color(0xFFFFB300)),
                        _buildMetaInfoDivider(),
                        _buildMetaInfoItem(Icons.people_alt_rounded, "$followersCount", "Followers", iconColor: Colors.purple),
                        _buildMetaInfoDivider(),
                        _buildMetaInfoItem(Icons.school_rounded, "$studentCount", "Students", iconColor: themeColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // অ্যাকশন বাটন সেকশন
                  Row(
                    children: [
                      // View Profile Button
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: themeColor, width: 1.6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: onProfilePressed,
                            child: const Text(
                              "View Profile",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Chat Now Button
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006653),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: onChatPressed,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Chat Now",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // মেটা ইনফো গ্রিড আইটেম বিল্ডার helper মেথড
  Widget _buildMetaInfoItem(IconData icon, String value, String label, {required Color iconColor}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInfoDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.grey.shade300,
    );
  }
}
