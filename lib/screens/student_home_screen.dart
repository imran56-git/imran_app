import 'package:flutter/material.dart';
// তোমার প্রোজেক্টের সঠিক পাথ অনুযায়ী ইম্পোর্টগুলো চেক করে নিও
import 'chat_home_screen.dart';
import 'teacher_search_screen.dart';
import 'student_profile_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  // ১. তোমার আগের সেই _selectedIndex এবং টাইটেল লিস্ট যা তুমি শুরুতে লিখেছিলে
  int _selectedIndex = 1; // ডিফল্ট হিসেবে সার্চ স্ক্রিন রাখা হয়েছে

  final List<String> _titles = [
    "Chats",
    "Search Teachers",
    "My Profile",
  ];

  // ২. তোমার সেই অরিজিনাল _onTabTapped মেথড যা তুমি চেয়েছিলে
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ৩. স্ক্রিন লিস্ট (IndexedStack এর জন্য এখানে রাখা হয়েছে যাতে ডেটা হারিয়ে না যায়)
  final List<Widget> _screens = [
    const ChatHomeScreen(),
    const TeacherSearchScreen(),
    const StudentProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      
      // appBar এ তোমার অরিজিনাল টাইটেল লজিক রাখা হয়েছে
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        // প্রোফাইল ট্যাবে গেলে সেটিংস আইকন দেখানোর বাড়তি ফিচার
        actions: [
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Settings Action
              },
            ),
        ],
      ),

      // body তে IndexedStack ব্যবহার করা হয়েছে যাতে সার্চ রেজাল্ট বা চ্যাট হিস্ট্রি মুছে না যায়
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // BottomNavigationBar এ তোমার সব ফিচার এবং আইকন স্টাইল
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped, // তোমার সেই অরিজিনাল ফাংশন কল
          selectedItemColor: Colors.deepPurple,
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
