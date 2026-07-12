import 'package:flutter/material.dart';
import 'chat_screen.dart'; 
import 'teacher_profile_screen.dart'; 

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChatScreen(
      teacherName: "Student",
      chatId: "sample_chat_id",
      currentUserId: "teacher_id_from_home",
      receiverId: "student_id_from_home",
    ),
    const TeacherProfileScreen(),
  ];

  final List<String> _titles = [
    "Student Messages",
    "My Profile",
  ];

  @override
  Widget build(BuildContext context) {
    // প্রোফাইল স্ক্রিন (Index 1) সিলেক্ট থাকলে হোমের AppBar হাইড থাকবে, 
    // কারণ প্রোফাইল স্ক্রিনের নিজের সুন্দর কাস্টম হেডার আছে।
    final bool showAppBar = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: showAppBar
          ? AppBar(
              title: Text(
                _titles[_selectedIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  onPressed: () {},
                ),
              ],
            )
          : null, // প্রোফাইলে গেলে হোমের AppBar উধাও
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: _selectedIndex == 0 
        ? FloatingActionButton(
            backgroundColor: const Color(0xFF128C7E),
            onPressed: () {},
            child: const Icon(Icons.message, color: Colors.white),
          )
        : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF128C7E),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
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
