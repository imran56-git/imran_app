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
  static const Color _outgoingBubbleColor = Color(0xFFDBEAFE);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _animController.reset();
    _animController.repeat();
  }

  Future<void> _handleNextOrFinish() async {
    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
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

  double _ remap(double value, double start, double end) {
    if (value <= start) return 0.0;
    if (value >= end) return 1.0;
    return Curves.easeInOutCubic.transform((value - start) / (end - start));
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                      return GestureDetector(
                        onTap: () => _goToStep(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isCurrent ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color:
                                isCurrent ? _brandBlue : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 265,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double w = constraints.maxWidth;
                      final double h = constraints.maxHeight;
                      return AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          if (_currentStep == 0) {
                            return _buildReplyScene(w, h);
                          } else if (_currentStep == 1) {
                            return _buildDragDeleteScene(w, h);
                          } else {
                            return _buildHoldTapDeleteScene(w, h);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildStepTextDetails(),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(54, 48),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _goToStep(_currentStep - 1),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primaryNavy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
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
                  ),
                ],
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
          'Press and hold a message, then drag it down to the message box and release to reply.';
    } else if (_currentStep == 1) {
      title = '2. Drag Up to Delete / Copy';
      description =
          'Press and hold a message, then drag it up and drop it onto the Delete or Copy icon.';
    } else {
      title = '3. Hold to Select & Tap Top Icon';
      description =
          'Press and hold a message to select it, then simply tap the Delete or Copy icon at the top.';
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
        const SizedBox(height: 5),
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

  Widget _buildReplyScene(double w, double h) {
    final double t = _animController.value;

    final bool isHolding = t >= 0.14 && t < 0.72;
    final double dragProgress = _remap(t, 0.26, 0.64);
    final bool isHoveringInput = t >= 0.50 && t < 0.72;
    final bool isReplyAttached = t >= 0.72 && t < 0.95;

    final double bubbleWidth = w * 0.46;
    final double baseRightBubbleLeft = w - bubbleWidth - 14;
    const double baseRightBubbleTop = 108.0;

    final double targetDropLeft = (w - bubbleWidth) / 2;
    final double targetDropTop = h - 76.0;

    final double currentDragLeft = baseRightBubbleLeft +
        (targetDropLeft - baseRightBubbleLeft) * dragProgress;
    final double currentDragTop = baseRightBubbleTop +
        (targetDropTop - baseRightBubbleTop) * dragProgress;

    final double handLeft = currentDragLeft + (bubbleWidth * 0.52);
    final double handTop = currentDragTop + 16.0;

    return Stack(
      children: [
        _buildMiniChatHeader(),
        Positioned(
          top: 52,
          left: 14,
          child: _buildIncomingChatBubble(w * 0.44),
        ),
        Positioned(
          top: baseRightBubbleTop,
          left: baseRightBubbleLeft,
          child: Opacity(
            opacity: isHolding ? 0.25 : 1.0,
            child: _buildOutgoingChatBubble(bubbleWidth, isLifted: false),
          ),
        ),
        if (isHolding)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: _buildFloatingTopBar(
              showSelectionCount: false,
              highlightedAction: null,
            ),
          ),
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: _buildMiniInputBar(
            isHoveringReply: isHoveringInput,
            showAttachedReply: isReplyAttached,
          ),
        ),
        if (isHolding)
          Positioned(
            top: currentDragTop,
            left: currentDragLeft,
            child: Transform.scale(
              scale: 1.05,
              child: _buildOutgoingChatBubble(bubbleWidth, isLifted: true),
            ),
          ),
        if (t >= 0.08 && t < 0.76)
          Positioned(
            top: handTop,
            left: handLeft,
            child: _buildPointerHand(isPressed: isHolding),
          ),
      ],
    );
  }

  Widget _buildDragDeleteScene(double w, double h) {
    final double t = _animController.value;

    final bool isHolding = t >= 0.14 && t < 0.72;
    final double dragProgress = _remap(t, 0.26, 0.64);
    final bool isHoveringTrash = t >= 0.52 && t < 0.72;
    final bool isDeleted = t >= 0.72 && t < 0.95;

    final double bubbleWidth = w * 0.46;
    final double baseRightBubbleLeft = w - bubbleWidth - 14;
    const double baseRightBubbleTop = 116.0;

    final double trashTargetLeft = (w * 0.5) - (bubbleWidth * 0.5);
    const double trashTargetTop = 18.0;

    final double currentDragLeft = baseRightBubbleLeft +
        (trashTargetLeft - baseRightBubbleLeft) * dragProgress;
    final double currentDragTop = baseRightBubbleTop +
        (trashTargetTop - baseRightBubbleTop) * dragProgress;

    final double handLeft = currentDragLeft + (bubbleWidth * 0.48);
    final double handTop = currentDragTop + 14.0;

    return Stack(
      children: [
        _buildMiniChatHeader(),
        Positioned(
          top: 60,
          left: 14,
          child: _buildIncomingChatBubble(w * 0.44),
        ),
        if (!isDeleted)
          Positioned(
            top: baseRightBubbleTop,
            left: baseRightBubbleLeft,
            child: Opacity(
              opacity: isHolding ? 0.25 : 1.0,
              child: _buildOutgoingChatBubble(bubbleWidth, isLifted: false),
            ),
          ),
        if (isHolding)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: _buildFloatingTopBar(
              showSelectionCount: false,
              highlightedAction: isHoveringTrash ? 'delete' : null,
            ),
          ),
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: _buildMiniInputBar(
            isHoveringReply: false,
            showAttachedReply: false,
          ),
        ),
        if (isHolding && !isDeleted)
          Positioned(
            top: currentDragTop,
            left: currentDragLeft,
            child: Opacity(
              opacity: isHoveringTrash ? 0.75 : 1.0,
              child: Transform.scale(
                scale: isHoveringTrash ? 0.92 : 1.05,
                child: _buildOutgoingChatBubble(bubbleWidth, isLifted: true),
              ),
            ),
          ),
        if (t >= 0.08 && t < 0.76)
          Positioned(
            top: handTop,
            left: handLeft,
            child: _buildPointerHand(isPressed: isHolding),
          ),
      ],
    );
  }

  Widget _buildHoldTapDeleteScene(double w, double h) {
    final double t = _animController.value;

    final bool isInitialPress = t >= 0.12 && t < 0.32;
    final bool isSelectedMode = t >= 0.26 && t < 0.74;
    final bool isTappingTrash = t >= 0.62 && t < 0.74;
    final bool isDeleted = t >= 0.74 && t < 0.95;

    final double bubbleWidth = w * 0.46;
    final double baseRightBubbleLeft = w - bubbleWidth - 14;
    const double baseRightBubbleTop = 116.0;

    final double moveUpProgress = _remap(t, 0.36, 0.60);

    final double startHandLeft = baseRightBubbleLeft + (bubbleWidth * 0.5);
    const double startHandTop = baseRightBubbleTop + 14.0;

    final double trashIconLeft = (w * 0.54);
    const double trashIconTop = 22.0;

    final double handLeft =
        startHandLeft + (trashIconLeft - startHandLeft) * moveUpProgress;
    final double handTop =
        startHandTop + (trashIconTop - startHandTop) * moveUpProgress;

    return Stack(
      children: [
        _buildMiniChatHeader(),
        Positioned(
          top: 60,
          left: 14,
          child: _buildIncomingChatBubble(w * 0.44),
        ),
        if (!isDeleted)
          Positioned(
            top: baseRightBubbleTop - 4,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isSelectedMode
                    ? _accentBlue.withOpacity(0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isSelectedMode)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: _accentBlue,
                        size: 18,
                      ),
                    )
                  else
                    const SizedBox(width: 22),
                  _buildOutgoingChatBubble(bubbleWidth, isLifted: isInitialPress),
                ],
              ),
            ),
          ),
        if (isSelectedMode || isInitialPress)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: _buildFloatingTopBar(
              showSelectionCount: isSelectedMode,
              highlightedAction: isTappingTrash ? 'delete' : null,
            ),
          ),
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: _buildMiniInputBar(
            isHoveringReply: false,
            showAttachedReply: false,
          ),
        ),
        if (t >= 0.08 && t < 0.78)
          Positioned(
            top: handTop,
            left: handLeft,
            child: _buildPointerHand(
              isPressed: isInitialPress || isTappingTrash,
            ),
          ),
      ],
    );
  }

  Widget _buildMiniChatHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryNavy, _brandBlue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 12),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 12),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF86EFAC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingChatBubble(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width * 0.72,
            height: 6.5,
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: width * 0.42,
                height: 6.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 20,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingChatBubble(double width, {required bool isLifted}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _outgoingBubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(
          color: isLifted ? _accentBlue : const Color(0xFFBFDBFE),
          width: isLifted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(isLifted ? 0.24 : 0.05),
            blurRadius: isLifted ? 14 : 4,
            offset: Offset(0, isLifted ? 6 : 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width * 0.70,
            height: 6.5,
            decoration: BoxDecoration(
              color: const Color(0xFF1E4C7A).withOpacity(0.65),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: width * 0.38,
                height: 6.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E4C7A).withOpacity(0.40),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Icon(
                Icons.done_all_rounded,
                size: 13,
                color: _accentBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTopBar({
    required bool showSelectionCount,
    required String? highlightedAction,
  }) {
    final bool isDeleteHighlighted = highlightedAction == 'delete';

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _primaryNavy.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (showSelectionCount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          _buildTopBarCircleIcon(
            icon: Icons.copy_rounded,
            color: Colors.cyanAccent,
            isHighlighted: false,
          ),
          _buildTopBarCircleIcon(
            icon: Icons.delete_outline_rounded,
            color: Colors.orangeAccent,
            isHighlighted: isDeleteHighlighted,
          ),
          _buildTopBarCircleIcon(
            icon: Icons.delete_forever_rounded,
            color: Colors.redAccent,
            isHighlighted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarCircleIcon({
    required IconData icon,
    required Color color,
    required bool isHighlighted,
  }) {
    return AnimatedScale(
      scale: isHighlighted ? 1.38 : 1.0,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withOpacity(0.32)
              : Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: isHighlighted ? color : Colors.white.withOpacity(0.22),
            width: isHighlighted ? 1.5 : 1.0,
          ),
        ),
        child: Icon(
          icon,
          color: isHighlighted ? color : Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildMiniInputBar({
    required bool isHoveringReply,
    required bool showAttachedReply,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isHoveringReply)
          Container(
            height: 24,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _primaryNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.reply_rounded, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  'Release here to Reply',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (showAttachedReply)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _brandBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Replying to Message',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _brandBlue,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 90,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHoveringReply
                        ? _accentBlue
                        : const Color(0xFFCBD5E1),
                    width: isHoveringReply ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_emotions_outlined,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 5.5,
                        margin: const EdgeInsets.only(right: 40),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Icon(Icons.attach_file_rounded,
                        size: 15, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: _brandBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPointerHand({required bool isPressed}) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (isPressed)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentBlue.withOpacity(0.22),
              border: Border.all(
                color: _accentBlue.withOpacity(0.5),
                width: 1.5,
              ),
            ),
          ),
        AnimatedScale(
          scale: isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _primaryNavy.withOpacity(0.88),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}
