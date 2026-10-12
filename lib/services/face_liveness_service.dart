import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceLivenessService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<bool> checkLiveness(InputImage inputImage) async {
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      if (faces.length == 1) {
        final Face face = faces.first;
        double? leftEyeOpen = face.leftEyeOpenProbability;
        double? rightEyeOpen = face.rightEyeOpenProbability;
        
        if (leftEyeOpen != null && rightEyeOpen != null) {
          if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
