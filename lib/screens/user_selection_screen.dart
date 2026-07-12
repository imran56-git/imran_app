import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Who are you?', 
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0, // ফ্ল্যাট মডার্ন লুকের জন্য
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Are you a...', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // টিচার রোল কার্ড
              _buildRoleCard('Teacher', Colors.deepPurple, 'assets/images/teacher.png'),
              const SizedBox(height: 20),

              // স্টুডেন্ট রোল কার্ড
              _buildRoleCard('Student', Colors.teal, 'assets/images/student.png'),

              const Spacer(),

              // লগইন স্ক্রিন নেভিগেশন (স্ট্যাক ক্লিন রাখার জন্য pushReplacementNamed ব্যবহার করা হয়েছে)
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // কন্টিনিউ বাটন (স্ট্যাক ক্লিন রাখার জন্য pushReplacementNamed ব্যবহার করা হয়েছে)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedRole == null 
                      ? null 
                      : () {
                          final targetRoute = _selectedRole == 'Teacher' 
                              ? AppRoutes.teacherRegister 
                              : AppRoutes.studentRegister;
                          
                          Navigator.pushReplacementNamed(context, targetRoute);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    disabledBackgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _selectedRole == null ? 0 : 2,
                  ),
                  child: const Text(
                    'Continue', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // রোল সিলেকশন কার্ড উইজেট
  Widget _buildRoleCard(String role, Color color, String imagePath) {
    final bool isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), // স্মুথ সিলেকশন অ্যানিমেশন
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? color : Colors.transparent, 
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.15) : Colors.black.withOpacity(0.05), 
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // ইমেজ লোড ফেইলর হ্যান্ডলিং সহ অ্যাসেট ইমেজ উইজেট
            Image.asset(
              imagePath, 
              height: 80, 
              width: 80,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    role == 'Teacher' ? Icons.school : Icons.person, 
                    color: color, 
                    size: 40,
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            Text(
              role, 
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: isSelected ? color : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected) 
              Icon(Icons.check_circle, color: color, size: 30),
          ],
        ),
      ),
    );
  }
}
