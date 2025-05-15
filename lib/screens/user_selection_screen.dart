import 'package:flutter/material.dart';
import 'register_screen.dart';

class UserSelectionScreen extends StatelessWidget {
  const UserSelectionScreen({super.key});

  void navigateToRegister(BuildContext context, String userType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(userType: userType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Who are you?'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Are you a...',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // Teacher Image + Button
                Image.asset('assets/images/teacher.png', height: 150),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => navigateToRegister(context, 'teacher'),
                  icon: const Icon(Icons.school, size: 28),
                  label: const Text('Teacher', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Student Image + Button
                Image.asset('assets/images/student.png', height: 150),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => navigateToRegister(context, 'student'),
                  icon: const Icon(Icons.person, size: 28),
                  label: const Text('Student', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}