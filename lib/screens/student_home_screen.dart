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
  // 1. Core State Variables
  int _selectedIndex = 1; // Defaulting to Search Screen for better UX

  // 2. Titles list as per your original requirement
  final List<String> _titles = [
    "Chats",
    "Search Teachers",
    "My Profile",
  ];

  // 3. Screens list wrapped in a list for IndexedStack
  final List<Widget> _screens = [
    const ChatHomeScreen(),
    const TeacherSearchScreen(),
    const StudentProfileScreen(),
  ];

  // 4. Your original Tab Tapping logic with setState
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      
      // AppBar with dynamic title switching logic
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple[800],
        actions: [
          if (_selectedIndex == 2) // Action button specifically for Profile tab
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                // Settings navigation logic goes here
              },
            ),
        ],
      ),

      // IndexedStack ensures that search results or chat states are preserved
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // Professional Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped, // Calling your original method
          selectedItemColor: Colors.deepPurple[700],
          unselectedItemColor: Colors.grey[500],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.manage_search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
