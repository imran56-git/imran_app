import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';

class LocalChatStorageService {
  static final LocalChatStorageService _instance =
      LocalChatStorageService._internal();
  factory LocalChatStorageService() => _instance;
  LocalChatStorageService._internal();

  Database? _database;
  final Dio _dio = Dio();
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
      version: 3,
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
        if (oldVersion < 3) {
          try {
            await db.execute(
                'ALTER TABLE local_messages ADD COLUMN localFilePaths TEXT');
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
        localFilePaths TEXT,
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
    String? localPathsJson;

    if (message.mediaMetaData != null) {
      if (message.mediaMetaData!['localFilePath'] != null) {
        localPath = message.mediaMetaData!['localFilePath'].toString();
      }

      if (message.mediaMetaData!['localFilePaths'] != null) {
        final rawPaths = message.mediaMetaData!['localFilePaths'];
        if (rawPaths is List) {
          final stringList = rawPaths.map((e) => e.toString()).toList();
          localPathsJson = jsonEncode(stringList);
          if (localPath == null && stringList.isNotEmpty) {
            localPath = stringList.first;
          }
        }
      }
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
      'localFilePaths': localPathsJson,
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
    List<String> deletedUsers = <String>[];
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

    String? singleLocalPath = map['localFilePath']?.toString();
    List<String> multiLocalPaths = <String>[];

    if (map['localFilePaths'] != null &&
        map['localFilePaths'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['localFilePaths'].toString());
        if (decoded is List) {
          multiLocalPaths = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    if (singleLocalPath != null && singleLocalPath.isNotEmpty) {
      mediaMeta ??= <String, dynamic>{};
      mediaMeta['localFilePath'] = singleLocalPath;
    }

    if (multiLocalPaths.isNotEmpty) {
      mediaMeta ??= <String, dynamic>{};
      mediaMeta['localFilePaths'] = multiLocalPaths;
      mediaMeta['imageUrls'] = multiLocalPaths;
      mediaMeta['urls'] = multiLocalPaths;
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
      starredBy: const <String>[],
      reactions: const <String, dynamic>{},
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

  Future<Directory> getPermanentMediaDirectory(String subFolder) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docsDir.path, 'fybtt_chat_media', subFolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  Future<String> copyFileToPermanentStorage(File sourceFile, {String subFolder = 'media'}) async {
    if (!await sourceFile.exists()) {
      return sourceFile.path;
    }

    final targetDir = await getPermanentMediaDirectory(subFolder);
    final ext = p.extension(sourceFile.path);
    final fileName = 'fybtt_${DateTime.now().microsecondsSinceEpoch}_${p.basenameWithoutExtension(sourceFile.path)}$ext';
    final permanentFile = File(p.join(targetDir.path, fileName));

    if (sourceFile.path == permanentFile.path) {
      return permanentFile.path;
    }

    await sourceFile.copy(permanentFile.path);
    return permanentFile.path;
  }

  Future<String?> downloadMediaFile(String url, {String subFolder = 'media'}) async {
    if (url.isEmpty || !url.startsWith('http')) return null;

    try {
      final targetDir = await getPermanentMediaDirectory(subFolder);
      final uri = Uri.parse(url);
      final rawName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media_file';
      final cleanName = rawName.contains('?') ? rawName.split('?').first : rawName;
      final ext = p.extension(cleanName).isNotEmpty ? p.extension(cleanName) : '.dat';
      final fileName = 'dl_${DateTime.now().microsecondsSinceEpoch}_${cleanName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}$ext';
      final savePath = p.join(targetDir.path, fileName);

      final response = await _dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );

      if (response.statusCode == 200 && await File(savePath).exists()) {
        return savePath;
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> downloadAlbumFiles(List<String> urls, {String subFolder = 'albums'}) async {
    if (urls.isEmpty) return <String>[];

    final downloadFutures = urls.map((url) async {
      final localPath = await downloadMediaFile(url, subFolder: subFolder);
      return localPath ?? url;
    });

    final results = await Future.wait(downloadFutures);
    return results;
  }

  Future<MessageModel> saveOutgoingMessageWithPermanentFiles(
      MessageModel message, String chatRoomId) async {
    Map<String, dynamic> updatedMeta = Map<String, dynamic>.from(message.mediaMetaData ?? {});

    if (updatedMeta['localFilePath'] != null) {
      final rawPath = updatedMeta['localFilePath'].toString();
      final srcFile = File(rawPath);
      if (await srcFile.exists()) {
        final permPath = await copyFileToPermanentStorage(srcFile, subFolder: 'sent_media');
        updatedMeta['localFilePath'] = permPath;
      }
    }

    if (updatedMeta['localFilePaths'] != null && updatedMeta['localFilePaths'] is List) {
      final rawList = updatedMeta['localFilePaths'] as List;
      final List<String> permPaths = <String>[];
      for (final item in rawList) {
        final srcFile = File(item.toString());
        if (await srcFile.exists()) {
          final permPath = await copyFileToPermanentStorage(srcFile, subFolder: 'sent_albums');
          permPaths.add(permPath);
        } else {
          permPaths.add(item.toString());
        }
      }
      updatedMeta['localFilePaths'] = permPaths;
      updatedMeta['imageUrls'] = permPaths;
      updatedMeta['urls'] = permPaths;
      if (permPaths.isNotEmpty && updatedMeta['localFilePath'] == null) {
        updatedMeta['localFilePath'] = permPaths.first;
      }
    }

    final updatedMessage = message.copyWith(mediaMetaData: updatedMeta);
    await saveMessage(updatedMessage, chatRoomId, isSynced: true);
    return updatedMessage;
  }

  Future<MessageModel> processAndSaveIncomingMessage(
      MessageModel message, String chatRoomId) async {
    Map<String, dynamic> updatedMeta = Map<String, dynamic>.from(message.mediaMetaData ?? {});
    final msgType = message.type.toLowerCase();

    if (msgType == 'album') {
      List<String> remoteUrls = <String>[];
      if (updatedMeta['imageUrls'] is List) {
        remoteUrls = (updatedMeta['imageUrls'] as List).map((e) => e.toString()).toList();
      } else if (updatedMeta['urls'] is List) {
        remoteUrls = (updatedMeta['urls'] as List).map((e) => e.toString()).toList();
      }

      if (remoteUrls.isNotEmpty) {
        final localAlbumPaths = await downloadAlbumFiles(remoteUrls, subFolder: 'received_albums');
        updatedMeta['localFilePaths'] = localAlbumPaths;
        updatedMeta['imageUrls'] = localAlbumPaths;
        updatedMeta['urls'] = localAlbumPaths;
        if (localAlbumPaths.isNotEmpty) {
          updatedMeta['localFilePath'] = localAlbumPaths.first;
        }
      }
    } else if (msgType == 'image' || msgType == 'video' || msgType == 'audio' || msgType == 'voice' || msgType == 'document' || msgType == 'file') {
      String? remoteUrl = message.mediaUrl;
      if (remoteUrl == null || remoteUrl.isEmpty) {
        remoteUrl = updatedMeta['imageUrl']?.toString() ??
            updatedMeta['audioUrl']?.toString() ??
            updatedMeta['videoUrl']?.toString() ??
            updatedMeta['fileUrl']?.toString() ??
            updatedMeta['url']?.toString();
      }

      if (remoteUrl != null && remoteUrl.startsWith('http')) {
        final downloadedPath = await downloadMediaFile(remoteUrl, subFolder: 'received_media');
        if (downloadedPath != null) {
          updatedMeta['localFilePath'] = downloadedPath;
        }
      }
    }

    final updatedMessage = message.copyWith(mediaMetaData: updatedMeta);
    await saveMessage(updatedMessage, chatRoomId, isSynced: true);
    return updatedMessage;
  }

  Future<bool> hasMessage(String messageId) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      'local_messages',
      columns: ['messageId'],
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<MessageModel?> getMessageById(String messageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_messages',
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _dbMapToMessage(maps.first);
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

  Future<void> updateLocalMediaPaths({
    required String messageId,
    required String chatRoomId,
    String? localFilePath,
    List<String>? localFilePaths,
  }) async {
    final db = await database;
    final Map<String, dynamic> updateValues = {};

    if (localFilePath != null) {
      updateValues['localFilePath'] = localFilePath;
    }

    if (localFilePaths != null) {
      updateValues['localFilePaths'] = jsonEncode(localFilePaths);
      if (localFilePath == null && localFilePaths.isNotEmpty) {
        updateValues['localFilePath'] = localFilePaths.first;
      }
    }

    if (updateValues.isNotEmpty) {
      await db.update(
        'local_messages',
        updateValues,
        where: 'messageId = ?',
        whereArgs: [messageId],
      );
      _roomUpdateStreamController.add(chatRoomId);
    }
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
      List<String> deleted = <String>[];
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
        'localFilePaths': null,
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
            : <String, dynamic>{};
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
            : <String, dynamic>{};
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
    if (query.trim().isEmpty) return <MessageModel>[];
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