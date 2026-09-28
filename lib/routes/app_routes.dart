import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:find_your_best_teacher_today/screens/splash_screen.dart';
import 'package:find_your_best_teacher_today/screens/welcome_screen.dart';
import 'package:find_your_best_teacher_today/screens/user_selection_screen.dart';
import 'package:find_your_best_teacher_today/screens/login_screen.dart';
import 'package:find_your_best_teacher_today/screens/student_home_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_home_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_welcome_screen.dart';
import 'package:find_your_best_teacher_today/screens/student_register_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_register_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_profile_screen.dart';
import 'package:find_your_best_teacher_today/screens/student_profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String userSelection = '/user-selection';
  static const String studentRegister = '/student-register';
  static const String teacherRegister = '/teacher-register';
  static const String login = '/login';
  static const String studentHome = '/student-home';
  static const String teacherHome = '/teacher-home';
  static const String teacherWelcome = '/teacher-welcome';
  static const String chat = '/chat';
  static const String teacherProfile = '/teacher_profile';
  static const String studentProfile = '/student_profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    Widget page;

    final authUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final args = settings.arguments;

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
        page = const StudentRegistrationScreen();
        break;

      case teacherRegister:
        page = const TeacherRegistrationScreen();
        break;

      case login:
        page = const LoginScreen();
        break;

      case studentHome:
        final userId = (args is String && args.isNotEmpty) ? args : authUserId;
        page = StudentHomeScreen(
          currentUserId: userId,
        );
        break;

      case teacherHome:
        final userId = (args is String && args.isNotEmpty) ? args : authUserId;
        page = TeacherHomeScreen(
          currentUserId: userId,
        );
        break;

      case teacherWelcome:
        final userId = (args is String && args.isNotEmpty) ? args : authUserId;
        page = TeacherWelcomeScreen(
          currentUserId: userId,
        );
        break;

      case teacherProfile:
        final teacherId = (args is Map && args.containsKey('teacherId'))
            ? args['teacherId'].toString()
            : (args is String ? args : authUserId);
        page = TeacherProfileScreen(currentUserId: teacherId);
        break;

      case studentProfile:
        final studentId = (args is Map && args.containsKey('studentId'))
            ? args['studentId'].toString()
            : (args is String ? args : authUserId);
        page = StudentProfileScreen(currentUserId: studentId);
        break;

      default:
        page = const WelcomeScreen();
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;

        final tween = Tween<Offset>(
          begin: begin,
          end: end,
        ).chain(
          CurveTween(curve: Curves.easeInOut),
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
