import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // রুম কোড স্যানিটাইজেশন ফিল্টারিং-এর জন্য
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
  final _formKey = GlobalKey<FormState>(); // ইনপুট ভ্যালিডেশন ট্র্যাক করার জন্য
  bool _isLoading = false;

  @override
  void dispose() {
    _roomController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // ফিক্সড: রুম কোড ভ্যালিডেশন এবং স্টুডেন্ট লাইভ ভেরিফিকেশন ইঞ্জিন (#8, #9, #10)
  void _handleLiveAction() async {
    if (!_formKey.currentState!.validate()) return;

    final roomId = _roomController.text.trim().toLowerCase();
    final title = _titleController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (widget.isTeacher) {
        // টিচার লাইভ ক্লাস অবজেক্ট আর্কিটেকচার
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
        // ফিক্সড: স্টুডেন্টদের জন্য প্রি-ভেরিফিকেশন চেক রুল (#10)
        final liveSession = await _liveClassService.getLiveClassSnapshot(roomId);
        
        if (liveSession == null || !liveSession.exists) {
          if (mounted) {
            _showErrorDialog('Invalid Room Code', 'No active live class found with this room code. Please check again.');
          }
          return;
        }

        final sessionData = liveSession.data() as Map<String, dynamic>?;
        final bool isCurrentlyLive = sessionData?['isLive'] ?? false;

        if (!isCurrentlyLive) {
          if (mounted) {
            _showErrorDialog('Class Ended', 'This live class session has already been ended by the teacher.');
          }
          return;
        }

        // ক্লাস ভ্যালিড হলে পার্টিসিপেন্ট হিসেবে ফায়ারবেসে রেজিস্টার করা হবে
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
          SnackBar(
            content: Text('Connection error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ভেরিফিকেশন ফেইলড অ্যালার্ট উইজেট
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
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.black74)),
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
        title: Text(
          widget.isTeacher ? 'Host Live Class' : 'Join Live Class',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
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
        child: SingleChildScrollView( // ফিক্সড: কীবোর্ড ওভারফ্লো প্রটেকশন লেয়ার (#15)
          physics: const BouncingScrollPhysics(),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.025),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isTeacher ? Icons.sensors_rounded : Icons.wifi_tethering_rounded,
                        size: 68,
                        color: widget.isTeacher ? Colors.redAccent : Colors.blue[800],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isTeacher ? 'Start a New Session' : 'Enter Room Code',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B)),
                      ),
                      const SizedBox(height: 24),
                      
                      if (widget.isTeacher) ...[
                        TextFormField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Class Title / Subject',
                            hintText: 'e.g., Physics 1st Paper - Chapter 3',
                            prefixIcon: const Icon(Icons.title_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a class title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _roomController,
                        // ফিক্সড: রুম কোড লোয়ারকেস ও স্পেশাল ক্যারেক্টার ফিল্টারিং রুল (#9)
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), // স্পেস ও স্পেশাল ক্যারেক্টার টাইপ করা ব্লক করা হলো
                        ],
                        decoration: InputDecoration(
                          labelText: 'Room Code',
                          hintText: 'Letters or numbers only (no spaces)',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a room code';
                          }
                          if (val.trim().length < 4) {
                            return 'Room code must be at least 4 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isTeacher ? Colors.redAccent : Colors.blue[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleLiveAction,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  widget.isTeacher ? 'GO LIVE WITH JITSI' : 'JOIN CLASS NOW',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
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
