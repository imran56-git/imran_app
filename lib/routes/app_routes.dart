import 'package:flutter/material.dart';
import 'package:find_your_best_teacher_today/screens/splash_screen.dart';
import 'package:find_your_best_teacher_today/screens/welcome_screen.dart';
import 'package:find_your_best_teacher_today/screens/user_selection_screen.dart';
import 'package:find_your_best_teacher_today/screens/login_screen.dart';
import 'package:find_your_best_teacher_today/screens/student_home_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_home_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:find_your_best_teacher_today/screens/student_register_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_register_screen.dart';

class AppRoutes {
  // Route Names
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String userSelection = '/user-selection';
  static const String studentRegister = '/student-register';
  static const String teacherRegister = '/teacher-register';
  static const String login = '/login';
  static const String studentHome = '/student-home';
  static const String teacherHome = '/teacher-home';
  static const String teacherWelcome = '/teacher-welcome';

// Route Mapping with Animation
static Route<dynamic> generateRoute(RouteSettings settings) {

  Widget page;

  switch (settings.name) {

    case splash:
      page = const SplashScreen();
      break;

    case welcome:
      page = const WelcomeScreen();
      break;

    case userSelection:
      page = const UserSelectionScreen();
      break;

    case studentRegister:
      page = StudentHomeScreen(
  currentUserId: FirebaseAuth.instance.currentUser!.uid,
);
      break;

    case teacherRegister:
      page = const TeacherRegistrationScreen();
      break;

    case login:
      page = const LoginScreen();
      break;

    case studentHome:
      page = const StudentHomeScreen();
      break;

    case teacherHome:
      page = const TeacherHomeScreen();
      break;

    case teacherWelcome:
      page = const TeacherWelcomeScreen();
      break;

    default:
      page = const WelcomeScreen();
  }

  return PageRouteBuilder(
    settings: settings,

    pageBuilder: (context, animation, secondaryAnimation) {
      return page;
    },

    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {

      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;

      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(
        CurveTween(
          curve: Curves.easeInOut,
        ),
      );

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    },
  );
}

}