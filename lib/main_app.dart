import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/chat_list_screen.dart';
import 'utils/chat_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find Your Best Teacher Today',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: ChatColors.primaryApp,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ChatColors.primaryApp,
          primary: ChatColors.primaryApp,
          secondary: ChatColors.primaryDark,
          background: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ChatColors.appBarLight,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const ChatListScreen(
        currentUserId: 'YOUR_CURRENT_USER_ID',
        currentUserName: 'YOUR_CURRENT_USER_NAME',
      ),
    );
  }
}
