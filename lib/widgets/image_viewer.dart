import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? heroTag;
  final bool isGroup;
  final VoidCallback? onEditPressed;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.heroTag,
    this.isGroup = false,
    this.onEditPressed,
  });

  /// Helper method to launch the full-screen viewer with a smooth fade transition.
  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String title,
    String? subtitle,
    String? heroTag,
    bool isGroup = false,
    VoidCallback? onEditPressed,
  }) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ImageViewer(
              imageUrl: imageUrl,
              title: title,
              subtitle: subtitle,
              heroTag: heroTag,
              isGroup: isGroup,
              onEditPressed: onEditPressed,
            ),
          );
        },
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;

  double _verticalDragOffset = 0.0;
  bool _isZoomed = false;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    _transformationController.addListener(() {
      final double currentScale =
          _transformationController.value.getMaxScaleOnAxis();
      final bool zoomed = currentScale > 1.05;
      if (zoomed != _isZoomed && mounted) {
        setState(() => _isZoomed = zoomed);
      }
    });
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix;
    if (currentScale > 1.1) {
      targetMatrix = Matrix4.identity();
    } else {
      const double targetScale = 2.5;
      final Offset tapPosition = details.localPosition;
      targetMatrix = Matrix4.identity()
        ..translate(
          -tapPosition.dx * (targetScale - 1),
          -tapPosition.dy * (targetScale - 1),
        )
        ..scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(parent: _zoomAnimController, curve: Curves.easeOutCubic),
    );
    _zoomAnimController.forward(from: 0);
  }

  String _getInitials(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return widget.isGroup ? 'G' : 'U';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final String cleanUrl = widget.imageUrl.trim();
    final bool hasValidImage = cleanUrl.isNotEmpty &&
        (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'));

    final double dragProgress =
        (_verticalDragOffset.abs() / 220.0).clamp(0.0, 1.0);
    final double bgOpacity = (1.0 - (dragProgress * 0.65)).clamp(0.35, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(bgOpacity),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.55),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title.trim().isEmpty
                  ? (widget.isGroup ? 'Group Icon' : 'Profile Photo')
                  : widget.title.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty)
              Text(
                widget.subtitle!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.onEditPressed != null)
            IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Change Photo',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEditPressed?.call();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onVerticalDragUpdate: _isZoomed
            ? null
            : (details) {
                setState(() {
                  _verticalDragOffset += details.delta.dy;
                });
              },
        onVerticalDragEnd: _isZoomed
            ? null
            : (details) {
                if (_verticalDragOffset.abs() > 110 ||
                    (details.primaryVelocity ?? 0).abs() > 750) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _verticalDragOffset = 0.0;
                  });
                }
              },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _verticalDragOffset),
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTap,
                onDoubleTap: () {},
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  clipBehavior: Clip.none,
                  child: _buildHeroWrapper(
                    child: SizedBox(
                      width: screenWidth,
                      height: screenWidth,
                      child: hasValidImage
                          ? Image.network(
                              cleanUrl,
                              fit: BoxFit.cover,
                              width: screenWidth,
                              height: screenWidth,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: screenWidth,
                                  height: screenWidth,
                                  color: const Color(0xFF111827),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.8,
                                      value: loadingProgress
                                                  .expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildFallbackAvatar(screenWidth);
                              },
                            )
                          : _buildFallbackAvatar(screenWidth),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroWrapper({required Widget child}) {
    if (widget.heroTag != null && widget.heroTag!.trim().isNotEmpty) {
      return Hero(
        tag: widget.heroTag!.trim(),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      );
    }
    return child;
  }

  Widget _buildFallbackAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryNavy,
            _brandBlue,
            _accentBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: widget.isGroup
            ? const Icon(
                Icons.groups_rounded,
                size: 110,
                color: Colors.white,
              )
            : Text(
                _getInitials(widget.title),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
      ),
    );
  }
}
