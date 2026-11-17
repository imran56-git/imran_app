import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class PermanentAvatarStorage {
  static const String _folderName = 'fybtt_permanent_avatars';
  static const String bannerPrefix = 'banner_';

  static final Map<String, File> _memoryCache = {};
  static final Map<String, Future<File?>> _inFlight = {};
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  static Directory? _avatarDirCache;
  static Future<Directory>? _dirInitFuture;

  /// Sanitizes ownerId so filenames are always filesystem-safe.
  static String _sanitizeOwnerId(String ownerId) {
    return ownerId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  /// Generates a compact, deterministic 16-char lowercase FNV-1a 64-bit hex hash.
  /// Keeps filenames well under Android's 255-character limit regardless of URL length.
  static String _urlHash(String url) {
    final bytes = utf8.encode(url.trim());
    BigInt hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final BigInt prime = BigInt.parse('100000001b3', radix: 16);
    final BigInt mask = BigInt.parse('ffffffffffffffff', radix: 16);

    for (final byte in bytes) {
      hash = hash ^ BigInt.from(byte);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static bool _isValidHttpUrl(String url) {
    final clean = url.trim();
    return clean.startsWith('http://') || clean.startsWith('https://');
  }

  static String _buildCacheKey(String safeOwnerId, String cleanUrl) {
    return '${safeOwnerId}_${_urlHash(cleanUrl)}';
  }

  static Future<Directory> _getAvatarDir() {
    if (_avatarDirCache != null) {
      return Future.value(_avatarDirCache!);
    }
    _dirInitFuture ??= _initAvatarDir();
    return _dirInitFuture!;
  }

  static Future<Directory> _initAvatarDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${docDir.path}/$_folderName');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    _avatarDirCache = avatarDir;
    await _indexExistingFiles(avatarDir);
    return avatarDir;
  }

  /// Indexes all valid cached files on disk into memory for instant Frame-1 lookups.
  static Future<void> _indexExistingFiles(Directory dir) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final fileName = entity.path.split(Platform.pathSeparator).last;
        if (fileName.endsWith('.tmp')) {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }
        if (!fileName.endsWith('.jpg')) continue;

        final stat = await entity.stat();
        if (stat.size <= 0) {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }

        final key = fileName.substring(0, fileName.length - 4);
        _memoryCache[key] = entity;
      }
    } catch (_) {}
  }

  /// Optional warm-up call (e.g., at app startup) so Frame-1 cache is ready even on the very first screen.
  static Future<void> warmUp() async {
    try {
      await _getAvatarDir();
    } catch (_) {}
  }

  /// Synchronous 0ms Frame-1 lookup from memory (or cached directory path).
  static File? getCachedFileSync({
    required String userId,
    required String imageUrl,
  }) {
    final cleanUrl = imageUrl.trim();
    final safeOwner = _sanitizeOwnerId(userId);
    if (safeOwner.isEmpty || !_isValidHttpUrl(cleanUrl)) {
      return null;
    }

    final cacheKey = _buildCacheKey(safeOwner, cleanUrl);
    final memFile = _memoryCache[cacheKey];
    if (memFile != null) {
      return memFile;
    }

    final dir = _avatarDirCache;
    if (dir != null) {
      final candidate = File('${dir.path}/$cacheKey.jpg');
      if (candidate.existsSync() && candidate.lengthSync() > 0) {
        _memoryCache[cacheKey] = candidate;
        return candidate;
      }
    }
    return null;
  }

  /// Synchronous Frame-1 lookup for a user's Cover Banner (`banner_<uid>`).
  static File? getCachedBannerSync({
    required String userId,
    required String imageUrl,
  }) {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return null;
    return getCachedFileSync(
      userId: '$bannerPrefix$cleanId',
      imageUrl: imageUrl,
    );
  }

  /// Returns an instant [ImageProvider] (local [FileImage] if cached, otherwise [NetworkImage] if valid URL).
  static ImageProvider? getImageProviderSync({
    required String ownerId,
    required String imageUrl,
  }) {
    final cached = getCachedFileSync(userId: ownerId, imageUrl: imageUrl);
    if (cached != null) return FileImage(cached);
    final cleanUrl = imageUrl.trim();
    if (_isValidHttpUrl(cleanUrl)) {
      return NetworkImage(cleanUrl);
    }
    return null;
  }

  /// Returns the permanent local [File] for [userId] + [imageUrl], downloading & persisting it if needed.
  /// Automatically deletes older cached files belonging to [userId] when the photo changes.
  static Future<File?> getOrDownloadAvatar({
    required String userId,
    required String imageUrl,
  }) async {
    final cleanUrl = imageUrl.trim();
    final safeOwner = _sanitizeOwnerId(userId);
    if (safeOwner.isEmpty || !_isValidHttpUrl(cleanUrl)) {
      return null;
    }

    final cacheKey = _buildCacheKey(safeOwner, cleanUrl);

    final memFile = _memoryCache[cacheKey];
    if (memFile != null && await memFile.exists()) {
      return memFile;
    }

    final existingInFlight = _inFlight[cacheKey];
    if (existingInFlight != null) {
      return existingInFlight;
    }

    final future = _resolveAndDownload(
      safeOwner: safeOwner,
      cacheKey: cacheKey,
      cleanUrl: cleanUrl,
    );
    _inFlight[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Downloads & permanently caches a Cover Banner under `banner_<userId>`.
  static Future<File?> getOrDownloadBanner({
    required String userId,
    required String imageUrl,
  }) {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return Future.value(null);
    return getOrDownloadAvatar(
      userId: '$bannerPrefix$cleanId',
      imageUrl: imageUrl,
    );
  }

  /// Fire-and-forget pre-cache helper for avatars.
  static Future<void> precacheAvatar({
    required String userId,
    required String imageUrl,
  }) async {
    await getOrDownloadAvatar(userId: userId, imageUrl: imageUrl);
  }

  /// Fire-and-forget pre-cache helper for cover banners.
  static Future<void> precacheBanner({
    required String userId,
    required String imageUrl,
  }) async {
    await getOrDownloadBanner(userId: userId, imageUrl: imageUrl);
  }

  /// Removes a single corrupted cached file and evicts it from memory.
  static Future<void> _invalidateCorruptedFile({
    required String userId,
    required String imageUrl,
  }) async {
    final safeOwner = _sanitizeOwnerId(userId);
    final cleanUrl = imageUrl.trim();
    if (safeOwner.isEmpty || !_isValidHttpUrl(cleanUrl)) return;

    final cacheKey = _buildCacheKey(safeOwner, cleanUrl);
    final file = _memoryCache.remove(cacheKey);
    if (file != null) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Clears all locally cached images for a specific ownerId (e.g., when photo is removed).
  static Future<void> clearOwnerCache(String ownerId) async {
    final safeOwner = _sanitizeOwnerId(ownerId);
    if (safeOwner.isEmpty) return;

    final prefix = '${safeOwner}_';
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));

    try {
      final dir = await _getAvatarDir();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final fileName = entity.path.split(Platform.pathSeparator).last;
        if (fileName.startsWith(prefix)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<File?> _resolveAndDownload({
    required String safeOwner,
    required String cacheKey,
    required String cleanUrl,
  }) async {
    try {
      final dir = await _getAvatarDir();
      final targetFileName = '$cacheKey.jpg';
      final targetFile = File('${dir.path}/$targetFileName');

      if (await targetFile.exists()) {
        final len = await targetFile.length();
        if (len > 0) {
          _memoryCache[cacheKey] = targetFile;
          return targetFile;
        }
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      final request = await _httpClient.getUrl(Uri.parse(cleanUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, element) => prev..addAll(element),
        );

        if (bytes.isNotEmpty) {
          // Atomic write via temporary file so partial writes never corrupt cache.
          final tempFile = File('${targetFile.path}.tmp');
          await tempFile.writeAsBytes(bytes, flush: true);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(targetFile.path);

          // Delete older avatar/banner files strictly for this exact owner prefix.
          final ownerPrefix = '${safeOwner}_';
          _memoryCache.removeWhere(
            (key, _) => key.startsWith(ownerPrefix) && key != cacheKey,
          );

          await for (final entity in dir.list(followLinks: false)) {
            if (entity is! File) continue;
            final fileName = entity.path.split(Platform.pathSeparator).last;
            if (fileName.startsWith(ownerPrefix) &&
                fileName.endsWith('.jpg') &&
                fileName != targetFileName) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }

          _memoryCache[cacheKey] = targetFile;
          return targetFile;
        }
      }
    } catch (_) {}
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
  final File? localOverrideFile;

  const PermanentProfileAvatar({
    super.key,
    required this.userId,
    required this.imageUrl,
    required this.fallbackName,
    this.radius = 24,
    this.gradientColors = const [Color(0xFF1E4C7A), Color(0xFF2563EB)],
    this.isGroup = false,
    this.localOverrideFile,
  });

  @override
  State<PermanentProfileAvatar> createState() => _PermanentProfileAvatarState();
}

class _PermanentProfileAvatarState extends State<PermanentProfileAvatar> {
  File? _localFile;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    // 0ms synchronous Frame-1 lookup to prevent any blank avatar flicker.
    _localFile = PermanentAvatarStorage.getCachedFileSync(
      userId: widget.userId,
      imageUrl: widget.imageUrl,
    );
    _resolveAvatar();
  }

  @override
  void didUpdateWidget(covariant PermanentProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.userId != widget.userId) {
      _imageLoadFailed = false;
      _localFile = PermanentAvatarStorage.getCachedFileSync(
        userId: widget.userId,
        imageUrl: widget.imageUrl,
      );
      _resolveAvatar();
    }
  }

  Future<void> _resolveAvatar() async {
    final cleanUrl = widget.imageUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      if (mounted && _localFile != null) {
        setState(() => _localFile = null);
      }
      return;
    }

    final reqUserId = widget.userId;
    final reqUrl = widget.imageUrl;

    final file = await PermanentAvatarStorage.getOrDownloadAvatar(
      userId: reqUserId,
      imageUrl: reqUrl,
    );

    if (!mounted ||
        widget.userId != reqUserId ||
        widget.imageUrl != reqUrl) {
      return;
    }

    if (file != null && _localFile?.path != file.path) {
      setState(() {
        _localFile = file;
        _imageLoadFailed = false;
      });
    }
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildFallback(double diameter) {
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

  @override
  Widget build(BuildContext context) {
    final double diameter = widget.radius * 2;
    final cleanUrl = widget.imageUrl.trim();
    final bool hasValidUrl =
        cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');

    final File? activeFile = widget.localOverrideFile ?? _localFile;

    ImageProvider? imageProvider;
    if (activeFile != null && !_imageLoadFailed) {
      imageProvider = FileImage(activeFile);
    } else if (hasValidUrl && !_imageLoadFailed) {
      imageProvider = NetworkImage(cleanUrl);
    }

    if (imageProvider == null) {
      return _buildFallback(diameter);
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildFallback(diameter),
            Image(
              image: imageProvider,
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                if (activeFile != null && widget.localOverrideFile == null) {
                  PermanentAvatarStorage._invalidateCorruptedFile(
                    userId: widget.userId,
                    imageUrl: widget.imageUrl,
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_imageLoadFailed) {
                    setState(() {
                      _localFile = null;
                      _imageLoadFailed = true;
                    });
                  }
                });
                return _buildFallback(diameter);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PermanentCoverBanner extends StatefulWidget {
  final String userId;
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final List<Color> gradientColors;
  final Widget? placeholder;
  final File? localOverrideFile;

  const PermanentCoverBanner({
    super.key,
    required this.userId,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.gradientColors = const [Color(0xFF0F2942), Color(0xFF1E4C7A)],
    this.placeholder,
    this.localOverrideFile,
  });

  @override
  State<PermanentCoverBanner> createState() => _PermanentCoverBannerState();
}

class _PermanentCoverBannerState extends State<PermanentCoverBanner> {
  File? _localFile;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _localFile = PermanentAvatarStorage.getCachedBannerSync(
      userId: widget.userId,
      imageUrl: widget.imageUrl,
    );
    _resolveBanner();
  }

  @override
  void didUpdateWidget(covariant PermanentCoverBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.userId != widget.userId) {
      _imageLoadFailed = false;
      _localFile = PermanentAvatarStorage.getCachedBannerSync(
        userId: widget.userId,
        imageUrl: widget.imageUrl,
      );
      _resolveBanner();
    }
  }

  Future<void> _resolveBanner() async {
    final cleanUrl = widget.imageUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      if (mounted && _localFile != null) {
        setState(() => _localFile = null);
      }
      return;
    }

    final reqUserId = widget.userId;
    final reqUrl = widget.imageUrl;

    final file = await PermanentAvatarStorage.getOrDownloadBanner(
      userId: reqUserId,
      imageUrl: reqUrl,
    );

    if (!mounted ||
        widget.userId != reqUserId ||
        widget.imageUrl != reqUrl) {
      return;
    }

    if (file != null && _localFile?.path != file.path) {
      setState(() {
        _localFile = file;
        _imageLoadFailed = false;
      });
    }
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder,
      );
    }
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.imageUrl.trim();
    final bool hasValidUrl =
        cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');
    final File? activeFile = widget.localOverrideFile ?? _localFile;

    ImageProvider? imageProvider;
    if (activeFile != null && !_imageLoadFailed) {
      imageProvider = FileImage(activeFile);
    } else if (hasValidUrl && !_imageLoadFailed) {
      imageProvider = NetworkImage(cleanUrl);
    }

    final Widget content = imageProvider == null
        ? _buildPlaceholder()
        : SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPlaceholder(),
                Image(
                  image: imageProvider,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    if (activeFile != null &&
                        widget.localOverrideFile == null) {
                      PermanentAvatarStorage._invalidateCorruptedFile(
                        userId:
                            '${PermanentAvatarStorage.bannerPrefix}${widget.userId}',
                        imageUrl: widget.imageUrl,
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_imageLoadFailed) {
                        setState(() {
                          _localFile = null;
                          _imageLoadFailed = true;
                        });
                      }
                    });
                    return _buildPlaceholder();
                  },
                ),
              ],
            ),
          );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }
    return content;
  }
}