import 'package:flutter/material.dart';

import 'chat_list_screen.dart';
import 'search_teacher_screen.dart';
import 'student_profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final String currentUserId;

  const StudentHomeScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  final List<String> _titles = const [
    'Messages',
    'Find Teachers',
    'Student Profile',
  ];

  @override
  void initState() {
    super.initState();

    _screens = [
      ChatListScreen(currentUserId: widget.currentUserId),
      const TeacherSearchScreen(),
      const StudentProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _handleFabPressed() {
    if (_selectedIndex == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open new chat / teacher search from here'),
        ),
      );
    } else if (_selectedIndex == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apply teacher search filters here'),
        ),
      );
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_selectedIndex == 0) {
      return [
        IconButton(
          tooltip: 'Mark all as read',
          icon: const Icon(Icons.mark_chat_read_outlined, color: Color(0xFF1A237E)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mark all chats as read')),
            );
          },
        ),
      ];
    }

    if (_selectedIndex == 2) {
      return [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF1A237E)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open settings screen here')),
            );
          },
        ),
      ];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final bool showFab = _selectedIndex != 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            color: Color(0xFF1A1C1E),
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: _buildAppBarActions(),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      floatingActionButton: showFab
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF128C7E),
              elevation: 3,
              onPressed: _handleFabPressed,
              child: Icon(
                _selectedIndex == 0 ? Icons.chat : Icons.filter_alt_outlined,
                color: Colors.white,
              ),
            )
          : null,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
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
            selectedItemColor: const Color(0xFF128C7E),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                activeIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                activeIcon: Icon(Icons.manage_search_rounded),
                label: 'Teachers',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}