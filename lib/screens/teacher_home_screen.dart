import 'package:flutter/material.dart';
import 'chat_list_screen.dart'; // চ্যাট স্ক্রিনের বদলে চ্যাট লিস্ট স্ক্রিন ইম্পোর্ট
import 'teacher_profile_screen.dart'; 

class TeacherHomeScreen extends StatefulWidget {
  final String currentUserId; // বাগ ফিক্স: টিচারের আইডি ডায়নামিক করার জন্য প্যারামিটার যুক্ত

  const TeacherHomeScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // বাগ ফিক্স: হার্ডকোড চ্যাট স্ক্রিন সরিয়ে রিয়েল-টাইম চ্যাট লিস্ট সিঙ্ক করা হলো
    _screens = [
      ChatListScreen(currentUserId: widget.currentUserId),
      TeacherProfileScreen(currentUserId: widget.currentUserId), // প্রোফাইল স্ক্রিনে আইডি পাস
    ];
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // প্রোফাইল স্ক্রিন (Index 1) সিলেক্ট থাকলে হোমের AppBar হাইড থাকবে
    final bool showAppBar = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // অ্যাপের স্ট্যান্ডার্ড ব্যাকগ্রাউন্ড সিঙ্ক
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              titleSpacing: 20,
              // FYBTT ব্র্যান্ড লগো এবং নেম ইন্টিগ্রেশন
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.school_rounded, color: Color(0xFF1E4C7A), size: 30),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'FYBTT Teacher',
                    style: TextStyle(
                      color: Color(0xFF1E4C7A),  
                      fontWeight: FontWeight.black,  
                      fontSize: 19,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Search Students',
                  icon: const Icon(Icons.search_rounded, color: Colors.black87, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Search student feature coming soon')),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
          
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      
      // Floating Action Button অ্যাকশন ফিক্স
      floatingActionButton: _selectedIndex == 0 
        ? FloatingActionButton(
            backgroundColor: const Color(0xFF1E4C7A), // ব্র্যান্ড কালার সিঙ্ক
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select a student from the list to start chatting')),
              );
            },
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
          )
        : null,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), 
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF1E4C7A), // ওল্ড গ্রিন কালার চেঞ্জড
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.chat_bubble_outline_rounded, size: 22),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.chat_bubble_rounded, size: 22),
                ),
                label: 'Student Chats',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.person_outline_rounded, size: 24),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.person_rounded, size: 24),
                ),
                label: 'My Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
