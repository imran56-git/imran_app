import 'package:flutter/material.dart';
import 'reminder_screen.dart';
import 'diary_screen.dart';

class TuitionManagementScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const TuitionManagementScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<TuitionManagementScreen> createState() => _TuitionManagementScreenState();
}

class _TuitionManagementScreenState extends State<TuitionManagementScreen> with TickerProviderStateMixin {
  // ভবিষ্যতের ডাইনামিক অ্যানিমেশন কন্ট্রোলার বা রিয়াল-টাইম ড্যাশবোর্ড ওভারভিউ চেকের জন্য TickerProviderStateMixin অক্ষুণ্ণ রাখা হলো

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Tuition Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // প্রিমিয়াম অ্যানিমেটেড হেডার সেকশন
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 350),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 12),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Management Hub',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                      letterSpacing: 0.3,
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
                ],
              ),
            ),
            const SizedBox(height: 28),

            // CARD 1: Free Reminder
            _buildAnimatedCard(
              delay: 100,
              child: TuitionHubCard(
                title: 'Free Reminder',
                subtitle: 'Send professional tuition fee alerts to students.',
                icon: Icons.notifications_active_outlined,
                iconColor: const Color(0xFFEF4444),
                gradientColors: const [Colors.white, Color(0xFFFFF5F5)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReminderScreen(
                        currentUserId: widget.currentUserId,
                        currentUserName: widget.currentUserName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // CARD 2: My Diary
            _buildAnimatedCard(
              delay: 200,
              child: TuitionHubCard(
                title: 'My Diary',
                subtitle: 'Track homework, topics covered, and attendance.',
                icon: Icons.auto_stories_outlined,
                iconColor: const Color(0xFF10B981),
                gradientColors: const [Colors.white, Color(0xFFF0FDF4)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiaryScreen(
                        currentUserId: widget.currentUserId,
                        currentUserName: widget.currentUserName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // কার্ডগুলোর জন্য একটি স্মুথ এন্ট্রান্স অ্যানিমেশন হেল্পার
  Widget _buildAnimatedCard({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// প্রিমিয়াম লুকিং টিউশন হাব কার্ড উইজেট ইমপ্লিমেন্টেশন
class TuitionHubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const TuitionHubCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: iconColor.withOpacity(0.06),
          highlightColor: iconColor.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                // কন্টেইনারাইজড আইকন ডিজাইন
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 18),
                // টেক্সট মেটেরিয়াল
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // ট্রেইলিং অ্যারো বাটন
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
