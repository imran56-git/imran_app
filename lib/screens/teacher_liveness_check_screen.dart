import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_liveness_service.dart';

class TeacherLivenessCheckScreen extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const TeacherLivenessCheckScreen({super.key, required this.registrationData});

  @override
  State<TeacherLivenessCheckScreen> createState() => _TeacherLivenessCheckScreenState();
}

class _TeacherLivenessCheckScreenState extends State<TeacherLivenessCheckScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final FaceLivenessService _livenessService = FaceLivenessService();
  bool _isChecking = false;
  bool _isVerifiedSuccess = false;
  String _statusMessage = "Position your face in the frame and blink.";
  File? _capturedFaceFile;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      _startLivenessScan();
    } catch (e) {
      setState(() {
        _statusMessage = "Camera initialization failed.";
      });
    }
  }

  void _startLivenessScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isChecking = true;
      _statusMessage = "Analyzing facial structure & liveness...";
    });

    int attempts = 0;
    while (attempts < 30 && !_isVerifiedSuccess) {
      try {
        final image = await _cameraController!.takePicture();
        final file = File(image.path);
        final inputImage = InputImage.fromFilePath(image.path);

        bool isLive = await _livenessService.checkLiveness(inputImage);

        if (isLive) {
          _capturedFaceFile = file;
          setState(() {
            _isVerifiedSuccess = true;
            _statusMessage = "Face Liveness Verified Successfully!";
          });
          await Future.delayed(const Duration(milliseconds: 900));
          if (mounted) {
            Navigator.pop(context, {
              'success': true,
              'faceFile': _capturedFaceFile,
            });
          }
          break;
        }
      } catch (e) {
        // Handle error silently during loop
      }

      attempts++;
      if (mounted) {
        setState(() {
          _statusMessage = "Processing secure biometric check (Attempt $attempts/30)...";
        });
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (!_isVerifiedSuccess && mounted) {
      setState(() {
        _isChecking = false;
        _statusMessage = "Verification timed out. Please ensure good lighting and retry.";
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    _livenessService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Face & Liveness Verification", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _cameraController == null || !_cameraController!.value.isInitialized
                  ? const CircularProgressIndicator(color: Colors.blueAccent)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 312,
                            height: 412,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: _isVerifiedSuccess
                                    ? Colors.greenAccent
                                    : (_isChecking ? Colors.blueAccent : Colors.orangeAccent),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 300,
                            height: 400,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                        if (_isChecking && !_isVerifiedSuccess)
                          Positioned(
                            bottom: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Backend AI processing...",
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!_isChecking && !_isVerifiedSuccess)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startLivenessScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Retry Verification", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
