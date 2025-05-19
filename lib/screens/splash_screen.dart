import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // for navigation
import 'welcome_screen.dart'; // your next screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Bounce animation
    _bounceController =
        AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _bounceAnimation =
        CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut);

    // Glow animation for the side cut
    _glowController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _bounceController.forward();
    _glowController.repeat(reverse: true);

    Timer(const Duration(seconds: 3), () {
      Get.off(() => const WelcomeScreen());
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: _bounceAnimation,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/logo.png', // use your logo image path
                height: 180,
              ),
              Positioned(
                top: 30,
                right: 55,
                child: FadeTransition(
                  opacity: _glowAnimation,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 3,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}