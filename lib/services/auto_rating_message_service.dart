import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/algorithm_config.dart';
import '../models/follow_model.dart';
import '../models/message_model.dart';
import '../models/season_model.dart';

class AutoRatingMessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _buildChatRoomId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<int> sendSeasonRatingPromptsForTeacher({
    required String teacherId,
    SeasonModel? season,
  }) async {
    if (teacherId.isEmpty) return 0;

    try {
      final activeSeason = season ?? SeasonModel.current();
      final teacherDoc =
          await _firestore.collection('teachers').doc(teacherId).get();
      final teacherData = teacherDoc.data() ?? {};

      final String teacherName =
          teacherData['name']?.toString() ?? 'Your Teacher';
      final String teacherPhoto =
          teacherData['profilePic']?.toString() ??
          teacherData['photoUrl']?.toString() ??
          '';
      final bool isVerified =
          teacherData['isVerifiedBadge'] == true ||
          teacherData['isVerified'] == true;
      final bool isGolden = teacherData['isGoldenBadge'] == true;

      final acceptedConnectionsSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'accepted')
          .get();

      int sentCount = 0;

      for (final doc in acceptedConnectionsSnap.docs) {
        final follow = FollowModel.fromMap(doc.data(), doc.id);

        if (!follow.isEligibleToRate) continue;
        if (follow.lastPromptedSeasonId == activeSeason.id) continue;
        if (follow.lastRatedSeasonId == activeSeason.id) continue;

        final String studentId = follow.studentId;
        if (studentId.isEmpty) continue;

        final String studentName = follow.studentName.isNotEmpty
            ? follow.studentName
            : 'Student';
        final String primarySubject =
            follow.subjects.isNotEmpty ? follow.subjects.first : 'general';

        final String chatRoomId = _buildChatRoomId(teacherId, studentId);
        final String deterministicMessageId =
            'season_prompt_${activeSeason.id}_${teacherId}_$studentId';

        final promptMessage = MessageModel.createSeasonRatingPrompt(
          messageId: deterministicMessageId,
          teacherId: teacherId,
          studentId: studentId,
          teacherName: teacherName,
          studentName: studentName,
          teacherProfilePic:
              teacherPhoto.isNotEmpty ? teacherPhoto : follow.teacherPhoto,
          seasonId: activeSeason.id,
          seasonName: activeSeason.name.displayName,
          connectionId: follow.id,
          subjectId: primarySubject,
          isTeacherVerified: isVerified,
          hasTeacherGoldenBadge: isGolden,
        );

        final batch = _firestore.batch();

        final chatDocRef = _firestore.collection('chats').doc(chatRoomId);
        batch.set(chatDocRef, {
          'chatId': chatRoomId,
          'participants': [teacherId, studentId],
          'lastMessage': promptMessage.content,
          'lastMessageType': AlgorithmConfig.seasonRatingMessageType,
          'lastMessageSenderId': teacherId,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final chatMessageRef =
            chatDocRef.collection('messages').doc(deterministicMessageId);
        batch.set(chatMessageRef, promptMessage.toMap(), SetOptions(merge: true));

        final rootMessageRef =
            _firestore.collection('messages').doc(deterministicMessageId);
        batch.set(rootMessageRef, promptMessage.toMap(), SetOptions(merge: true));

        final notificationRef = _firestore
            .collection('notifications')
            .doc('notif_$deterministicMessageId');
        batch.set(notificationRef, {
          'id': 'notif_$deterministicMessageId',
          'receiverId': studentId,
          'senderId': teacherId,
          'senderName': teacherName,
          'senderPhoto':
              teacherPhoto.isNotEmpty ? teacherPhoto : follow.teacherPhoto,
          'title': 'New Rating Season Started!',
          'body':
              'Please rate your learning experience with $teacherName for ${activeSeason.name.displayName}.',
          'type': AlgorithmConfig.seasonRatingMessageType,
          'seasonId': activeSeason.id,
          'teacherId': teacherId,
          'connectionId': follow.id,
          'subjectId': primarySubject,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        batch.set(doc.reference, {
          'lastPromptedSeasonId': activeSeason.id,
        }, SetOptions(merge: true));

        await batch.commit();
        sentCount++;
      }

      return sentCount;
    } catch (e) {
      debugPrint('Error sending season rating prompts for teacher: $e');
      return 0;
    }
  }

  Future<void> broadcastNewSeasonPromptsToAllConnectedStudents({
    SeasonModel? season,
  }) async {
    try {
      final activeSeason = season ?? SeasonModel.current();
      final seasonRef =
          _firestore.collection('seasons').doc(activeSeason.id);
      final seasonSnap = await seasonRef.get();

      if (seasonSnap.exists &&
          seasonSnap.data()?['promptBroadcastSent'] == true) {
        return;
      }

      final teachersSnap = await _firestore.collection('teachers').get();
      for (final teacherDoc in teachersSnap.docs) {
        await sendSeasonRatingPromptsForTeacher(
          teacherId: teacherDoc.id,
          season: activeSeason,
        );
      }

      await seasonRef.set({
        'promptBroadcastSent': true,
        'promptBroadcastAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error broadcasting seasonal rating prompts: $e');
    }
  }

  Future<bool> sendSingleStudentRatingPrompt({
    required String teacherId,
    required String studentId,
  }) async {
    if (teacherId.isEmpty || studentId.isEmpty) return false;

    try {
      final activeSeason = SeasonModel.current();
      final connectionId = '${teacherId}_$studentId';
      final connDoc = await _firestore
          .collection('follow_requests')
          .doc(connectionId)
          .get();

      if (!connDoc.exists || connDoc.data() == null) return false;

      final follow = FollowModel.fromMap(connDoc.data()!, connDoc.id);
      if (!follow.isEligibleToRate) return false;

      final String deterministicMessageId =
          'season_prompt_${activeSeason.id}_${teacherId}_$studentId';
      final String chatRoomId = _buildChatRoomId(teacherId, studentId);

      final promptMessage = MessageModel.createSeasonRatingPrompt(
        messageId: deterministicMessageId,
        teacherId: teacherId,
        studentId: studentId,
        teacherName:
            follow.teacherName.isNotEmpty ? follow.teacherName : 'Teacher',
        studentName:
            follow.studentName.isNotEmpty ? follow.studentName : 'Student',
        teacherProfilePic: follow.teacherPhoto,
        seasonId: activeSeason.id,
        seasonName: activeSeason.name.displayName,
        connectionId: follow.id,
        subjectId:
            follow.subjects.isNotEmpty ? follow.subjects.first : 'general',
      );

      final batch = _firestore.batch();

      final chatDocRef = _firestore.collection('chats').doc(chatRoomId);
      batch.set(chatDocRef, {
        'chatId': chatRoomId,
        'participants': [teacherId, studentId],
        'lastMessage': promptMessage.content,
        'lastMessageType': AlgorithmConfig.seasonRatingMessageType,
        'lastMessageSenderId': teacherId,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(
        chatDocRef.collection('messages').doc(deterministicMessageId),
        promptMessage.toMap(),
        SetOptions(merge: true),
      );

      batch.set(
        _firestore.collection('messages').doc(deterministicMessageId),
        promptMessage.toMap(),
        SetOptions(merge: true),
      );

      batch.set(connDoc.reference, {
        'lastPromptedSeasonId': activeSeason.id,
      }, SetOptions(merge: true));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error sending single student rating prompt: $e');
      return false;
    }
  }
}
