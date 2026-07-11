import 'package:flutter/material.dart';
import '../../widgets/tuition_cards.dart';
import 'reminder_screen.dart';
import 'diary_screen.dart';

class TuitionManagementScreen extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;

  const TuitionManagementScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Tuition Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Management Hub',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select a tool to manage your classes and payments.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            TuitionHubCard(
              title: 'Free Reminder',
              subtitle: 'Send professional tuition fee alerts to students.',
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFFEF4444),
              gradientStart: Colors.white,
              gradientEnd: Colors.white,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReminderScreen(
                      currentUserId: currentUserId,
                      currentUserName: currentUserName,
                    ),
                  ),
                );
              },
            ),
            TuitionHubCard(
              title: 'My Diary',
              subtitle: 'Track homework, topics covered, and attendance.',
              icon: Icons.auto_stories_outlined,
              iconColor: const Color(0xFF10B981),
              gradientStart: Colors.white,
              gradientEnd: Colors.white,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiaryScreen(
                      currentUserId: currentUserId,
                      currentUserName: currentUserName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
