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
        // --- ফিক্সড ও টাইপ-সেফ: স্ট্রিম থেকে প্রথম লেটেস্ট ডেটা নেওয়া হলো ---
        final liveClassData = await _liveClassService.watchLiveClass(roomId).first;

        if (liveClassData == null) {
          if (mounted) {
            _showErrorDialog('Invalid Room Code', 'No active live class found. Please check again.');
          }
          return;
        }

        // মডেল থেকে সরাসরি 'isLive' প্রোপার্টি চেক করা হচ্ছে
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E4C7A))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(widget.isTeacher ? 'Host Live Class' : 'Join Live Class',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    children: [
                      Icon(widget.isTeacher ? Icons.sensors_rounded : Icons.wifi_tethering_rounded,
                        size: 68, color: widget.isTeacher ? Colors.redAccent : Colors.blue[800],
                      ),
                      const SizedBox(height: 24),
                      if (widget.isTeacher) ...[
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Class Title',
                            prefixIcon: const Icon(Icons.title_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _roomController,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
                        decoration: InputDecoration(
                          labelText: 'Room Code',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (val) => (val == null || val.length < 4) ? 'Enter valid room code' : null,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: widget.isTeacher ? Colors.redAccent : Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: _isLoading ? null : _handleLiveAction,
                          child: Text(widget.isTeacher ? 'GO LIVE' : 'JOIN CLASS NOW', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
