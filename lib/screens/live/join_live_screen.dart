import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _roomController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _handleLiveAction() async {
    if (!_formKey.currentState!.validate()) return;

    final roomId = _roomController.text.trim().toLowerCase();
    final title = _titleController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (widget.isTeacher) {
        final liveClass = LiveClassModel(
          roomId: roomId,
          title: title,
          teacherId: widget.currentUserId,
          teacherName: widget.currentUserName,
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
          SuccessToast.show(context, 'Live Class Created Successfully');
        }
      } else {
        final liveClassData = await _liveClassService.watchLiveClass(roomId).first;

        if (liveClassData == null) {
          if (mounted) {
            _showErrorDialog('Invalid Room Code', 'No active live class found. Please check again.');
          }
          return;
        }

        final bool isCurrentlyLive = liveClassData.isLive;

        if (!isCurrentlyLive) {
          if (mounted) {
            _showErrorDialog('Class Ended', 'This session has already been ended.');
          }
          return;
        }

        await _liveClassService.joinParticipant(roomId, widget.currentUserId);
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveClassScreen(
              roomId: roomId,
              userId: widget.currentUserId,
              userName: widget.currentUserName,
              isTeacher: widget.isTeacher,
              subjectTitle: widget.isTeacher ? title : 'Live Class Session',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                content: Text(message, style: const TextStyle(color: Colors.black87)),
                actions: [
                  TextButton(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isTeacher ? 'Host Live Room' : 'Join Live Room',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade900, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FYBTT DIGITAL',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                          Text(
                            'Virtual Classroom Network',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: widget.isTeacher ? Colors.red.shade50 : Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            widget.isTeacher ? Icons.sensors_rounded : Icons.wifi_tethering_rounded,
                            size: 46,
                            color: widget.isTeacher ? Colors.redAccent : Colors.blue[800],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      if (widget.isTeacher) ...[
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: 'Class Title',
                            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                            prefixIcon: Icon(Icons.title_rounded, color: Colors.blue[800], size: 22),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                            ),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Please enter a valid title' : null,
                        ),
                        const SizedBox(height: 18),
                      ],
                      TextFormField(
                        controller: _roomController,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
                        decoration: InputDecoration(
                          labelText: 'Room Code',
                          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                          prefixIcon: Icon(Icons.vpn_key_rounded, color: Colors.blue[800], size: 22),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                            ),
                        ),
                        validator: (val) => (val == null || val.length < 4) ? 'Enter valid room code (min 4 chars)' : null,
                      ),
                      const SizedBox(height: 34),
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: widget.isTeacher 
                                  ? Colors.redAccent.withOpacity(0.35) 
                                  : Colors.blue[800]!.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleLiveAction,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.isTeacher
                                    ? [const Color(0xFFFF416C), const Color(0xFFFF4B2B)]
                                    : [Colors.blue.shade800, Colors.blue.shade600],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          widget.isTeacher ? Icons.videocam_rounded : Icons.login_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          widget.isTeacher ? 'GO LIVE WITH FYBTT' : 'JOIN CLASS NOW',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
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
