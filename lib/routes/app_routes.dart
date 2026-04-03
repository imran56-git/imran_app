import 'package:flutter/material.dart';

// Screens Import
import 'package:find_your_best_teacher_today/screens/splash_screen.dart';
import 'package:find_your_best_teacher_today/screens/welcome_screen.dart';
import 'package:find_your_best_teacher_today/screens/user_selection_screen.dart';
import 'package:find_your_best_teacher_today/screens/login_screen.dart';
import 'package:find_your_best_teacher_today/screens/student_home_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_home_screen.dart';
import 'package:find_your_best_teacher_today/screens/teacher_welcome_screen.dart';
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

  // Route Mapping
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    welcome: (context) => const WelcomeScreen(),
    userSelection: (context) => const UserSelectionScreen(),
    studentRegister: (context) => const StudentRegistrationScreen(), 
    teacherRegister: (context) => const TeacherRegistrationScreen(),
    login: (context) => const LoginScreen(),
    studentHome: (context) => const StudentHomeScreen(),
    teacherHome: (context) => const TeacherHomeScreen(),
    teacherWelcome: (context) => const TeacherWelcomeScreen(),
  };
}
