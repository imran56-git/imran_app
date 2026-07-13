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

  @override
  void initState() {
    super.initState();
    // বাগ ফিক্স: চাইল্ড স্ক্রিনগুলোতে currentUserId পাস করা হয়েছে যাতে ডেটা সিঙ্ক ঠিক থাকে
    _screens = [  
      ChatListScreen(currentUserId: widget.currentUserId),  
      const TeacherSearchScreen(),  // আপনার আর্কিটেকচার অনুযায়ী প্রয়োজনীয় প্যারামিটার দিতে পারেন
      StudentProfileScreen(currentUserId: widget.currentUserId),  
    ];
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  // প্রফেশনাল FAB অ্যাকশন হ্যান্ডলার
  void _handleFabPressed() {
    if (_selectedIndex == 0) {
      // মেসেজ ট্যাবে থাকলে সরাসরি শিক্ষক খোঁজার ট্যাবে (Index 1) রিডাইরেক্ট করবে
      setState(() => _selectedIndex = 1);
    } else if (_selectedIndex == 1) {
      // ফিল্টারের জন্য একটি মডার্ন বটম শিট ওপেন হবে
      _showFilterBottomSheet();
    }
  }

  // ফিল্টার বটম শিট আর্কিটেকচার
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
                children: [
                  const Text(
                    'Filter Teachers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
              // এখানে আপনার কাস্টম ফিল্টার উইজেট (যেমন সাবজেক্ট, লোকেশন) অ্যাড করতে পারবেন
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Advanced filters will appear here', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_selectedIndex == 0) {
      return [
        IconButton(
          tooltip: 'Mark all as read',
          icon: const Icon(Icons.mark_chat_read_outlined, color: Color(0xFF1E4C7A), size: 22),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('All messages marked as read'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final bool showFab = _selectedIndex != 2;
    final bool showAppBar = _selectedIndex != 2; 

    return Scaffold(  
      backgroundColor: const Color(0xFFF7F9FC),  
      appBar: showAppBar  
          ? AppBar(  
              backgroundColor: Colors.white,  
              elevation: 0,  
              scrolledUnderElevation: 0,  
              centerTitle: false,  
              titleSpacing: 20,  
              // লগো এবং ব্র্যান্ড নেম (FYBTT) ইন্টিগ্রেশন
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
                    'FYBTT',
                    style: TextStyle(
                      color: Color(0xFF1E4C7A),  
                      fontWeight: FontWeight.black,  
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),  
              actions: _buildAppBarActions(),  
            )  
          : null,  

      body: IndexedStack(  
        index: _selectedIndex,  
        children: _screens,  
      ),  

      floatingActionButton: showFab  
          ? FloatingActionButton(  
              backgroundColor: const Color(0xFF1E4C7A),  
              elevation: 4,  
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _handleFabPressed,  
              child: Icon(  
                _selectedIndex == 0 ? Icons.chat_rounded : Icons.filter_alt_rounded,  
                color: Colors.white,  
              ),  
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
            selectedItemColor: const Color(0xFF1E4C7A),  
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
                label: 'Messages',  
              ),  
              BottomNavigationBarItem(  
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.search_rounded, size: 24),
                ),  
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.manage_search_rounded, size: 24),
                ),  
                label: 'Teachers',  
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
                label: 'Profile',  
              ),  
            ],  
          ),  
        ),  
      ),  
    );
  }
}
