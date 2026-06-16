import 'dart:async';
import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import '../widgets/shiny_loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

    @override
      State<SplashScreen> createState() => _SplashScreenState();
      }

      class _SplashScreenState extends State<SplashScreen>
          with TickerProviderStateMixin {
            late AnimationController _bounceController;
              late Animation<double> _bounceAnimation;

                @override
                  void initState() {
                      super.initState();

                          _bounceController = AnimationController(
                                  duration: const Duration(milliseconds: 1200), vsync: this);
                                      _bounceAnimation =
                                              CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut);

                                                  _bounceController.forward();

                                                      Timer(const Duration(seconds: 3), () {
                                                            if (mounted) {
                                                                    Navigator.pushReplacement(
                                                                              context,
                                                                                        PageRouteBuilder(
                                                                                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                                                                                                    const WelcomeScreen(),
                                                                                                                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                                                                                                              return FadeTransition(
                                                                                                                                                              opacity: animation,
                                                                                                                                                                              child: child,
                                                                                                                                                                                            );
                                                                                                                                                                                                        },
                                                                                                                                                                                                                    transitionDuration: const Duration(milliseconds: 800),
                                                                                                                                                                                                                              ),
                                                                                                                                                                                                                                      );
                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                });
                                                                                                                                                                                                                                                  }

                                                                                                                                                                                                                                                    @override
                                                                                                                                                                                                                                                      void dispose() {
                                                                                                                                                                                                                                                          _bounceController.dispose();
                                                                                                                                                                                                                                                              super.dispose();
                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                  @override
                                                                                                                                                                                                                                                                    Widget build(BuildContext context) {
                                                                                                                                                                                                                                                                        return Scaffold(
                                                                                                                                                                                                                                                                              backgroundColor: Colors.black,
                                                                                                                                                                                                                                                                                    body: Center(
                                                                                                                                                                                                                                                                                            child: ScaleTransition(
                                                                                                                                                                                                                                                                                                      scale: _bounceAnimation,
                                                                                                                                                                                                                                                                                                                child: CustomShinyLoading(
                                                                                                                                                                                                                                                                                                                            child: const Text(
                                                                                                                                                                                                                                                                                                                                          'IM',
                                                                                                                                                                                                                                                                                                                                                        style: TextStyle(
                                                                                                                                                                                                                                                                                                                                                                        fontSize: 90,
                                                                                                                                                                                                                                                                                                                                                                                        fontWeight: FontWeight.bold,
                                                                                                                                                                                                                                                                                                                                                                                                        letterSpacing: 2.0,
                                                                                                                                                                                                                                                                                                                                                                                                                      ),
                                                                                                                                                                                                                                                                                                                                                                                                                                  ),
                                                                                                                                                                                                                                                                                                                                                                                                                                            ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                    ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                          ),
                                                                                                                                                                                                                                                                                                                                                                                                                                                              );
                                                                                                                                                                                                                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                