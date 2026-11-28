import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class MediaEditorResult {
  final File file;
  final String caption;
  final bool sendImmediately;

  MediaEditorResult({
    required this.file,
    required this.caption,
    this.sendImmediately = false,
  });
}

class OverlayItem {
  final String id;
  String text;
  final bool isEmoji;
  Color color;
  Offset position;
  double scale;

  OverlayItem({
    required this.id,
    required this.text,
    required this.isEmoji,
    required this.color,
    required this.position,
    this.scale = 1.0,
  });
}

class MediaPreviewEditorScreen extends StatefulWidget {
  final File file;
  final String? initialCaption;
  final bool isAlbum;
  final bool isVideo;
  final int? albumCount;

  const MediaPreviewEditorScreen({
    super.key,
    required this.file,
    this.initialCaption,
    this.isAlbum = false,
    this.isVideo = false,
    this.albumCount,
  });

  @override
  State<MediaPreviewEditorScreen> createState() =>
      _MediaPreviewEditorScreenState();
}

class _MediaPreviewEditorScreenState extends State<MediaPreviewEditorScreen> {
  late File _currentFile;
  late TextEditingController _captionController;
  final GlobalKey _repaintKey = GlobalKey();
  final List<OverlayItem> _overlays = [];
  bool _isProcessing = false;

  final List<String> _commonEmojis = [
    '😀', '😂', '😍', '🔥', '👍', '🎉',
    '❤️', '🙏', '💯', '✨', '👏', '🚀',
    '🤩', '😎', '🥳', '🤔', '💪', '💡',
    '⭐', '🎯', '📚', '🎓', '✏️', '📖'
  ];

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _captionController =
        TextEditingController(text: widget.initialCaption ?? '');
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool get _isImage {
    if (widget.isVideo) return false;
    final ext = _currentFile.path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.heic');
  }

  bool get _isVideo {
    if (widget.isVideo) return true;
    final ext = _currentFile.path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv') ||
        ext.endsWith('.webm') ||
        ext.endsWith('.3gp');
  }

  String get _fileName {
    return _currentFile.path.split(Platform.pathSeparator).last;
  }

  String get _fileSizeString {
    try {
      final bytes = _currentFile.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  Future<void> _cropImage() async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _currentFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop & Rotate',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          activeControlsWidgetColor: const Color(0xFF00A884),
        ),
        IOSUiSettings(
          title: 'Crop & Rotate',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _currentFile = File(croppedFile.path);
        _overlays.clear();
      });
    }
  }

  void _showAddTextDialog() {
    final textController = TextEditingController();
    Color selectedColor = Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Text',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: TextStyle(
                      color: selectedColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type text here...',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00A884), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Colors.white,
                      Colors.yellow,
                      Colors.redAccent,
                      Colors.greenAccent,
                      Colors.cyanAccent,
                      Colors.orangeAccent,
                      Colors.purpleAccent,
                    ].map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white24,
                              width: isSelected ? 3.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  onPressed: () {
                    final text = textController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _overlays.add(
                          OverlayItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            text: text,
                            isEmoji: false,
                            color: selectedColor,
                            position: const Offset(100, 160),
                          ),
                        );
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEmojiSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2428),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          height: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Emoji',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _commonEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _commonEmojis[index];
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _overlays.add(
                            OverlayItem(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              text: emoji,
                              isEmoji: true,
                              color: Colors.white,
                              position: const Offset(120, 160),
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> _bakeOverlaysIntoImage() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return _currentFile;

    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return _currentFile;

    final pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tempFile.writeAsBytes(pngBytes, flush: true);
    return tempFile;
  }

  Future<void> _handleConfirm({bool sendDirectly = false}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      File finalFile = _currentFile;
      if (_isImage && _overlays.isNotEmpty) {
        finalFile = await _bakeOverlaysIntoImage();
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        MediaEditorResult(
          file: finalFile,
          caption: _captionController.text.trim(),
          sendImmediately: sendDirectly,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      color: Colors.black.withValues(alpha: 0.55),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_isImage) ...[
            IconButton(
              icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white, size: 24),
              onPressed: _cropImage,
              tooltip: 'Crop',
            ),
            IconButton(
              icon: const Icon(Icons.sentiment_satisfied_alt_rounded,
                  color: Colors.white, size: 24),
              onPressed: _showAddEmojiSheet,
              tooltip: 'Emoji',
            ),
            IconButton(
              icon: const Icon(Icons.title_rounded, color: Colors.white, size: 24),
              onPressed: _showAddTextDialog,
              tooltip: 'Text',
            ),
            if (_overlays.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.undo_rounded, color: Colors.white, size: 24),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _overlays.removeLast();
                  });
                },
                tooltip: 'Undo',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Center(
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.file(
              _currentFile,
              fit: BoxFit.contain,
            ),
            ..._overlays.map((item) {
              return Positioned(
                left: item.position.dx,
                top: item.position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      item.position += details.delta;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: item.isEmoji ? 4 : 10,
                      vertical: item.isEmoji ? 2 : 5,
                    ),
                    decoration: item.isEmoji
                        ? null
                        : BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                    child: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: item.isEmoji ? 44 : 22,
                        color: item.color,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black87,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2428),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.redAccent,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_fileSizeString.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _fileSizeString,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreview() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2428),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF00A884).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Color(0xFF00A884),
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_fileSizeString.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _fileSizeString,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final String hintText = _isVideo
        ? 'Add a caption for this video...'
        : (widget.isAlbum
            ? (widget.albumCount != null && widget.albumCount! > 1
                ? 'Add a caption for ${widget.albumCount} photos...'
                : 'Add a caption for this album...')
            : 'Add a caption...');

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      color: Colors.black.withValues(alpha: 0.85),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2428),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _captionController,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isProcessing ? null : () => _handleConfirm(sendDirectly: false),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF00A884),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A884).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isProcessing
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isImage
                ? _buildImagePreview()
                : (_isVideo ? _buildVideoPreview() : _buildDocumentPreview()),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }
}