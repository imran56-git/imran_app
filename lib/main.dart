import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart'; // Firebase console থেকে ডাউনলোড করা
import 'routes/app_routes.dart'; // তোমার রুটিং ফাইল
import 'screens/splash_screen.dart';

// Firebase background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const FindYourBestTeacherTodayApp());
}

runApp(GetMaterialApp(
  debugShowCheckedModeBanner: false,
  home: const SplashScreen(),
));

class FindYourBestTeacherTodayApp extends StatefulWidget {
  const FindYourBestTeacherTodayApp({super.key});

  @override
  State<FindYourBestTeacherTodayApp> createState() => _FindYourBestTeacherTodayAppState();
}

class _FindYourBestTeacherTodayAppState extends State<FindYourBestTeacherTodayApp>
    with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnlineStatus(true); // App launch করলে অনলাইন
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = _auth.currentUser;
    if (user != null) {
      if (state == AppLifecycleState.resumed) {
        _setUserOnlineStatus(true);
      } else {
        _setUserOnlineStatus(false);
      }
    }
  }

  Future<void> _setUserOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find Your Best Teacher Today',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}