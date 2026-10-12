import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class DocumentVerificationService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractTextFromDocument(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return '';
    }
  }

  bool verifyNameMatch(String extractedText, String registeredName) {
    if (extractedText.isEmpty || registeredName.isEmpty) return false;
    
    final cleanExtracted = extractedText.toLowerCase();
    final cleanName = registeredName.toLowerCase();
    
    List<String> nameParts = cleanName.split(' ');
    int matchCount = 0;
    
    for (String part in nameParts) {
      if (part.length > 2 && cleanExtracted.contains(part)) {
        matchCount++;
      }
    }
    
    if (nameParts.isNotEmpty && (matchCount / nameParts.length) >= 0.7) {
      return true;
    }
    
    return cleanExtracted.contains(cleanName);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
