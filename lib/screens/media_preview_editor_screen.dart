import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class MediaEditorResult {
  final File file;
  final String caption;

  MediaEditorResult({
    required this.file,
    required this.caption,
  });
}

class OverlayItem {
  final String id;
  final String text;
  final bool isEmoji;
  final Color color;
  Offset position;

  OverlayItem({
    required this.id,
    required this.text,
    required this.isEmoji,
    required this.color,
    required this.position,
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
    '🤩', '😎', '🥳', '🤔', '💪', '💡'
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
    final bytes = _currentFile.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _cropImage() async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _currentFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          activeControlsWidgetColor: const Color(0xFF00A884),
        ),
        IOSUiSettings(
          title: 'Crop Image',
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
              title: const Text(
                'Add Text',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: TextStyle(color: selectedColor, fontSize: 20),
                    decoration: const InputDecoration(
                      hintText: 'Type text here...',
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00A884)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Colors.white,
                      Colors.yellow,
                      Colors.redAccent,
                      Colors.greenAccent,
                      Colors.cyanAccent,
                      Colors.orangeAccent,
                    ].map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
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
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                  ),
                  onPressed: () {
                    final text = textController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _overlays.add(
                          OverlayItem(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            text: text,
                            isEmoji: false,
                            color: selectedColor,
                            position: const Offset(100, 150),
                          ),
                        );
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white),
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
          padding: const EdgeInsets.all(16),
          height: 220,
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
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _commonEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _commonEmojis[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _overlays.add(
                            OverlayItem(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              text: emoji,
                              isEmoji: true,
                              color: Colors.white,
                              position: const Offset(120, 150),
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(8),
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

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return _currentFile;

    final pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tempFile.writeAsBytes(pngBytes);
    return tempFile;
  }

  Future<void> _handleConfirm() async {
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
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      color: Colors.black45,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_isImage) ...[
            IconButton(
              icon: const Icon(Icons.crop, color: Colors.white, size: 24),
              onPressed: _cropImage,
              tooltip: 'Crop',
            ),
            IconButton(
              icon: const Icon(Icons.sentiment_satisfied_alt,
                  color: Colors.white, size: 24),
              onPressed: _showAddEmojiSheet,
              tooltip: 'Emoji',
            ),
            IconButton(
              icon: const Icon(Icons.title, color: Colors.white, size: 24),
              onPressed: _showAddTextDialog,
              tooltip: 'Text',
            ),
            if (_overlays.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white, size: 24),
                onPressed: () {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: item.isEmoji
                        ? null
                        : BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                    child: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: item.isEmoji ? 42 : 24,
                        color: item.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
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
            const SizedBox(height: 8),
            Text(
              _fileSizeString,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00A884).withOpacity(0.15),
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
            const SizedBox(height: 8),
            Text(
              _fileSizeString,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
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
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      color: Colors.black87,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2428),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _captionController,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle:
                      const TextStyle(color: Colors.white54, fontSize: 15),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isProcessing ? null : _handleConfirm,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF00A884),
                shape: BoxShape.circle,
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
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
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
