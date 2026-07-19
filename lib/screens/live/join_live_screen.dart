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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 12),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 18)),
                  ],
                ),
                content: Text(message, style: const TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.4)),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    final themeColor = widget.isTeacher ? Colors.redAccent : Colors.blue[800]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isTeacher ? 'Host Live Room' : 'Join Live Room',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18, letterSpacing: 0.3),
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // প্রিমিয়াম টপ ব্যানার উইজেট (লোগো ইন্টিগ্রেশন সহ)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade900, const Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          ]
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.school_rounded,
                              color: Colors.blue[900],
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FYBTT DIGITAL',
                              // ফিক্সড: FontWeight.black পরিবর্তন করে ফ্ল্যাটার স্ট্যান্ডার্ড FontWeight.w900 করা হলো
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Virtual Classroom Network',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // মূল ইনপুট প্যানেল কার্ড
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: widget.isTeacher ? Colors.red.shade50 : Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            widget.isTeacher ? Icons.sensors_rounded : Icons.wifi_tethering_rounded,
                            size: 40,
                            color: themeColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      
                      if (widget.isTeacher) ...[
                        _buildCustomTextField(
                          controller: _titleController,
                          label: 'Class Title',
                          hint: 'e.g. Physics Quantum Mechanics',
                          icon: Icons.title_rounded,
                          accentColor: themeColor,
                          validator: (val) => val == null || val.isEmpty ? 'Please enter a valid title' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      _buildCustomTextField(
                        controller: _roomController,
                        label: 'Room Code',
                        hint: 'Enter or generate unique code',
                        icon: Icons.vpn_key_rounded,
                        accentColor: themeColor,
                        isCode: true,
                        validator: (val) => (val == null || val.length < 4) ? 'Enter valid room code (min 4 chars)' : null,
                      ),
                      const SizedBox(height: 30),
                      
                      // প্রিমিয়াম গ্রেডিয়েন্ট অ্যাকশন বাটন
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: _isLoading ? null : _handleLiveAction,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.isTeacher
                                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                    : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          widget.isTeacher ? Icons.videocam_rounded : Icons.login_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          widget.isTeacher ? 'GO LIVE WITH FYBTT' : 'JOIN CLASS NOW',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
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

  // মডার্ন ইনপুট ফিল্ড বিল্ডার উইজেট
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color accentColor,
    required String? Function(String?)? validator,
    bool isCode = false,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        fontSize: 14, 
        fontWeight: isCode ? FontWeight.bold : FontWeight.w500,
        color: const Color(0xFF1E293B),
        letterSpacing: isCode ? 1.5 : 0.2
      ),
      inputFormatters: isCode ? [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
