import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatGestureTutorialDialog extends StatefulWidget {
  final String userId;
  final bool isGroup;

  const ChatGestureTutorialDialog({
    super.key,
    required this.userId,
    required this.isGroup,
  });

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String userId,
    required bool isGroup,
  }) async {
    if (userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = isGroup
        ? 'group_gesture_guide_shown_$userId'
        : 'chat_gesture_guide_shown_$userId';
    final bool alreadyShown = prefs.getBool(key) ?? false;
    if (alreadyShown) return;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChatGestureTutorialDialog(
        userId: userId,
        isGroup: isGroup,
      ),
    );
  }

  @override
  State<ChatGestureTutorialDialog> createState() =>
      _ChatGestureTutorialDialogState();
}

class _ChatGestureTutorialDialogState extends State<ChatGestureTutorialDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animController;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleNextOrFinish() async {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _animController.forward(from: 0.0);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final key = widget.isGroup
          ? 'group_gesture_guide_shown_${widget.userId}'
          : 'chat_gesture_guide_shown_${widget.userId}';
      await prefs.setBool(key, true);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _brandBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.touch_app_rounded,
                          color: _brandBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Gesture Guide',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: List.generate(3, (index) {
                      final bool isCurrent = _currentStep == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrent ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCurrent ? _brandBlue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      if (_currentStep == 0) {
                        return _buildReplyAnimation();
                      } else if (_currentStep == 1) {
                        return _buildDragDeleteAnimation();
                      } else {
                        return _buildHoldTapDeleteAnimation();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildStepTextDetails(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _handleNextOrFinish,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep < 2 ? 'Next' : 'Got It',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _currentStep < 2
                            ? Icons.arrow_forward_rounded
                            : Icons.check_circle_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepTextDetails() {
    String title = '';
    String description = '';

    if (_currentStep == 0) {
      title = '1. Drag Down to Reply';
      description =
          'Press and hold any message, then drag it down towards the input bar to quote and reply.';
    } else if (_currentStep == 1) {
      title = '2. Drag Up to Delete / Manage';
      description =
          'Press and hold the message, then drag it up and drop directly onto the top action bar to delete.';
    } else {
      title = '3. Hold to Select & Tap Action';
      description =
          'Press and hold any message to select it, then tap the Delete or Copy icon on the top action bar.';
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: _primaryNavy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildReplyAnimation() {
    final double t = _animController.value;
    double dragProgress = 0.0;
    if (t > 0.25 && t < 0.75) {
      dragProgress = (t - 0.25) / 0.5;
    } else if (t >= 0.75) {
      dragProgress = 1.0;
    }

    final double msgOffsetY = dragProgress * 80.0;
    final bool isHovering = dragProgress > 0.6;
    final bool isReplyActive = t >= 0.75;

    return Stack(
      children: [
        Positioned(
          top: 36 + msgOffsetY,
          left: 36,
          right: 36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: dragProgress > 0 ? _brandBlue : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dragProgress > 0
                    ? _accentBlue
                    : const Color(0xFFCBD5E1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dragProgress > 0 ? 0.16 : 0.04),
                  blurRadius: dragProgress > 0 ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: dragProgress > 0 ? Colors.white : _primaryNavy,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hello, how can I help?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: dragProgress > 0 ? Colors.white : _primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: isHovering ? 26 : 0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: isHovering
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.reply_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Release here to Reply',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHovering ? _accentBlue : const Color(0xFFCBD5E1),
                    width: isHovering ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isReplyActive ? 'Replying to message...' : 'Type a message...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isReplyActive ? _accentBlue : Colors.grey.shade400,
                          fontWeight: isReplyActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.send_rounded, size: 18, color: _brandBlue),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 48 + (dragProgress * 80.0),
          left: 140,
          child: Opacity(
            opacity: (t > 0.1 && t < 0.9) ? 1.0 : 0.0,
            child: _buildPointerHand(),
          ),
        ),
      ],
    );
  }

  Widget _buildDragDeleteAnimation() {
    final double t = _animController.value;
    double dragProgress = 0.0;
    if (t > 0.25 && t < 0.75) {
      dragProgress = (t - 0.25) / 0.5;
    } else if (t >= 0.75) {
      dragProgress = 1.0;
    }

    final double msgOffsetY = -dragProgress * 80.0;
    final bool isOverTrash = dragProgress > 0.7;
    final bool isDeleted = t >= 0.85;

    return Stack(
      children: [
        Positioned(
          top: 12,
          left: 20,
          right: 20,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _primaryNavy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 16),
                const Icon(Icons.edit_rounded, color: Colors.lightBlueAccent, size: 16),
                AnimatedScale(
                  scale: isOverTrash ? 1.4 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: isOverTrash ? Colors.redAccent : Colors.orangeAccent,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isDeleted)
          Positioned(
            top: 115 + msgOffsetY,
            left: 36,
            right: 36,
            child: Opacity(
              opacity: isOverTrash ? 0.6 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: dragProgress > 0 ? _brandBlue : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dragProgress > 0
                        ? _accentBlue
                        : const Color(0xFFCBD5E1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(dragProgress > 0 ? 0.16 : 0.04),
                      blurRadius: dragProgress > 0 ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: dragProgress > 0 ? Colors.white : _primaryNavy,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete this message',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: dragProgress > 0 ? Colors.white : _primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (!isDeleted)
          Positioned(
            top: 125 + msgOffsetY,
            left: 140,
            child: Opacity(
              opacity: (t > 0.1 && t < 0.9) ? 1.0 : 0.0,
              child: _buildPointerHand(),
            ),
          ),
      ],
    );
  }

  Widget _buildHoldTapDeleteAnimation() {
    final double t = _animController.value;
    final bool isSelected = t > 0.35 && t < 0.85;
    final bool isDeleted = t >= 0.85;

    double handTop = 115;
    double handLeft = 140;

    if (t <= 0.35) {
      handTop = 115;
      handLeft = 140;
    } else if (t > 0.35 && t < 0.65) {
      final double moveP = (t - 0.35) / 0.30;
      handTop = 115 - (moveP * 95);
      handLeft = 140 + (moveP * 30);
    } else {
      handTop = 20;
      handLeft = 170;
    }

    return Stack(
      children: [
        if (isSelected)
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _primaryNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 16),
                  const Icon(Icons.edit_rounded, color: Colors.lightBlueAccent, size: 16),
                  AnimatedScale(
                    scale: t >= 0.65 && t < 0.85 ? 1.4 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!isDeleted)
          Positioned(
            top: 105,
            left: 36,
            right: 36,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _accentBlue.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _accentBlue : const Color(0xFFCBD5E1),
                  width: isSelected ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_circle_rounded, color: _accentBlue, size: 16),
                    const SizedBox(width: 6),
                  ],
                  const Text(
                    'Tap to delete me',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: handTop,
          left: handLeft,
          child: Opacity(
            opacity: (t > 0.05 && t < 0.95) ? 1.0 : 0.0,
            child: _buildPointerHand(),
          ),
        ),
      ],
    );
  }

  Widget _buildPointerHand() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.touch_app_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
