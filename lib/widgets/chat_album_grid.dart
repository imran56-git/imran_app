import 'package:flutter/material.dart';

class ChatAlbumGrid extends StatelessWidget {
  final List<String> imageUrls;
  final void Function(int initialIndex) onImageTap;
  final double maxWidth;
  final BorderRadius borderRadius;

  const ChatAlbumGrid({
    super.key,
    required this.imageUrls,
    required this.onImageTap,
    this.maxWidth = 260.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(14.0)),
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxWidth,
        ),
        child: _buildLayout(context),
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
        child: _buildNetworkImage(imageUrls[index]),
      ),
    );
  }

  Widget _buildTwoImages() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onImageTap(0),
            child: _buildNetworkImage(imageUrls[0]),
          ),
        ),
        const SizedBox(width: 2.0),
        Expanded(
          child: GestureDetector(
            onTap: () => onImageTap(1),
            child: _buildNetworkImage(imageUrls[1]),
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
            child: _buildNetworkImage(imageUrls[0]),
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
                  child: _buildNetworkImage(imageUrls[1]),
                ),
              ),
              const SizedBox(height: 2.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(2),
                  child: _buildNetworkImage(imageUrls[2]),
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
                  child: _buildNetworkImage(imageUrls[0]),
                ),
              ),
              const SizedBox(width: 2.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(1),
                  child: _buildNetworkImage(imageUrls[1]),
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
                  child: _buildNetworkImage(imageUrls[2]),
                ),
              ),
              const SizedBox(width: 2.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => onImageTap(3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildNetworkImage(imageUrls[3]),
                      if (extraCount > 0)
                        Container(
                          color: Colors.black.withOpacity(0.55),
                          alignment: Alignment.center,
                          child: Text(
                            '+$extraCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
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

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFF1E2428),
          child: Center(
            child: SizedBox(
              width: 24.0,
              height: 24.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF00A884),
                ),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF1E2428),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_rounded,
            color: Colors.white38,
            size: 32.0,
          ),
        );
      },
    );
  }
}