import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../constants/algorithm_config.dart';
import '../models/review_model.dart';
import '../models/season_model.dart';
import 'chat_service.dart';
import 'review_service.dart';

const String _kReplyActionId = 'ACTION_INLINE_REPLY';
const String _kSendPhotoActionId = 'ACTION_SEND_PHOTO';
const String _kSendVideoActionId = 'ACTION_SEND_VIDEO';
const String _kRateTeacherNowActionId = 'ACTION_RATE_TEACHER_NOW';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await NotificationService.instance.showRemoteMessageNotification(message);
  } catch (_) {}
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await NotificationService.instance
        .handleNotificationResponse(response, isFromBackground: true);
  } catch (_) {}
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  static const String _serviceAccountJsonFromEnv =
      String.fromEnvironment('FCM_SERVICE_ACCOUNT_JSON', defaultValue: '');

  bool _isInitialized = false;
  String? _listeningUserId;
  final DateTime _sessionStartTime = DateTime.now();
  final Set<String> _shownNotificationIds = {};

  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _eventsSubscription;
  Map<String, dynamic>? _pendingMediaActionPayload;
  Map<String, dynamic>? _pendingRatingActionPayload;

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'fybtt_chat_interactive_channel',
    'FYBTT Direct & Group Chats',
    description:
        'Interactive chat notifications with inline reply, photo and video sharing',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _activityChannel =
      AndroidNotificationChannel(
    'fybtt_activity_alerts_channel',
    'FYBTT Follow & Group Alerts',
    description:
        'Notifications for teacher follows, unfollows, group dismissals and invites',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initializeNotificationSystem({
    GlobalKey<NavigatorState>? appNavigatorKey,
  }) async {
    if (_isInitialized) {
      _bindRealtimeListenersForCurrentUser();
      return;
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'CHAT_INTERACTIVE_CATEGORY',
          actions: [
            DarwinNotificationAction.text(
              _kReplyActionId,
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Type your reply...',
            ),
            DarwinNotificationAction.plain(
              _kSendPhotoActionId,
              'Send Photo',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              _kSendVideoActionId,
              'Send Video',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          'SEASON_RATING_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              _kRateTeacherNowActionId,
              '⭐ Rate Teacher Now',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        handleNotificationResponse(response, isFromBackground: false);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.createNotificationChannel(_chatChannel);
      await androidPlugin.createNotificationChannel(_activityChannel);
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showRemoteMessageNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        _processTappedPayload(message.data);
      }
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _saveCurrentUserDeviceToken(user.uid);
        _bindRealtimeListenersForCurrentUser(uidOverride: user.uid);
      } else {
        _disposeRealtimeListeners();
      }
    });

    _bindRealtimeListenersForCurrentUser();
    _isInitialized = true;
  }

  Future<void> _saveCurrentUserDeviceToken(String uid) async {
    try {
      final token = await getDeviceToken();
      if (token == null || token.isEmpty) return;

      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final teacherDoc = await _firestore.collection('teachers').doc(uid).get();
      if (teacherDoc.exists) {
        await _firestore.collection('teachers').doc(uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      } else {
        final studentDoc =
            await _firestore.collection('students').doc(uid).get();
        if (studentDoc.exists) {
          await _firestore.collection('students').doc(uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  void _bindRealtimeListenersForCurrentUser({String? uidOverride}) {
    final String? uid = uidOverride ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    if (_listeningUserId == uid && _chatsSubscription != null) return;

    _disposeRealtimeListeners();
    _listeningUserId = uid;

    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified ||
            change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final String lastSenderId = (data['lastSenderId'] ??
                  data['lastMessageSenderId'] ??
                  data['senderId'] ??
                  '')
              .toString();
          if (lastSenderId.isEmpty || lastSenderId == uid) continue;

          final Timestamp? lastTime = data['lastMessageTime'] as Timestamp?;
          if (lastTime == null) continue;
          if (lastTime.toDate().isBefore(_sessionStartTime)) continue;

          final String uniqueKey =
              'chat_${change.doc.id}_${lastTime.millisecondsSinceEpoch}';
          if (_shownNotificationIds.contains(uniqueKey)) continue;
          _shownNotificationIds.add(uniqueKey);

          final bool isGroup = data['isGroup'] == true;
          final String senderName = _resolveSenderDisplayName(data, uid);
          final String messagePreview =
              (data['lastMessage'] ?? data['lastMessageContent'] ?? 'New message')
                  .toString();
          final String lastMessageType =
              (data['lastMessageType'] ?? 'text').toString();

          if (lastMessageType == AlgorithmConfig.seasonRatingMessageType) {
            showActivityAlertNotification(
              notificationId: change.doc.id.hashCode,
              title: '$senderName • New Rating Season',
              body: messagePreview,
              payloadData: {
                'notificationType': AlgorithmConfig.seasonRatingMessageType,
                'teacherId': lastSenderId,
                'teacherName': senderName,
                'seasonId': SeasonModel.current().id,
                'connectionId': '${lastSenderId}_$uid',
                'chatRoomId': change.doc.id,
              },
            );
          } else {
            showInteractiveChatNotification(
              chatRoomId: change.doc.id,
              senderId: lastSenderId,
              senderName: senderName,
              messageText: messagePreview,
              isGroup: isGroup,
            );
          }
        }
      }
    });

    _eventsSubscription = _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final String type = (data['type'] ?? '').toString().toLowerCase();
          if (type == 'chat' || type == 'group_message') {
            continue;
          }

          final Timestamp? createdAt =
              (data['timestamp'] ?? data['createdAt']) as Timestamp?;
          if (createdAt != null &&
              createdAt.toDate().isBefore(_sessionStartTime)) {
            continue;
          }

          final String uniqueKey = 'event_${change.doc.id}';
          if (_shownNotificationIds.contains(uniqueKey)) continue;
          _shownNotificationIds.add(uniqueKey);

          final String title =
              (data['title'] ?? data['senderName'] ?? 'FYBTT Notification')
                  .toString();
          final String body =
              (data['body'] ?? data['message'] ?? 'You have a new update')
                  .toString();

          showActivityAlertNotification(
            notificationId: change.doc.id.hashCode,
            title: title,
            body: body,
            payloadData: {
              'notificationType': type,
              'notificationDocId': change.doc.id,
              'senderId': (data['senderId'] ?? '').toString(),
              'teacherId':
                  (data['teacherId'] ?? data['senderId'] ?? '').toString(),
              'teacherName': (data['senderName'] ?? 'Teacher').toString(),
              'seasonId':
                  (data['seasonId'] ?? SeasonModel.current().id).toString(),
              'connectionId': (data['connectionId'] ?? '').toString(),
              'subjectId': (data['subjectId'] ?? 'general').toString(),
              'groupId': (data['groupId'] ?? '').toString(),
            },
          );
        }
      }
    });
  }

  String _resolveSenderDisplayName(
      Map<String, dynamic> chatData, String currentUid) {
    final String teacherId = (chatData['teacherId'] ?? '').toString();
    if (teacherId.isNotEmpty && teacherId != currentUid) {
      final String tName = (chatData['teacherName'] ?? '').toString();
      if (tName.isNotEmpty && tName != 'Me') return tName;
    }
    final String studentId = (chatData['studentId'] ?? '').toString();
    if (studentId.isNotEmpty && studentId != currentUid) {
      final String sName = (chatData['studentName'] ?? '').toString();
      if (sName.isNotEmpty && sName != 'Me') return sName;
    }
    return (chatData['receiverName'] ??
            chatData['senderName'] ??
            chatData['groupName'] ??
            'New Message')
        .toString();
  }

  void _disposeRealtimeListeners() {
    _chatsSubscription?.cancel();
    _eventsSubscription?.cancel();
    _chatsSubscription = null;
    _eventsSubscription = null;
    _listeningUserId = null;
  }

  Future<void> showRemoteMessageNotification(RemoteMessage message) async {
    final data = message.data;
    final String notifType =
        (data['type'] ?? data['notificationType'] ?? 'chat')
            .toString()
            .toLowerCase();

    final String title = message.notification?.title ??
        (data['title'] ?? data['senderName'] ?? 'FYBTT').toString();
    final String body = message.notification?.body ??
        (data['body'] ?? data['message'] ?? 'New notification').toString();

    if (notifType == AlgorithmConfig.seasonRatingMessageType) {
      await showActivityAlertNotification(
        notificationId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        payloadData: {
          ...data,
          'notificationType': AlgorithmConfig.seasonRatingMessageType,
        },
      );
      return;
    }

    if (notifType == 'chat' ||
        notifType == 'group_chat' ||
        data.containsKey('chatRoomId')) {
      final String chatRoomId =
          (data['chatRoomId'] ?? data['chatId'] ?? data['groupId'] ?? '')
              .toString();
      final String senderId = (data['senderId'] ?? '').toString();
      final bool isGroup =
          data['isGroup'] == 'true' || data['isGroup'] == true;

      await showInteractiveChatNotification(
        chatRoomId: chatRoomId,
        senderId: senderId,
        senderName: title,
        messageText: body,
        isGroup: isGroup,
      );
    } else {
      await showActivityAlertNotification(
        notificationId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        payloadData: data,
      );
    }
  }

  Future<void> showInteractiveChatNotification({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String messageText,
    bool isGroup = false,
  }) async {
    if (chatRoomId.isEmpty) return;

    final Map<String, dynamic> payloadMap = {
      'category': 'chat_interactive',
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'isGroup': isGroup,
    };

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _chatChannel.id,
      _chatChannel.name,
      channelDescription: _chatChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1E4C7A),
      styleInformation: BigTextStyleInformation(
        messageText,
        contentTitle: senderName,
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          _kReplyActionId,
          'Reply',
          allowGeneratedReplies: true,
          showsUserInterface: false,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              label: 'Write your reply...',
            ),
          ],
        ),
        const AndroidNotificationAction(
          _kSendPhotoActionId,
          '📷 Send Photo',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          _kSendVideoActionId,
          '🎥 Send Video',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'CHAT_INTERACTIVE_CATEGORY',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      chatRoomId.hashCode,
      senderName,
      messageText,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  Future<void> showActivityAlertNotification({
    required int notificationId,
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) async {
    final String notifType =
        (payloadData['notificationType'] ?? payloadData['type'] ?? '')
            .toString();
    final bool isRatingPrompt =
        notifType == AlgorithmConfig.seasonRatingMessageType;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _activityChannel.id,
      _activityChannel.name,
      channelDescription: _activityChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0F766E),
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
      actions: isRatingPrompt
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                _kRateTeacherNowActionId,
                '⭐ Rate Teacher Now',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: isRatingPrompt ? 'SEASON_RATING_CATEGORY' : null,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadData),
    );
  }

  Future<void> handleNotificationResponse(
    NotificationResponse response, {
    required bool isFromBackground,
  }) async {
    if (response.payload == null || response.payload!.trim().isEmpty) return;

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.payload!) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final String actionId = response.actionId ?? '';
    final String chatRoomId = (data['chatRoomId'] ?? '').toString();
    final String senderId = (data['senderId'] ?? '').toString();
    final String senderName = (data['senderName'] ?? 'User').toString();
    final bool isGroup = data['isGroup'] == true;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (actionId == _kRateTeacherNowActionId) {
      _processTappedPayload({
        ...data,
        'notificationType': AlgorithmConfig.seasonRatingMessageType,
      });
      return;
    }

    if (actionId == _kReplyActionId) {
      final String replyText = (response.input ?? '').trim();
      if (replyText.isNotEmpty &&
          currentUserId != null &&
          chatRoomId.isNotEmpty) {
        final chatService = ChatService();
        await chatService.sendMessage(
          chatId: chatRoomId,
          senderId: currentUserId,
          receiverId: isGroup ? 'group' : senderId,
          message: replyText,
          type: 'text',
        );
        await _localNotifications.cancel(chatRoomId.hashCode);
      }
      return;
    }

    if (actionId == _kSendPhotoActionId || actionId == _kSendVideoActionId) {
      final String mediaType =
          actionId == _kSendPhotoActionId ? 'photo' : 'video';
      final Map<String, dynamic> mediaRequest = {
        'chatRoomId': chatRoomId,
        'receiverId': isGroup ? 'group' : senderId,
        'receiverName': senderName,
        'mediaType': mediaType,
      };

      if (navigatorKey.currentContext != null) {
        _openQuickMediaReplyDialog(
          context: navigatorKey.currentContext!,
          chatRoomId: chatRoomId,
          receiverId: isGroup ? 'group' : senderId,
          receiverName: senderName,
          mediaType: mediaType,
        );
      } else {
        _pendingMediaActionPayload = mediaRequest;
      }
      return;
    }

    _processTappedPayload(data);
  }

  void consumePendingMediaActionIfNeeded(BuildContext context) {
    if (_pendingMediaActionPayload != null) {
      final payload = Map<String, dynamic>.from(_pendingMediaActionPayload!);
      _pendingMediaActionPayload = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openQuickMediaReplyDialog(
          context: context,
          chatRoomId: (payload['chatRoomId'] ?? '').toString(),
          receiverId: (payload['receiverId'] ?? '').toString(),
          receiverName: (payload['receiverName'] ?? 'User').toString(),
          mediaType: (payload['mediaType'] ?? 'photo').toString(),
        );
      });
    }

    if (_pendingRatingActionPayload != null) {
      final ratingPayload =
          Map<String, dynamic>.from(_pendingRatingActionPayload!);
      _pendingRatingActionPayload = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        openDirectSeasonalRatingSheet(
          context: context,
          teacherId: (ratingPayload['teacherId'] ?? '').toString(),
          teacherName: (ratingPayload['teacherName'] ?? 'Teacher').toString(),
          seasonId: (ratingPayload['seasonId'] ?? SeasonModel.current().id)
              .toString(),
          connectionId: (ratingPayload['connectionId'] ?? '').toString(),
          initialSubjectId:
              (ratingPayload['subjectId'] ?? 'general').toString(),
        );
      });
    }
  }

  Future<void> openDirectSeasonalRatingSheet({
    required BuildContext context,
    required String teacherId,
    required String teacherName,
    String? seasonId,
    String? connectionId,
    String initialSubjectId = 'general',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || teacherId.isEmpty) return;

    final reviewService = ReviewService();
    final isEligible = await reviewService.canStudentReviewTeacher(
      studentId: currentUser.uid,
      teacherId: teacherId,
    );

    if (!context.mounted) return;

    if (!isEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only accepted connected students can submit or update a rating for this season.',
          ),
        ),
      );
      return;
    }

    final existingReview =
        await reviewService.getStudentReviewForCurrentSeason(
      studentId: currentUser.uid,
      teacherId: teacherId,
    );

    if (!context.mounted) return;

    double teaching = existingReview?.categories.teaching ?? 5.0;
    double behaviour = existingReview?.categories.behaviour ?? 5.0;
    double communication = existingReview?.categories.communication ?? 5.0;
    double knowledge = existingReview?.categories.knowledge ?? 5.0;
    double punctuality = existingReview?.categories.punctuality ?? 5.0;
    final TextEditingController commentController =
        TextEditingController(text: existingReview?.comment ?? '');
    final TextEditingController subjectController = TextEditingController(
      text: existingReview?.subjectId.isNotEmpty == true
          ? existingReview!.subjectId
          : initialSubjectId,
    );
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final overall = double.parse(
              ((teaching +
                          behaviour +
                          communication +
                          knowledge +
                          punctuality) /
                      5.0)
                  .toStringAsFixed(1),
            );

            Widget buildSliderRow(
              String label,
              double value,
              ValueChanged<double> onChanged,
            ) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 115,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: value,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8,
                        activeColor: const Color(0xFF1E4C7A),
                        label: value.toStringAsFixed(1),
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        value.toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(
                              Icons.stars_rounded,
                              color: Color(0xFF1E4C7A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingReview != null
                                      ? 'Update Season Rating for $teacherName'
                                      : 'Rate $teacherName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Overall Score: $overall ⭐ (${SeasonModel.current().name.displayName})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      buildSliderRow(
                        'Teaching Quality',
                        teaching,
                        (v) => setSheetState(() => teaching = v),
                      ),
                      buildSliderRow(
                        'Behaviour',
                        behaviour,
                        (v) => setSheetState(() => behaviour = v),
                      ),
                      buildSliderRow(
                        'Communication',
                        communication,
                        (v) => setSheetState(() => communication = v),
                      ),
                      buildSliderRow(
                        'Knowledge',
                        knowledge,
                        (v) => setSheetState(() => knowledge = v),
                      ),
                      buildSliderRow(
                        'Punctuality',
                        punctuality,
                        (v) => setSheetState(() => punctuality = v),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          labelText: 'Subject (e.g. Mathematics, Physics)',
                          prefixIcon: const Icon(
                            Icons.menu_book_rounded,
                            color: Color(0xFF1E4C7A),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Share your learning experience...',
                          prefixIcon: const Icon(
                            Icons.rate_review_rounded,
                            color: Color(0xFF1E4C7A),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E4C7A),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  final categories = CategoryRating(
                                    teaching: teaching,
                                    behaviour: behaviour,
                                    communication: communication,
                                    knowledge: knowledge,
                                    punctuality: punctuality,
                                  );

                                  final reviewModel = ReviewModel(
                                    id: existingReview?.id ?? '',
                                    teacherId: teacherId,
                                    studentId: currentUser.uid,
                                    studentName:
                                        currentUser.displayName ?? 'Student',
                                    studentPhotoUrl:
                                        currentUser.photoURL ?? '',
                                    connectionId: connectionId?.isNotEmpty ==
                                            true
                                        ? connectionId!
                                        : '${teacherId}_${currentUser.uid}',
                                    subjectId:
                                        subjectController.text.trim().isNotEmpty
                                            ? subjectController.text
                                                .trim()
                                                .toLowerCase()
                                            : 'general',
                                    seasonId: seasonId?.isNotEmpty == true
                                        ? seasonId!
                                        : SeasonModel.current().id,
                                    categories: categories,
                                    overallRating: categories.overallAverage,
                                    comment: commentController.text.trim(),
                                    createdAt: existingReview?.createdAt ??
                                        DateTime.now(),
                                  );

                                  final ok = await reviewService
                                      .submitOrUpdateReview(review: reviewModel);
                                  if (!sheetCtx.mounted) return;
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Thank you! Your seasonal rating has been saved.'
                                            : 'Could not submit rating. Please verify your connection.',
                                      ),
                                    ),
                                  );
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                ),
                          label: Text(
                            isSubmitting
                                ? 'Submitting...'
                                : (existingReview != null
                                    ? 'Update Season Rating'
                                    : 'Submit Verified Rating'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openQuickMediaReplyDialog({
    required BuildContext context,
    required String chatRoomId,
    required String receiverId,
    required String receiverName,
    required String mediaType,
  }) async {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || chatRoomId.isEmpty) return;

    final bool isVideo = mediaType == 'video';
    File? selectedFile;

    try {
      if (isVideo) {
        final XFile? pickedVideo =
            await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (pickedVideo != null) {
          selectedFile = File(pickedVideo.path);
        }
      } else {
        final XFile? pickedImage = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 82,
        );
        if (pickedImage != null) {
          selectedFile = File(pickedImage.path);
        }
      }
    } catch (_) {}

    if (selectedFile == null || !context.mounted) return;

    final TextEditingController reasonController = TextEditingController();
    bool isSending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.photo_camera_back_rounded,
                            color: const Color(0xFF1E4C7A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVideo
                                    ? 'Quick Send Video to $receiverName'
                                    : 'Quick Send Photo to $receiverName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'Direct Notification Media Reply',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!isVideo)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          selectedFile!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.video_file_rounded,
                                color: Colors.redAccent, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedFile!.path.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isVideo
                            ? 'Optional: Why are you sending this video?'
                            : 'Optional: Add a note or reason for this photo...',
                        hintText: isVideo
                            ? 'e.g. Solution video for Question 4...'
                            : 'e.g. Homework page 2 attached...',
                        prefixIcon: const Icon(Icons.notes_rounded,
                            color: Color(0xFF1E4C7A)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E4C7A),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isSending
                            ? null
                            : () async {
                                setSheetState(() => isSending = true);
                                final chatService = ChatService();
                                final String captionNote =
                                    reasonController.text.trim();
                                try {
                                  if (isVideo) {
                                    await chatService.sendVideoFile(
                                      chatRoomId: chatRoomId,
                                      senderId: currentUserId,
                                      receiverId: receiverId,
                                      file: selectedFile!,
                                    );
                                  } else {
                                    await chatService.sendImageFile(
                                      chatRoomId: chatRoomId,
                                      senderId: currentUserId,
                                      receiverId: receiverId,
                                      file: selectedFile!,
                                    );
                                  }

                                  if (captionNote.isNotEmpty) {
                                    await chatService.sendMessage(
                                      chatId: chatRoomId,
                                      senderId: currentUserId,
                                      receiverId: receiverId,
                                      message: isVideo
                                          ? '🎥 Video Note: $captionNote'
                                          : '📷 Photo Note: $captionNote',
                                      type: 'text',
                                    );
                                  }

                                  await _localNotifications
                                      .cancel(chatRoomId.hashCode);
                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                  }
                                } catch (_) {
                                  setSheetState(() => isSending = false);
                                }
                              },
                        icon: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                        label: Text(
                          isSending
                              ? 'Sending...'
                              : (isVideo
                                  ? 'Send Video & Note'
                                  : 'Send Photo & Note'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _processTappedPayload(Map<String, dynamic> data) {
    final String notifType =
        (data['notificationType'] ?? data['type'] ?? '').toString();

    if (notifType == AlgorithmConfig.seasonRatingMessageType) {
      final String teacherId =
          (data['teacherId'] ?? data['senderId'] ?? '').toString();
      if (teacherId.isEmpty) return;

      final Map<String, dynamic> ratingRequest = {
        'teacherId': teacherId,
        'teacherName':
            (data['teacherName'] ?? data['senderName'] ?? 'Teacher').toString(),
        'seasonId': (data['seasonId'] ?? SeasonModel.current().id).toString(),
        'connectionId': (data['connectionId'] ?? '').toString(),
        'subjectId': (data['subjectId'] ?? 'general').toString(),
      };

      if (navigatorKey.currentContext != null) {
        openDirectSeasonalRatingSheet(
          context: navigatorKey.currentContext!,
          teacherId: ratingRequest['teacherId'],
          teacherName: ratingRequest['teacherName'],
          seasonId: ratingRequest['seasonId'],
          connectionId: ratingRequest['connectionId'],
          initialSubjectId: ratingRequest['subjectId'],
        );
      } else {
        _pendingRatingActionPayload = ratingRequest;
      }
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> subscribeToGroupTopic(String groupId) async {
    if (groupId.trim().isEmpty) return;
    await _messaging.subscribeToTopic(groupId);
  }

  Future<void> unsubscribeFromGroupTopic(String groupId) async {
    if (groupId.trim().isEmpty) return;
    await _messaging.unsubscribeFromTopic(groupId);
  }

  Future<void> createInAppActivityNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    String senderPhoto = '',
    required String type,
    required String title,
    required String body,
    String? groupId,
    String? groupName,
  }) async {
    if (receiverId.trim().isEmpty || type == 'chat') return;

    await _firestore.collection('notifications').add({
      'receiverId': receiverId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'type': type,
      'title': title,
      'body': body,
      'message': body,
      'groupId': groupId ?? '',
      'groupName': groupName ?? '',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> sendPushNotification({
    required String recipientToken,
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) async {
    try {
      await _firestore.collection('fcm_push_queue').add({
        'recipientToken': recipientToken,
        'title': title,
        'body': body,
        'data': payloadData,
        'hasServiceAccountConfigured': _serviceAccountJsonFromEnv.isNotEmpty,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_serviceAccountJsonFromEnv.isNotEmpty) {
        final Map<String, dynamic> sa =
            jsonDecode(_serviceAccountJsonFromEnv) as Map<String, dynamic>;
        final String projectId = (sa['project_id'] ?? '').toString();
        if (projectId.isNotEmpty) {
          await http.post(
            Uri.parse(
                'https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': {
                'token': recipientToken,
                'notification': {'title': title, 'body': body},
                'data': payloadData.map(
                  (key, value) => MapEntry(key, value.toString()),
                ),
              },
            }),
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
