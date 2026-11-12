import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum MediaUploadType {
  profile,
  banner,
  groupIcon,
}

class MediaCompressionService {
  MediaCompressionService._();

  static final ImagePicker _picker = ImagePicker();
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);

  /// Shows a clean bottom sheet for choosing Camera or Gallery,
  /// then crops, ultra-compresses to WebP, and uploads to Firebase Storage.
  static Future<String?> pickCropCompressAndUpload({
    required BuildContext context,
    required MediaUploadType uploadType,
    required String ownerId,
    void Function(double progress)? onUploadProgress,
  }) async {
    final ImageSource? source = await showImageSourceSheet(
      context: context,
      title: uploadType == MediaUploadType.banner
          ? 'Update Cover Banner'
          : uploadType == MediaUploadType.groupIcon
              ? 'Update Group Icon'
              : 'Update Profile Photo',
    );

    if (source == null) return null;

    return processAndUploadFromSource(
      source: source,
      uploadType: uploadType,
      ownerId: ownerId,
      onUploadProgress: onUploadProgress,
    );
  }

  /// Directly picks from [source], crops, compresses to WebP, and uploads.
  static Future<String?> processAndUploadFromSource({
    required ImageSource source,
    required MediaUploadType uploadType,
    required String ownerId,
    void Function(double progress)? onUploadProgress,
  }) async {
    File? croppedFile;
    File? compressedFile;

    try {
      // 1. Pick raw image (pre-capped at 2048px to avoid memory spikes on 100MP+ cameras)
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );

      if (picked == null) return null;

      // 2. Smart Aspect-Ratio Crop (exports full 1:1 square for profile/group with circular guide)
      croppedFile = await _cropImage(
        sourcePath: picked.path,
        uploadType: uploadType,
      );

      if (croppedFile == null) return null;

      // 3. Ultra-compress to WebP format on device
      compressedFile = await _compressToWebP(
        file: croppedFile,
        uploadType: uploadType,
      );

      if (compressedFile == null) return null;

      // 4. Upload to fixed path in Firebase Storage (automatically overwrites old file)
      final String storagePath = _buildStoragePath(
        uploadType: uploadType,
        ownerId: ownerId,
      );

      final Reference ref = _storage.ref().child(storagePath);
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/webp',
        cacheControl: 'public, max-age=86400',
        customMetadata: {
          'ownerId': ownerId,
          'uploadType': uploadType.name,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = ref.putFile(compressedFile, metadata);

      if (onUploadProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final double progress =
                snapshot.bytesTransferred / snapshot.totalBytes;
            onUploadProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final TaskSnapshot completedSnapshot = await uploadTask;
      final String rawDownloadUrl =
          await completedSnapshot.ref.getDownloadURL();

      // Append timestamp query parameter to bust local image cache on immediate update
      final String separator = rawDownloadUrl.contains('?') ? '&' : '?';
      final String freshUrl =
          '$rawDownloadUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}';

      return freshUrl;
    } catch (e) {
      debugPrint('MediaCompressionService Error: $e');
      rethrow;
    } finally {
      // Clean up temporary cache files on device
      _safeDeleteTempFile(croppedFile);
      _safeDeleteTempFile(compressedFile);
    }
  }

  /// Crops image with circular visual guide for profile/group (saving full 1:1 square)
  /// and wide 12:5 frame for cover banners.
  static Future<File?> _cropImage({
    required String sourcePath,
    required MediaUploadType uploadType,
  }) async {
    final bool isBanner = uploadType == MediaUploadType.banner;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: isBanner
          ? const CropAspectRatio(ratioX: 12, ratioY: 5)
          : const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isBanner ? 'Adjust Cover Banner' : 'Adjust Photo',
          toolbarColor: _primaryNavy,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _accentBlue,
          statusBarColor: _primaryNavy,
          backgroundColor: Colors.black,
          initAspectRatio: isBanner
              ? CropAspectRatioPreset.ratio16x9
              : CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: isBanner ? CropStyle.rectangle : CropStyle.circle,
        ),
        IOSUiSettings(
          title: isBanner ? 'Adjust Cover Banner' : 'Adjust Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: isBanner ? CropStyle.rectangle : CropStyle.circle,
        ),
      ],
    );

    if (cropped == null) return null;
    return File(cropped.path);
  }

  /// Compresses image to crisp HD WebP (~50-80 KB for square, ~70-120 KB for banner).
  static Future<File?> _compressToWebP({
    required File file,
    required MediaUploadType uploadType,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String targetPath =
        '${tempDir.path}/fybtt_${uploadType.name}_${DateTime.now().millisecondsSinceEpoch}.webp';

    final bool isBanner = uploadType == MediaUploadType.banner;
    final int targetWidth = isBanner ? 1200 : 800;
    final int targetHeight = isBanner ? 500 : 800;
    const int initialQuality = 80;

    XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: initialQuality,
      format: CompressFormat.webp,
      keepExif: false,
    );

    if (result == null) return null;

    File compressed = File(result.path);

    // Secondary pass if file is still larger than 140 KB
    final int sizeInBytes = await compressed.length();
    if (sizeInBytes > 140 * 1024) {
      final String secondPassPath =
          '${tempDir.path}/fybtt_${uploadType.name}_opt_${DateTime.now().millisecondsSinceEpoch}.webp';
      final XFile? secondResult = await FlutterImageCompress.compressAndGetFile(
        compressed.absolute.path,
        secondPassPath,
        minWidth: isBanner ? 1080 : 720,
        minHeight: isBanner ? 450 : 720,
        quality: 68,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (secondResult != null) {
        _safeDeleteTempFile(compressed);
        compressed = File(secondResult.path);
      }
    }

    return compressed;
  }

  /// Fixed storage paths so each new upload overwrites the previous file.
  static String _buildStoragePath({
    required MediaUploadType uploadType,
    required String ownerId,
  }) {
    final String cleanId = ownerId.trim();
    switch (uploadType) {
      case MediaUploadType.profile:
        return 'profile_images/$cleanId/profile.webp';
      case MediaUploadType.banner:
        return 'cover_banners/$cleanId/cover.webp';
      case MediaUploadType.groupIcon:
        return 'group_icons/$cleanId/icon.webp';
    }
  }

  static void _safeDeleteTempFile(File? file) {
    try {
      if (file != null && file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  /// Clean modal bottom sheet to select Camera or Gallery.
  static Future<ImageSource?> showImageSourceSheet({
    required BuildContext context,
    String title = 'Select Photo Source',
  }) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SourceOptionTile(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: _accentBlue,
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _SourceOptionTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: _brandBlue,
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.camera),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SourceOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
