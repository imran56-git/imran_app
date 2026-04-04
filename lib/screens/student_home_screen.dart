import 'package:flutter/material.dart';
import 'chat_home_screen.dart';
import 'teacher_search_screen.dart';
import 'student_profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  // 1. Core State Management
  int _selectedIndex = 1; // Defaulting to Search for better user onboarding

  // 2. Titles mapped to indices
  final List<String> _titles = [
    "Messages",
    "Find Teachers",
    "Student Profile",
  ];

  // 3. Main Screens (Ensure these files are imported correctly)
  final List<Widget> _screens = [
    const ChatHomeScreen(),
    const TeacherSearchScreen(),
    const StudentProfileScreen(),
  ];

  // 4. Tab Switcher Logic
  void _onTabTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),

      // Professional Dynamic AppBar
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1A1C1E),
          ),
        ),
        centerTitle: false, // Professional left-aligned title
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          // Dynamic actions based on selected tab
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.mark_chat_read_outlined, color: Colors.blue),
              onPressed: () {},
            ),
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black87),
              onPressed: () {
                // Navigate to Settings
              },
            ),
        ],
      ),

      // IndexedStack preserves the state of each page (no reloading)
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // Context-Aware Floating Action Button
      floatingActionButton: _selectedIndex != 2 
        ? FloatingActionButton(
            backgroundColor: const Color(0xFF128C7E),
            onPressed: () {
              // Action based on tab: Create Group or Apply Filter
            },
            child: Icon(
              _selectedIndex == 0 ? Icons.chat : Icons.filter_list,
              color: Colors.white,
            ),
          )
        : null,

      // Highly Professional Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          selectedItemColor: const Color(0xFF128C7E), // Professional Teal/Green
          unselectedItemColor: Colors.blueGrey[300],
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.message_outlined),
              ),
              activeIcon: Icon(Icons.message),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.travel_explore_outlined),
              ),
              activeIcon: Icon(Icons.travel_explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.account_circle_outlined),
              ),
              activeIcon: Icon(Icons.account_circle),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
