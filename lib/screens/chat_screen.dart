import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverId;
  final String receiverName;
  final String receiverProfilePic;
  final String currentUserId;
  final bool isTeacher; // রোল বেসড আর্কিটেকচারের জন্য

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

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  Stream<QuerySnapshot>? _messageStream;

  @override
  void initState() {
    super.initState();
    _initChatStream();
    _updateTypingStatus(false);
  }

  // ফায়ারস্টোর স্ট্রিম ইনিশিয়ালাইজেশন এবং সেফটি মেকানিজম
  void _initChatStream() {
    try {
      _messageStream = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      debugPrint("Stream Initialization Error: $e");
    }
  }

  // রিয়াল-টাইম টাইপিং স্ট্যাটাস সিঙ্ক
  void _updateTypingStatus(bool isTyping) {
    FirebaseFirestore.instance
        .collection('typing')
        .doc(widget.chatRoomId)
        .set({
      widget.currentUserId: isTyping,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    // সেফ ব্যাক নেভিগেশন যাতে ব্ল্যাক স্ক্রিন ইস্যু না হয়
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _updateTypingStatus(false);
        Navigator.of(context).pop();
      },
      child: Scaffold(
        // WhatsApp Style Wallpaper Background
        backgroundColor: const Color(0xFFEFE7DD), 
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF006653), // WhatsApp Premium Teal
          titleSpacing: 0,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  _updateTypingStatus(false);
                  Navigator.pop(context);
                },
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: widget.receiverProfilePic.isNotEmpty
                    ? NetworkImage(widget.receiverProfilePic)
                    : null,
                child: widget.receiverProfilePic.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.receiverName,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // রিয়াল-টাইম অনলাইন/টাইপিং স্ট্যাটাস ইন্ডিকেটর উইজেট
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('typing')
                          .doc(widget.chatRoomId)
                          .snapshots(),
                      builder: (context, typingSnapshot) {
                        bool isTyping = false;
                        if (typingSnapshot.hasData && typingSnapshot.data!.exists) {
                          var data = typingSnapshot.data!.data() as Map<String, dynamic>?;
                          isTyping = data?[widget.receiverId] ?? false;
                        }

                        if (isTyping) {
                          return const Text(
                            'typing...',
                            style: TextStyle(
                              fontSize: 12, 
                              color: Color(0xFF25D366), 
                              fontWeight: FontWeight.bold
                            ),
                          );
                        }

                        // অনলাইন স্ট্যাটাস ট্র্যাকিং
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection(widget.isTeacher ? 'students' : 'teachers')
                              .doc(widget.receiverId)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                              bool isOnline = userData?['isOnline'] ?? false;
                              return Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: isOnline ? const Color(0xFF25D366) : Colors.white70
                                ),
                              );
                            }
                            return const Text('Offline', style: TextStyle(fontSize: 12, color: Colors.white70));
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.videocam_rounded, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.call_rounded, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.white), onPressed: () {}),
          ],
        ),
        body: Column(
          children: [
            // মেসেজ লিস্ট এরিয়া
            Expanded(
              child: _messageStream == null
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF006653)))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _messageStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Failed to load messages.',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF006653)));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Messages are end-to-end encrypted',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true, // নিচের দিক থেকে মেসেজ লোড হবে (WhatsApp Style)
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            
                            // মেসেজ মডেল পার্সিং ও সেফটি রেন্ডারিং
                            final message = MessageModel.fromMap(data);
                            final bool isMe = message.senderId == widget.currentUserId;

                            return MessageBubble(
                              message: message,
                              isMe: isMe,
                            );
                          },
                        );
                      },
                    ),
            ),
            // প্রিমিয়াম চ্যাট ইনপুট বার
            ChatInputBar(
              chatRoomId: widget.chatRoomId,
              senderId: widget.currentUserId,
              receiverId: widget.receiverId,
              onTypingChanged: (isTyping) => _updateTypingStatus(isTyping),
            ),
          ],
        ),
      ),
    );
  }
}

