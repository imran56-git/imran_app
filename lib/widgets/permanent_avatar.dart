import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class PermanentAvatarStorage {
  static final Map<String, File> _memoryCache = {};
  static final Set<String> _inProgress = {};

  static String _urlHash(String url) {
    final bytes = utf8.encode(url.trim());
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<Directory> _getAvatarDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${docDir.path}/fybtt_permanent_avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    return avatarDir;
  }

  static Future<File?> getOrDownloadAvatar({
    required String userId,
    required String imageUrl,
  }) async {
    final cleanUrl = imageUrl.trim();
    if (userId.trim().isEmpty ||
        (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
      return null;
    }

    final hash = _urlHash(cleanUrl);
    final cacheKey = '${userId}_$hash';

    if (_memoryCache.containsKey(cacheKey) &&
        await _memoryCache[cacheKey]!.exists()) {
      return _memoryCache[cacheKey];
    }

    try {
      final dir = await _getAvatarDir();
      final targetFile = File('${dir.path}/$cacheKey.jpg');

      if (await targetFile.exists() && await targetFile.length() > 0) {
        _memoryCache[cacheKey] = targetFile;
        return targetFile;
      }

      if (_inProgress.contains(cacheKey)) return null;
      _inProgress.add(cacheKey);

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(cleanUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, element) => prev..addAll(element),
        );
        if (bytes.isNotEmpty) {
          // Delete old avatar files for this specific userId when photo changes
          final existingFiles = dir.listSync();
          for (final entity in existingFiles) {
            if (entity is File &&
                entity.path.contains('${userId}_') &&
                entity.path != targetFile.path) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }

          await targetFile.writeAsBytes(bytes, flush: true);
          _memoryCache[cacheKey] = targetFile;
          _inProgress.remove(cacheKey);
          return targetFile;
        }
      }
      _inProgress.remove(cacheKey);
    } catch (_) {
      _inProgress.remove(cacheKey);
    }
    return null;
  }
}

class PermanentProfileAvatar extends StatefulWidget {
  final String userId;
  final String imageUrl;
  final String fallbackName;
  final double radius;
  final List<Color> gradientColors;
  final bool isGroup;

  const PermanentProfileAvatar({
    super.key,
    required this.userId,
    required this.imageUrl,
    required this.fallbackName,
    this.radius = 24,
    this.gradientColors = const [Color(0xFF1E4C7A), Color(0xFF2563EB)],
    this.isGroup = false,
  });

  @override
  State<PermanentProfileAvatar> createState() => _PermanentProfileAvatarState();
}

class _PermanentProfileAvatarState extends State<PermanentProfileAvatar> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _resolveAvatar();
  }

  @override
  void didUpdateWidget(covariant PermanentProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.userId != widget.userId) {
      _resolveAvatar();
    }
  }

  Future<void> _resolveAvatar() async {
    final file = await PermanentAvatarStorage.getOrDownloadAvatar(
      userId: widget.userId,
      imageUrl: widget.imageUrl,
    );
    if (mounted && file != null) {
      setState(() => _localFile = file);
    }
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final double diameter = widget.radius * 2;
    final cleanUrl = widget.imageUrl.trim();
    final bool hasValidUrl =
        cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');

    if (_localFile != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.gradientColors.first,
        backgroundImage: FileImage(_localFile!),
      );
    }

    if (hasValidUrl) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.gradientColors.first,
        backgroundImage: NetworkImage(cleanUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: widget.isGroup
          ? Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: widget.radius * 0.95,
            )
          : Text(
              _getInitials(widget.fallbackName),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: widget.radius * 0.65,
              ),
            ),
    );
  }
}
