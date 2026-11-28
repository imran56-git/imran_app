import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatAlbumGrid extends StatelessWidget {
  final List<String> imageUrls;
  final void Function(int initialIndex) onImageTap;
  final double maxWidth;
  final BorderRadius borderRadius;
  final String? caption;
  final bool isUploading;
  final double? uploadProgress;
  final bool hasError;
  final VoidCallback? onRetry;
  final TextStyle? captionStyle;

  const ChatAlbumGrid({
    super.key,
    required this.imageUrls,
    required this.onImageTap,
    this.maxWidth = 260.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(14.0)),
    this.caption,
    this.isUploading = false,
    this.uploadProgress,
    this.hasError = false,
    this.onRetry,
    this.captionStyle,
  });

  bool _isLocalFile(String path) {
    return !path.startsWith('http://') && !path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasCaption = caption != null && caption!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: hasCaption
                ? BorderRadius.vertical(
                    top: borderRadius.topLeft,
                  )
                : borderRadius,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxWidth,
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  _buildLayout(context),
                  if (isUploading) _buildUploadOverlay(context),
                  if (hasError && !isUploading) _buildErrorOverlay(context),
                ],
              ),
            ),
          ),
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 7.0, 8.0, 5.0),
              child: Text(
                caption!.trim(),
                style: captionStyle ??
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          height: 1.3,
                        ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: (uploadProgress != null && uploadProgress! > 0.0 && uploadProgress! < 1.0)
                    ? uploadProgress
                    : null,
                strokeWidth: 3.0,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Retry Upload',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    switch (imageUrls.length) {
      case 1:
        return _buildSingleImage(0);
      case 2:
        return _buildTwoImages();
      case 3:
        return _buildThreeImages();
      default:
        return _buildFourOrMoreImages();
    }
  }

  Widget _buildSingleImage(int index) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: _buildMediaItem(imageUrls[index]),
      ),
    );
  }

  Widget _buildTwoImages() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onImageTap(0),
            child: _buildMediaItem(imageUrls[0]),
          ),
        ),
        const SizedBox(width: 2.0),
        Expanded(
          child: GestureDetector(
            onTap: () => onImageTap(1),
            child: _buildMediaItem(imageUrls[1]),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeImages() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () => onImageTap(0),
            child: _buildMediaItem(imageUrls[0]),
          ),
        ),
        const SizedBox(width: 2.0),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(1),
                  child: _buildMediaItem(imageUrls[1]),
                ),
              ),
              const SizedBox(height: 2.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(2),
                  child: _buildMediaItem(imageUrls[2]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourOrMoreImages() {
    final int extraCount = imageUrls.length - 4;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(0),
                  child: _buildMediaItem(imageUrls[0]),
                ),
              ),
              const SizedBox(width: 2.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(1),
                  child: _buildMediaItem(imageUrls[1]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2.0),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(2),
                  child: _buildMediaItem(imageUrls[2]),
                ),
              ),
              const SizedBox(width: 2.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildMediaItem(imageUrls[3]),
                      if (extraCount > 0)
                        Container(
                          color: Colors.black.withValues(alpha: 0.58),
                          alignment: Alignment.center,
                          child: Text(
                            '+$extraCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(String pathOrUrl) {
    if (_isLocalFile(pathOrUrl)) {
      return Image.file(
        File(pathOrUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1E2428),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_rounded,
            color: Colors.white38,
            size: 32.0,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: pathOrUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: const Color(0xFF1E2428),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24.0,
          height: 24.0,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF00A884),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF1E2428),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_rounded,
          color: Colors.white38,
          size: 32.0,
        ),
      ),
    );
  }
}