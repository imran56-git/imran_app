import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/live_class_model.dart';
import '../../services/live_class_service.dart';
import '../../widgets/success_toast.dart';
import 'live_class_screen.dart';

class JoinLiveScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final bool isTeacher;

  const JoinLiveScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.isTeacher,
  });

  @override
  State<JoinLiveScreen> createState() => _JoinLiveScreenState();
}

class _JoinLiveScreenState extends State<JoinLiveScreen> {
  final LiveClassService _liveClassService = LiveClassService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isTeacher) {
      _generateUniqueRoomCode();
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _generateUniqueRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final code = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    _roomController.text = 'FYBTT-$code';
    setState(() {});
  }

  String _sanitizeJitsiRoomId(String rawCode) {
    final clean = rawCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    return 'fybtt_secure_room_${clean}_edu';
  }

  void _handleLiveAction({String? existingRoomId, String? existingTitle}) async {
    final rawCode = (existingRoomId ?? _roomController.text).trim();
    final title = (existingTitle ?? _titleController.text).trim();

    if (existingRoomId == null && !_formKey.currentState!.validate()) return;

    final internalJitsiRoomId = _sanitizeJitsiRoomId(rawCode);

    setState(() => _isLoading = true);

    try {
      if (widget.isTeacher) {
        final liveClass = LiveClassModel(
          roomId: rawCode,
          title: title,
          teacherId: widget.currentUserId,
          teacherName: widget.currentUserName.isNotEmpty ? widget.currentUserName : 'Teacher',
          isLive: true,
          createdAt: DateTime.now(),
          isMicMuted: false,
          isCameraOff: false,
          participants: [widget.currentUserId],
          handRaisedUsers: [],
          allowedMicUsers: [widget.currentUserId],
        );

        await _liveClassService.createLiveClass(liveClass);
        if (mounted) {
          SuccessToast.show(context, 'Live Classroom Ready');
        }
      } else {
        final liveClassSnapshot = await _firestore.collection('live_classes').doc(rawCode).get();

        if (!liveClassSnapshot.exists || liveClassSnapshot.data() == null) {
          if (mounted) {
            _showErrorDialog('Room Not Found', 'No active live session found with Room Code: $rawCode');
          }
          return;
        }

        final data = liveClassSnapshot.data()!;
        final bool isLive = data['isLive'] == true;

        if (!isLive) {
          if (mounted) {
            _showErrorDialog('Session Ended', 'This class has already been concluded by the teacher.');
          }
          return;
        }

        await _liveClassService.joinParticipant(rawCode, widget.currentUserId);
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveClassScreen(
              roomId: internalJitsiRoomId,
              userId: widget.currentUserId,
              userName: widget.currentUserName.isNotEmpty ? widget.currentUserName : (widget.isTeacher ? 'Teacher' : 'Student'),
              isTeacher: widget.isTeacher,
              subjectTitle: title.isNotEmpty ? title : 'Live Class Session',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Connection Error', 'Could not enter classroom. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: anim,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 26),
                    const SizedBox(width: 10),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 17)),
                  ],
                ),
                content: Text(message, style: const TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.4)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, const Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.school_rounded,
                  color: Colors.blue[900],
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FYBTT DIGITAL',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
                SizedBox(height: 2),
                Text(
                  '1-Click Interactive Classroom',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.isTeacher ? 'TEACHER' : 'STUDENT',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentActiveClassesFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('live_classes').where('isLive', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        final liveDocs = snapshot.hasData ? snapshot.data!.docs : [];

        if (liveDocs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.tv_off_rounded, size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text(
                  'No Teachers Live Right Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'When your teacher starts a class, it will appear here for 1-click join.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Classes Happening Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...liveDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final String title = data['title'] ?? 'Live Class Session';
              final String teacherName = data['teacherName'] ?? 'Teacher';
              final String roomId = doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade100, width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sensors_rounded, color: Colors.red, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'By $teacherName',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _handleLiveAction(existingRoomId: roomId, existingTitle: title),
                      child: const Text('JOIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isTeacher ? const Color(0xFFDC2626) : Colors.blue[800]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isTeacher ? 'Host Classroom' : 'Live Classroom',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTopBanner(),
                const SizedBox(height: 22),

                if (!widget.isTeacher) ...[
                  _buildStudentActiveClassesFeed(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR JOIN VIA CODE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                  ),
                ],

                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      if (widget.isTeacher) ...[
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Class Title / Subject',
                            hintText: 'e.g. Physics 1st Paper: Mechanics',
                            prefixIcon: Icon(Icons.menu_book_rounded, color: themeColor, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a class topic' : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _roomController,
                        readOnly: widget.isTeacher,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        decoration: InputDecoration(
                          labelText: 'Room Code',
                          hintText: 'e.g. FYBTT-9482',
                          prefixIcon: Icon(Icons.vpn_key_rounded, color: themeColor, size: 20),
                          suffixIcon: widget.isTeacher
                              ? IconButton(
                                  icon: const Icon(Icons.refresh_rounded),
                                  tooltip: 'Generate New Code',
                                  onPressed: _generateUniqueRoomCode,
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (val) => (val == null || val.trim().length < 3) ? 'Enter valid room code' : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 1,
                          ),
                          onPressed: _isLoading ? null : () => _handleLiveAction(),
                          icon: _isLoading ? const SizedBox.shrink() : Icon(widget.isTeacher ? Icons.sensors_rounded : Icons.login_rounded, size: 22),
                          label: _isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                              : Text(
                                  widget.isTeacher ? 'START LIVE CLASS' : 'JOIN ROOM',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}