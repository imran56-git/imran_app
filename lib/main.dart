import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'services/notification_service.dart';

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

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.instance.initializeNotificationSystem(
    appNavigatorKey: NotificationService.navigatorKey,
  );

  runApp(const FindYourBestTeacherTodayApp());
}

class FindYourBestTeacherTodayApp extends StatefulWidget {
  const FindYourBestTeacherTodayApp({super.key});

  @override
  State<FindYourBestTeacherTodayApp> createState() =>
      _FindYourBestTeacherTodayAppState();
}

class _FindYourBestTeacherTodayAppState
    extends State<FindYourBestTeacherTodayApp> with WidgetsBindingObserver {
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
      NotificationService.instance.consumePendingMediaActionIfNeeded(context);
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

      if (token != null && token.isNotEmpty) {
        updateData['fcmToken'] = token;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});
      await _firestore
          .collection('teachers')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});
      await _firestore
          .collection('students')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});
    } catch (_) {}
  }

  Future<void> _updateFcmTokenInFirestore(String token) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final updateData = {'fcmToken': token};
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});
      await _firestore
          .collection('teachers')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});
      await _firestore
          .collection('students')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Find Your Best Teacher Today',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E4C7A)),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
