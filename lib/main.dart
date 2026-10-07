import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:find_your_best_teacher_today/ratings_badges_system.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const FindYourBestTeacherTodayApp());
}

class FindYourBestTeacherTodayApp extends StatefulWidget {
  const FindYourBestTeacherTodayApp({super.key});

  @override
  State<FindYourBestTeacherTodayApp> createState() => _FindYourBestTeacherTodayAppState();
}

class _FindYourBestTeacherTodayAppState extends State<FindYourBestTeacherTodayApp>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAppData();
  }

  Future<void> _initializeAppData() async {
    await _setupNotifications();
    await _setUserOnlineStatusAndToken(true);
  }

  Future<void> _setupNotifications() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messaging.onTokenRefresh.listen((newToken) {
      _updateFcmTokenInFirestore(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnlineStatusAndToken(true);
    } else {
      _setUserOnlineStatusAndToken(false);
    }
  }

  Future<void> _setUserOnlineStatusAndToken(bool isOnline) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      String? token = await _messaging.getToken();

      Map<String, dynamic> updateData = {
        'isOnline': isOnline,
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      };

      if (token != null) {
        updateData['fcmToken'] = token;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData).catchError((_) {});
      await _firestore.collection('teachers').doc(user.uid).update(updateData).catchError((_) {});
      await _firestore.collection('students').doc(user.uid).update(updateData).catchError((_) {});
    } catch (e) {
      debugPrint("Firestore Online/Token Update Error: $e");
    }
  }

  Future<void> _updateFcmTokenInFirestore(String token) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({'fcmToken': token}).catchError((_) {});
      await _firestore.collection('teachers').doc(user.uid).update({'fcmToken': token}).catchError((_) {});
      await _firestore.collection('students').doc(user.uid).update({'fcmToken': token}).catchError((_) {});
    } catch (e) {
      debugPrint("Token Refresh Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find Your Best Teacher Today',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
