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

class _TeacherLivenessCheckScreenState extends State<TeacherLivenessCheckScreen> {
  CameraController? _cameraController;
  final FaceLivenessService _livenessService = FaceLivenessService();
  bool _isChecking = false;
  bool _isVerifiedSuccess = false;
  String _statusMessage = "Position your face in the frame and blink.";

  @override
  void initState() {
    super.initState();
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
    });

    int attempts = 0;
    while (attempts < 30 && !_isVerifiedSuccess) {
      try {
        final image = await _cameraController!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        
        bool isLive = await _livenessService.checkLiveness(inputImage);

        if (isLive) {
          setState(() {
            _isVerifiedSuccess = true;
            _statusMessage = "Liveness Verified Successfully!";
          });
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context, true);
          }
          break;
        }
      } catch (e) {
        // Handle error silently during loop
      }

      attempts++;
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (!_isVerifiedSuccess && mounted) {
      setState(() {
        _isChecking = false;
        _statusMessage = "Verification failed. Please try again.";
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _livenessService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("AI Face & Liveness Verification", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _cameraController == null || !_cameraController!.value.isInitialized
                  ? const CircularProgressIndicator()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 300,
                        height: 400,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!_isChecking && !_isVerifiedSuccess)
                  ElevatedButton(
                    onPressed: _startLivenessScan,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: const Text("Retry Verification", style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
