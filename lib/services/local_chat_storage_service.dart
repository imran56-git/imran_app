import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';

class LocalChatStorageService {
  static final LocalChatStorageService _instance =
      LocalChatStorageService._internal();
  factory LocalChatStorageService() => _instance;
  LocalChatStorageService._internal();

  Database? _database;
  final StreamController<String> _roomUpdateStreamController =
      StreamController<String>.broadcast();

  Stream<String> get roomUpdateStream => _roomUpdateStreamController.stream;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String databasesPath = await getDatabasesPath();
    final String path = p.join(databasesPath, 'fybtt_local_chat.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
                'ALTER TABLE local_messages ADD COLUMN localFilePath TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_messages (
        messageId TEXT PRIMARY KEY,
        chatRoomId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT,
        senderName TEXT,
        senderRole TEXT,
        content TEXT,
        type TEXT,
        timestamp INTEGER,
        status TEXT,
        mediaUrl TEXT,
        localFilePath TEXT,
        isDeletedForEveryone INTEGER DEFAULT 0,
        deletedForUsers TEXT,
        replyToMessageId TEXT,
        replyText TEXT,
        messageCategory TEXT,
        isPinned INTEGER DEFAULT 0,
        pollData TEXT,
        quizData TEXT,
        mediaMetaData TEXT,
        isSyncedWithServer INTEGER DEFAULT 1
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_room_time ON local_messages(chatRoomId, timestamp DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_room_cat ON local_messages(chatRoomId, messageCategory)');
  }

  Map<String, dynamic> _messageToDbMap(
      MessageModel message, String chatRoomId, {bool isSynced = true}) {
    String? localPath;
    if (message.mediaMetaData != null &&
        message.mediaMetaData!['localFilePath'] != null) {
      localPath = message.mediaMetaData!['localFilePath'].toString();
    }

    return {
      'messageId': message.messageId,
      'chatRoomId': chatRoomId,
      'senderId': message.senderId,
      'receiverId': message.receiverId,
      'senderName': message.senderName,
      'senderRole': message.senderRole,
      'content': message.content,
      'type': message.type,
      'timestamp': message.timestamp?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'status': message.status,
      'mediaUrl': message.mediaUrl,
      'localFilePath': localPath,
      'isDeletedForEveryone': message.isDeletedForEveryone ? 1 : 0,
      'deletedForUsers': jsonEncode(message.deletedForUsers),
      'replyToMessageId': message.replyToMessageId,
      'replyText': message.replyText,
      'messageCategory': message.messageCategory,
      'isPinned': message.isPinned ? 1 : 0,
      'pollData':
          message.pollData != null ? jsonEncode(message.pollData) : null,
      'quizData':
          message.quizData != null ? jsonEncode(message.quizData) : null,
      'mediaMetaData': message.mediaMetaData != null
          ? jsonEncode(message.mediaMetaData)
          : null,
      'isSyncedWithServer': isSynced ? 1 : 0,
    };
  }

  MessageModel _dbMapToMessage(Map<String, dynamic> map) {
    List<String> deletedUsers = [];
    if (map['deletedForUsers'] != null &&
        map['deletedForUsers'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['deletedForUsers'].toString());
        if (decoded is List) {
          deletedUsers = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    Map<String, dynamic>? poll;
    if (map['pollData'] != null && map['pollData'].toString().isNotEmpty) {
      try {
        poll = Map<String, dynamic>.from(jsonDecode(map['pollData'].toString()));
      } catch (_) {}
    }

    Map<String, dynamic>? quiz;
    if (map['quizData'] != null && map['quizData'].toString().isNotEmpty) {
      try {
        quiz = Map<String, dynamic>.from(jsonDecode(map['quizData'].toString()));
      } catch (_) {}
    }

    Map<String, dynamic>? mediaMeta;
    if (map['mediaMetaData'] != null &&
        map['mediaMetaData'].toString().isNotEmpty) {
      try {
        mediaMeta =
            Map<String, dynamic>.from(jsonDecode(map['mediaMetaData'].toString()));
      } catch (_) {}
    }

    if (map['localFilePath'] != null &&
        map['localFilePath'].toString().isNotEmpty) {
      mediaMeta ??= {};
      mediaMeta['localFilePath'] = map['localFilePath'].toString();
    }

    DateTime? time;
    if (map['timestamp'] != null) {
      final int ms = (map['timestamp'] as num).toInt();
      time = DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? 'student',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: time,
      status: map['status'] ?? 'sent',
      mediaUrl: map['mediaUrl'],
      isDeletedForEveryone: map['isDeletedForEveryone'] == 1,
      deletedForUsers: deletedUsers,
      starredBy: const [],
      reactions: const {},
      replyToMessageId: map['replyToMessageId'],
      replyText: map['replyText'],
      messageCategory: map['messageCategory'] ?? 'general',
      isPinned: map['isPinned'] == 1,
      pollData: poll,
      quizData: quiz,
      mediaMetaData: mediaMeta,
      isSyncedWithServer: map['isSyncedWithServer'] == 1,
    );
  }

  Future<void> saveMessage(MessageModel message, String chatRoomId,
      {bool isSynced = true}) async {
    final db = await database;
    await db.insert(
      'local_messages',
      _messageToDbMap(message, chatRoomId, isSynced: isSynced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> saveMessagesBatch(
      List<MessageModel> messages, String chatRoomId,
      {bool isSynced = true}) async {
    if (messages.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final msg in messages) {
      batch.insert(
        'local_messages',
        _messageToDbMap(msg, chatRoomId, isSynced: isSynced),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<List<MessageModel>> getMessages(String chatRoomId,
      {int limit = 100, int offset = 0}) async {
    return await getLocalMessages(
      chatRoomId: chatRoomId,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<MessageModel>> getLocalMessages({
    required String chatRoomId,
    String? categoryFilter,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    String whereClause = 'chatRoomId = ?';
    List<dynamic> whereArgs = [chatRoomId];

    if (categoryFilter != null &&
        categoryFilter.isNotEmpty &&
        categoryFilter != 'all') {
      whereClause += ' AND messageCategory = ?';
      whereArgs.add(categoryFilter);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'local_messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => _dbMapToMessage(m)).toList();
  }

  Stream<List<MessageModel>> streamLocalMessages({
    required String chatRoomId,
    String? categoryFilter,
  }) async* {
    yield await getLocalMessages(
      chatRoomId: chatRoomId,
      categoryFilter: categoryFilter,
    );

    await for (final updatedRoomId in _roomUpdateStreamController.stream) {
      if (updatedRoomId == chatRoomId) {
        yield await getLocalMessages(
          chatRoomId: chatRoomId,
          categoryFilter: categoryFilter,
        );
      }
    }
  }

  Future<void> updateLocalMediaPath({
    required String messageId,
    required String chatRoomId,
    required String localPath,
  }) async {
    final db = await database;
    await db.update(
      'local_messages',
      {'localFilePath': localPath},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> markMessageReadLocally(String messageId, String chatRoomId) async {
    final db = await database;
    await db.update(
      'local_messages',
      {'status': 'seen'},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> markAllMessagesReadLocally(String chatRoomId) async {
    final db = await database;
    await db.update(
      'local_messages',
      {'status': 'seen'},
      where: 'chatRoomId = ?',
      whereArgs: [chatRoomId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> deleteMessageForMeLocally(
      String messageId, String chatRoomId, String currentUserId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_messages',
      columns: ['deletedForUsers'],
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      List<String> deleted = [];
      try {
        final decoded = jsonDecode(maps.first['deletedForUsers']?.toString() ?? '[]');
        if (decoded is List) {
          deleted = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}

      if (!deleted.contains(currentUserId)) {
        deleted.add(currentUserId);
        await db.update(
          'local_messages',
          {'deletedForUsers': jsonEncode(deleted)},
          where: 'messageId = ?',
          whereArgs: [messageId],
        );
        _roomUpdateStreamController.add(chatRoomId);
      }
    }
  }

  Future<void> deleteMessageForEveryoneLocally(
      String messageId, String chatRoomId) async {
    final db = await database;
    await db.update(
      'local_messages',
      {
        'isDeletedForEveryone': 1,
        'content': 'This message was deleted',
        'mediaUrl': null,
        'localFilePath': null,
      },
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> updateMessageContentLocally({
    required String messageId,
    required String chatRoomId,
    required String newContent,
  }) async {
    final db = await database;
    await db.update(
      'local_messages',
      {'content': newContent},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> togglePinLocally({
    required String messageId,
    required String chatRoomId,
    required bool isPinned,
  }) async {
    final db = await database;
    await db.update(
      'local_messages',
      {'isPinned': isPinned ? 1 : 0},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }

  Future<void> updatePollVoteLocally({
    required String messageId,
    required String chatRoomId,
    required String userId,
    required int optionIndex,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_messages',
      columns: ['pollData'],
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (maps.isNotEmpty && maps.first['pollData'] != null) {
      try {
        final Map<String, dynamic> poll =
            Map<String, dynamic>.from(jsonDecode(maps.first['pollData'].toString()));
        final Map<String, dynamic> votes = poll['votes'] is Map
            ? Map<String, dynamic>.from(poll['votes'])
            : {};
        votes[userId] = optionIndex;
        poll['votes'] = votes;

        await db.update(
          'local_messages',
          {'pollData': jsonEncode(poll)},
          where: 'messageId = ?',
          whereArgs: [messageId],
        );
        _roomUpdateStreamController.add(chatRoomId);
      } catch (_) {}
    }
  }

  Future<void> updateQuizAnswerLocally({
    required String messageId,
    required String chatRoomId,
    required String userId,
    required int optionIndex,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_messages',
      columns: ['quizData'],
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (maps.isNotEmpty && maps.first['quizData'] != null) {
      try {
        final Map<String, dynamic> quiz =
            Map<String, dynamic>.from(jsonDecode(maps.first['quizData'].toString()));
        final Map<String, dynamic> submissions = quiz['submissions'] is Map
            ? Map<String, dynamic>.from(quiz['submissions'])
            : {};
        submissions[userId] = optionIndex;
        quiz['submissions'] = submissions;

        await db.update(
          'local_messages',
          {'quizData': jsonEncode(quiz)},
          where: 'messageId = ?',
          whereArgs: [messageId],
        );
        _roomUpdateStreamController.add(chatRoomId);
      } catch (_) {}
    }
  }

  Future<List<MessageModel>> searchMessagesLocally({
    required String chatRoomId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_messages',
      where: 'chatRoomId = ? AND content LIKE ?',
      whereArgs: [chatRoomId, '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => _dbMapToMessage(m)).toList();
  }

  Future<void> clearRoomLocally(String chatRoomId) async {
    final db = await database;
    await db.delete(
      'local_messages',
      where: 'chatRoomId = ?',
      whereArgs: [chatRoomId],
    );
    _roomUpdateStreamController.add(chatRoomId);
  }
}