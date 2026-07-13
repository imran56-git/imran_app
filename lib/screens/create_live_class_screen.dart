import 'dart:ui';
import 'package:flutter/material.dart';

class LiveClassScreen extends StatefulWidget {
  final String channelName; 
  final String userName;

  const LiveClassScreen({
    super.key, 
    required this.channelName, 
    required this.userName
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _onToggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
  }

  void _onSwitchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  // লাইভ ক্লাস লিভ করার সময় কনফার্মেশন পপআপ (বাগ প্রিভেনশন)
  Future<bool> _showExitConfirmation() async {
    return await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (ctx, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('End Session?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: const Text('Are you sure you want to end or leave this live class?', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21), // প্রিমিয়াম ডার্ক স্টুডিও ব্যাকগ্রাউন্ড
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            children: [
              Text(
                widget.channelName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text('LIVE SESSION', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              )
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () async {
              if (await _showExitConfirmation()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            // ১. মেইন ভিডিও স্ট্রিম উইন্ডো (টিচার/হোস্ট ভিউ)
            Positioned.fill(
              child: _isVideoOff
                  ? Center(
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                        ),
                        child: const Icon(Icons.person, size: 60, color: Colors.white54),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1D1E33),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_rounded, size: 50, color: Colors.white24),
                            const SizedBox(height: 10),
                            Text('${widget.userName} Stream Active', style: const TextStyle(color: Colors.white30, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
            ),

            // ২. ফ্লোटिंग পিআইপি (Picture-in-Picture) উইন্ডো - স্টুডেন্ট থাম্বনেইল ভিউর জন্য
            Positioned(
              top: 20,
              right: 16,
              child: Container(
                width: 110,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E21),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  child: Center(
                    child: Icon(Icons.person_outline_rounded, color: Colors.white38, size: 30),
                  ),
                ),
              ),
            ),

            // ৩. কাটআউট ফিক্স: প্রফেশনাল কন্ট্রোল বাটন ড্যাশবোর্ড প্যানেল
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // অডিও মিউট বাটন
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isMuted ? Colors.redAccent : Colors.white.withOpacity(0.15),
                    iconColor: Colors.white,
                    onTap: _onToggleMute,
                  ),
                  const SizedBox(width: 16),
                  
                  // ভিডিও অন/অফ বাটন
                  _buildControlButton(
                    icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    color: _isVideoOff ? Colors.redAccent : Colors.white.withOpacity(0.15),
                    iconColor: Colors.white,
                    onTap: _onToggleVideo,
                  ),
                  const SizedBox(width: 16),

                  // ক্যামেরা টগল সুইচ বাটন
                  _buildControlButton(
                    icon: Icons.flip_camera_ios_rounded,
                    color: Colors.white.withOpacity(0.15),
                    iconColor: Colors.white,
                    onTap: _onSwitchCamera,
                  ),
                  const SizedBox(width: 32),

                  // লাল রঙের ইনডেক্স কল ডিসকানেক্ট বাটন
                  _buildControlButton(
                    icon: Icons.call_end_rounded,
                    color: Colors.red,
                    iconColor: Colors.white,
                    radius: 28,
                    onTap: () async {
                      if (await _showExitConfirmation()) {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double radius = 25,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Icon(icon, color: iconColor, size: radius * 0.92),
      ),
    );
  }
}
