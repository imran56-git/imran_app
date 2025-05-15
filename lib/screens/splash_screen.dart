import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'welcome_screen.dart'; // Welcome Screen Import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Wait 3 seconds then navigate to WelcomeScreen
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: Center(
        child: Lottie.asset(
          'assets/animations/teacher_logo_animation.json', // Updated animation path
          width: 250,
          height: 250,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}