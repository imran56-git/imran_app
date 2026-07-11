import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _getLocalBackupFile(String chatId) async {
    final path = await _localPath;
    return File('$path/backup_$chatId.json');
  }

  Future<bool> createLocalBackup(String chatId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      final List<Map<String, dynamic>> messagesList = [];

      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
        }
        if (data['editTimestamp'] != null && data['editTimestamp'] is Timestamp) {
          data['editTimestamp'] = (data['editTimestamp'] as Timestamp).millisecondsSinceEpoch;
        }
        messagesList.add(data);
      }

      final String jsonExport = jsonEncode({
        'chatId': chatId,
        'backupVersion': '1.0.0',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messages': messagesList,
      });

      final file = await _getLocalBackupFile(chatId);
      await file.writeAsString(jsonExport);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreLocalBackup(String chatId) async {
    try {
      final file = await _getLocalBackupFile(chatId);
      if (!await file.exists()) return false;

      final String fileContent = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(fileContent);
      final List<dynamic> messages = backupData['messages'] ?? [];

      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('chats').doc(chatId).collection('messages');

      final existingMessages = await collectionRef.get();
      for (var doc in existingMessages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      final restoreBatch = _firestore.batch();
      for (var msg in messages) {
        final Map<String, dynamic> messageMap = Map<String, dynamic>.from(msg);
        if (messageMap['timestamp'] != null) {
          messageMap['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(messageMap['timestamp'] as int);
        }
        if (messageMap['editTimestamp'] != null) {
          messageMap['editTimestamp'] = Timestamp.fromMillisecondsSinceEpoch(messageMap['editTimestamp'] as int);
        }
        
        final docRef = collectionRef.doc(messageMap['messageId']);
        restoreBatch.set(docRef, messageMap);
      }

      await restoreBatch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLocalBackup(String chatId) async {
    try {
      final file = await _getLocalBackupFile(chatId);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
