import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_your_best_teacher_today/services/chat_service.dart';
import 'package:find_your_best_teacher_today/services/chat_menu_service.dart';
import 'package:find_your_best_teacher_today/models/message_model.dart';
import 'package:find_your_best_teacher_today/widgets/chat_input_bar.dart';
import 'package:find_your_best_teacher_today/widgets/message_bubble.dart';
import 'package:find_your_best_teacher_today/widgets/chat_popup_menu.dart';
import 'package:find_your_best_teacher_today/widgets/block_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/report_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/clear_chat_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/delete_chat_dialog.dart';
import 'package:find_your_best_teacher_today/utils/popup_menu_actions.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverId;
  final String receiverName;
  final String receiverProfilePic;
  final String currentUserId;
  final bool isTeacher;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverProfilePic,
    required this.currentUserId,
    required this.isTeacher,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final ChatMenuService _chatMenuService = ChatMenuService();
  final ScrollController _scrollController = ScrollController();

  late String _activeChatRoomId;
  Stream<List<MessageModel>>? _messageStream;

  String? _replyToMessageId;
  String? _replyToText;
  String? _customBgImagePath;
  bool _isMarkingRead = false;
  bool _isInitializing = true;

  bool _isDraggingMessage = false;
  bool _isDragHoveringInput = false;
  String? _hoveredTopAction;
  MessageModel? _draggedMessage;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  bool get _isOfficialChannel =>
      widget.receiverId == 'OFFICIAL_FYBTT_DESK' ||
      widget.chatRoomId.startsWith('official_desk_');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeChatRoomId = widget.chatRoomId;

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _setupChatRoom();
    _loadCustomTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bounceController.dispose();
    if (!_isOfficialChannel) {
      _chatService.updateTypingStatus(_activeChatRoomId, widget.currentUserId, false);
    }
    _markMessagesAsReadSafe();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsReadSafe();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isOfficialChannel) {
        _chatService.updateTypingStatus(_activeChatRoomId, widget.currentUserId, false);
      }
    }
  }

  Future<void> _setupChatRoom() async {
    if (_isOfficialChannel) {
      if (mounted) {
        setState(() {
          _messageStream = _chatService.getMessages(_activeChatRoomId);
          _isInitializing = false;
        });
        _markMessagesAsReadSafe();
      }
      return;
    }

    try {
      String teacherId = widget.isTeacher ? widget.currentUserId : widget.receiverId;
      String studentId = widget.isTeacher ? widget.receiverId : widget.currentUserId;

      await _chatService.createOrInitializeChat(
        teacherId: teacherId,
        studentId: studentId,
        teacherName: widget.isTeacher ? 'Me' : widget.receiverName,
        studentName: widget.isTeacher ? widget.receiverName : 'Me',
        teacherImage: widget.isTeacher ? '' : widget.receiverProfilePic,
        studentImage: widget.isTeacher ? widget.receiverProfilePic : '',
      );

      if (mounted) {
        setState(() {
          _messageStream = _chatService.getMessages(_activeChatRoomId);
          _isInitializing = false;
        });
        _chatService.updateTypingStatus(_activeChatRoomId, widget.currentUserId, false);
        _markMessagesAsReadSafe();
      }
    } catch (e) {
      log("Chat setup error: $e");
      if (mounted) {
        setState(() {
          _messageStream = _chatService.getMessages(_activeChatRoomId);
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _markMessagesAsReadSafe() async {
    if (_isMarkingRead) return;
    _isMarkingRead = true;
    try {
      await _chatService.markAsSeen(_activeChatRoomId, widget.currentUserId);
    } catch (e) {
      log("Error marking as read: $e");
    } finally {
      if (mounted) {
        _isMarkingRead = false;
      }
    }
  }

  Future<void> _loadCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _customBgImagePath = prefs.getString('chat_theme_$_activeChatRoomId');
      });
    }
  }

  Future<void> _changeChatThemeFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_theme_$_activeChatRoomId', pickedFile.path);
      if (mounted) {
        setState(() {
          _customBgImagePath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat theme updated successfully')),
        );
      }
    }
  }

  void _triggerReply(MessageModel message) {
    if (_isOfficialChannel) return;
    _bounceController.forward(from: 0.0).then((_) => _bounceController.reverse());
    setState(() {
      _replyToMessageId = message.messageId;
      _replyToText = message.type == 'text' ? message.content : 'Attachment';
    });
  }

  void _handleMenuAction(ChatMenuAction action) {
    switch (action) {
      case ChatMenuAction.viewProfile:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing profile of ${widget.receiverName}')),
        );
        break;

      case ChatMenuAction.blockUser:
        showDialog(
          context: context,
          builder: (context) => BlockDialog(
            userName: widget.receiverName,
            onConfirm: () async {
              await _chatMenuService.blockUser(widget.currentUserId, widget.receiverId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.reportUser:
        showDialog(
          context: context,
          builder: (context) => ReportDialog(
            userName: widget.receiverName,
            onConfirm: (reason) async {
              await _chatMenuService.reportUser(widget.currentUserId, widget.receiverId, reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User reported successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.clearChat:
        showDialog(
          context: context,
          builder: (context) => ClearChatDialog(
            onConfirm: () async {
              await _chatMenuService.clearChat(_activeChatRoomId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.deleteConversation:
        showDialog(
          context: context,
          builder: (context) => DeleteChatDialog(
            onConfirm: () async {
              await _chatMenuService.deleteConversation(_activeChatRoomId);
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        );
        break;
    }
  }

  Widget _buildTopActionIcon({
    required String actionKey,
    required IconData icon,
    required Color color,
    required Function(MessageModel) onAccept,
  }) {
    final bool isHovered = _hoveredTopAction == actionKey;

    return DragTarget<MessageModel>(
      onWillAcceptWithDetails: (details) {
        HapticFeedback.selectionClick();
        setState(() {
          _hoveredTopAction = actionKey;
        });
        return true;
      },
      onLeave: (_) {
        setState(() {
          if (_hoveredTopAction == actionKey) _hoveredTopAction = null;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _hoveredTopAction = null;
        });
        onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedScale(
          scale: isHovered ? 1.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHovered ? color.withOpacity(0.25) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isHovered ? color : Colors.white,
              size: 22,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopActionToolbar() {
    return Positioned(
      top: 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _isDraggingMessage ? 1.0 : 0.0,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.92),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTopActionIcon(
                  actionKey: 'copy',
                  icon: Icons.copy_rounded,
                  color: Colors.white,
                  onAccept: (msg) async {
                    await Clipboard.setData(ClipboardData(text: msg.content));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                ),
                _buildTopActionIcon(
                  actionKey: 'delete_me',
                  icon: Icons.delete_outline_rounded,
                  color: Colors.orangeAccent,
                  onAccept: (msg) async {
                    try {
                      await _chatService.deleteMessageForMe(
                          _activeChatRoomId, msg.messageId, widget.currentUserId);
                    } catch (e) {
                      log("Delete for me error: $e");
                    }
                  },
                ),
                if (!_isOfficialChannel)
                  _buildTopActionIcon(
                    actionKey: 'delete_all',
                    icon: Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                    onAccept: (msg) async {
                      try {
                        await _chatService.deleteMessageForEveryone(
                            _activeChatRoomId, msg.messageId);
                      } catch (e) {
                        log("Delete for everyone error: $e");
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialAppBarTitle() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () async {
            await _markMessagesAsReadSafe();
            if (context.mounted) Navigator.pop(context);
          },
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.verified_rounded, color: Colors.tealAccent, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text(
                      'FYBTT official',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Image.asset(
                    'assets/images/Verified_Batch.png',
                    width: 15,
                    height: 15,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF38BDF8),
                      size: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Verified Desk',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFA7F3D0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStandardAppBarTitle() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _chatService.getUserStatusStream(
        widget.receiverId,
        widget.isTeacher,
      ),
      builder: (context, statusSnapshot) {
        String displayName = widget.receiverName;
        String displayPic = widget.receiverProfilePic;
        bool isOnline = false;

        if (statusSnapshot.hasData && statusSnapshot.data != null) {
          final data = statusSnapshot.data!;
          isOnline = data['isOnline'] == true;

          if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
            displayName = data['fullName'].toString();
          }
          if (data['profileImageUrl'] != null &&
              data['profileImageUrl'].toString().isNotEmpty) {
            displayPic = data['profileImageUrl'].toString();
          }
        }

        if (displayName.isEmpty || displayName == 'User') {
          displayName = widget.receiverName.isNotEmpty ? widget.receiverName : 'User';
        }

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () async {
                _chatService.updateTypingStatus(
                    _activeChatRoomId, widget.currentUserId, false);
                await _markMessagesAsReadSafe();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage:
                  displayPic.isNotEmpty ? NetworkImage(displayPic) : null,
              child: displayPic.isEmpty
                  ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('typing')
                        .doc(_activeChatRoomId)
                        .snapshots()
                        .handleError((error) => log('Typing Stream Error: $error')),
                    builder: (context, typingSnapshot) {
                      bool isTyping = false;
                      if (typingSnapshot.hasData && typingSnapshot.data!.exists) {
                        var data =
                            typingSnapshot.data!.data() as Map<String, dynamic>?;
                        isTyping = data?[widget.receiverId] ?? false;
                      }

                      if (isTyping) {
                        return const Text(
                          'typing...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA2E8DD),
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }

                      return Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              isOnline ? const Color(0xFF22C55E) : Colors.white70,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_isOfficialChannel) {
          _chatService.updateTypingStatus(_activeChatRoomId, widget.currentUserId, false);
        }
        await _markMessagesAsReadSafe();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1E4C7A),
          elevation: 0,
          titleSpacing: 0,
          scrolledUnderElevation: 0,
          title: _isOfficialChannel
              ? _buildOfficialAppBarTitle()
              : _buildStandardAppBarTitle(),
          actions: [
            IconButton(
              icon: const Icon(Icons.wallpaper_rounded, color: Colors.white, size: 22),
              tooltip: 'Change Chat Theme',
              onPressed: _changeChatThemeFromGallery,
            ),
            if (!_isOfficialChannel)
              ChatPopupMenu(onSelected: _handleMenuAction),
            const SizedBox(width: 4),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            image: _customBgImagePath != null
                ? DecorationImage(
                    image: FileImage(File(_customBgImagePath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _isInitializing || _messageStream == null
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF1E4C7A), strokeWidth: 3))
                        : StreamBuilder<List<MessageModel>>(
                            stream: _messageStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Failed to load messages.',
                                    style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              }

                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF1E4C7A), strokeWidth: 3));
                              }

                              final messages = snapshot.data ?? [];

                              if (messages.isEmpty) {
                                return Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isOfficialChannel
                                              ? Icons.campaign_rounded
                                              : Icons.lock_outline_rounded,
                                          size: 16,
                                          color: Colors.black54,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isOfficialChannel
                                              ? 'Official notice channel'
                                              : 'Messages are end-to-end encrypted',
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _markMessagesAsReadSafe());

                              return ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final bool isMe =
                                      message.senderId == widget.currentUserId;

                                  return LongPressDraggable<MessageModel>(
                                    delay: const Duration(milliseconds: 500),
                                    data: message,
                                    onDragStarted: () {
                                      HapticFeedback.mediumImpact();
                                      setState(() {
                                        _isDraggingMessage = true;
                                        _draggedMessage = message;
                                      });
                                    },
                                    onDragEnd: (_) {
                                      setState(() {
                                        _isDraggingMessage = false;
                                        _draggedMessage = null;
                                        _hoveredTopAction = null;
                                        _isDragHoveringInput = false;
                                      });
                                    },
                                    onDraggableCanceled: (_, __) {
                                      setState(() {
                                        _isDraggingMessage = false;
                                        _draggedMessage = null;
                                        _hoveredTopAction = null;
                                        _isDragHoveringInput = false;
                                      });
                                    },
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.85,
                                        child: Transform.scale(
                                          scale: 1.05,
                                          child: MessageBubble(
                                            message: message,
                                            isMe: isMe,
                                            chatRoomId: _activeChatRoomId,
                                            currentUserId: widget.currentUserId,
                                            onReplyPressed: (_) {},
                                          ),
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                        chatRoomId: _activeChatRoomId,
                                        currentUserId: widget.currentUserId,
                                        onReplyPressed: (_) {},
                                      ),
                                    ),
                                    child: MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      chatRoomId: _activeChatRoomId,
                                      currentUserId: widget.currentUserId,
                                      onReplyPressed: (repliedMessage) {
                                        _triggerReply(repliedMessage);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  if (_isOfficialChannel)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 14,
                        bottom: MediaQuery.of(context).padding.bottom + 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Only official announcements are delivered here.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DragTarget<MessageModel>(
                      onWillAcceptWithDetails: (details) {
                        HapticFeedback.selectionClick();
                        setState(() => _isDragHoveringInput = true);
                        return true;
                      },
                      onLeave: (_) {
                        setState(() => _isDragHoveringInput = false);
                      },
                      onAcceptWithDetails: (details) {
                        setState(() => _isDragHoveringInput = false);
                        _triggerReply(details.data);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return AnimatedScale(
                          scale: _isDragHoveringInput ? 1.03 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.elasticOut,
                          child: ScaleTransition(
                            scale: _bounceAnimation,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: _isDragHoveringInput
                                    ? Border.all(
                                        color: const Color(0xFF1E4C7A), width: 2)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: _isDragHoveringInput
                                        ? const Color(0xFF1E4C7A).withOpacity(0.2)
                                        : Colors.black.withOpacity(0.03),
                                    blurRadius: _isDragHoveringInput ? 15 : 10,
                                    offset: const Offset(0, -3),
                                  ),
                                ],
                              ),
                              child: ChatInputBar(
                                chatRoomId: _activeChatRoomId,
                                senderId: widget.currentUserId,
                                receiverId: widget.receiverId,
                                replyToMessageId: _replyToMessageId,
                                replyToText: _replyToText,
                                onCancelReply: () {
                                  setState(() {
                                    _replyToMessageId = null;
                                    _replyToText = null;
                                  });
                                },
                                onTypingChanged: (isTyping) {
                                  _chatService.updateTypingStatus(
                                      _activeChatRoomId, widget.currentUserId, isTyping);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (_isDraggingMessage) _buildTopActionToolbar(),
            ],
          ),
        ),
      ),
    );
  }
}