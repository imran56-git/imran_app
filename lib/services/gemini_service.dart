import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../constants/ai_knowledge.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  bool _isBusy = false;
  final List<Content> _conversationHistory = [];

  String _buildSystemInstruction([String? customSystemPrompt]) {
    if (customSystemPrompt != null && customSystemPrompt.trim().isNotEmpty) {
      return customSystemPrompt.trim();
    }
    return '${AiKnowledge.systemInstruction}\n\n'
        'CRITICAL RESPONSE GUIDELINES (STRICT COMPLIANCE):\n'
        '1. NO UNPROMPTED GREETINGS OR META-INTRODUCTIONS:\n'
        '   - NEVER begin answers with "Hello! As the official AI Assistant for FYBTT...", "I would be delighted to...", or similar repetitive introductory fluff.\n'
        '   - Dive straight into the core, direct explanation or solution in sentence 1.\n'
        '   - Only greet if the user explicitly greets you first (e.g., "Hi", "Hello").\n'
        '   - Do NOT add repetitive closing advertisements like "If you need help mastering these formulas or want to connect with teachers on FYBTT..." unless the user specifically asks how to find a teacher.\n\n'
        '2. MATHEMATICAL & SCIENTIFIC FORMULA FORMATTING (NO RAW LATEX):\n'
        '   - NEVER output raw LaTeX syntax with dollar delimiters such as "\$\$... \$\$", "\$...\$", "\\times", "\\sum", "\\quad", or "\\text{}". The chat UI does not parse raw dollar LaTeX.\n'
        '   - ALWAYS render formulas and equations using clean, universally readable UNICODE symbols and clean typography:\n'
        '     * Multiplication: use "×" or "·" (never write "\\times" or "*")\n'
        '     * Division: use "/" or "÷"\n'
        '     * Exponents & Subscripts: use unicode superscripts/subscripts like "x²", "v² = u² + 2as", "H₂O", "F_net", "a_avg"\n'
        '     * Mathematical & Greek symbols: "∑", "√", "π", "θ", "α", "β", "γ", "λ", "μ", "ω", "∆", "∫", "±", "≈", "≠", "≤", "≥", "sin θ", "cos θ", "tan θ"\n'
        '   - Present equations prominently on their own lines:\n'
        '     Example: **F = m × a**\n'
        '     Example: **∑F = 0 (when a = 0)**\n'
        '     Example: **v = u + a·t**\n'
        '     Example: **s = u·t + ½a·t²**\n'
        '     Followed immediately by clean bullet points defining each variable.\n\n'
        '3. ACCURACY & LANGUAGE:\n'
        '   - Keep answers structured, engaging, and direct for students.\n'
        '   - Respond clearly in English.';
  }

  void _recordTurn(String userPrompt, String aiResponse) {
    if (aiResponse.trim().isEmpty) return;
    _conversationHistory.add(Content.text(userPrompt));
    _conversationHistory.add(Content.model([TextPart(aiResponse)]));
    while (_conversationHistory.length > 8) {
      _conversationHistory.removeAt(0);
    }
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  Map<String, dynamic> _extractJsonMap(String rawText) {
    String cleaned = rawText.trim();
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
    }
    cleaned = cleaned.trim();

    final int startBrace = cleaned.indexOf('{');
    final int endBrace = cleaned.lastIndexOf('}');
    if (startBrace != -1 && endBrace != -1 && endBrace > startBrace) {
      cleaned = cleaned.substring(startBrace, endBrace + 1);
    }

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  static bool doNamesMatch(String nameA, String nameB) {
    String normalize(String input) {
      String s = input.toLowerCase().trim();
      s = s.replaceAll(RegExp(r'[^a-z\s]'), ' ');
      final prefixes = [
        'md',
        'mohammad',
        'mohammed',
        'muhammad',
        'mr',
        'mrs',
        'ms',
        'miss',
        'dr',
        'prof',
        'sri',
        'shri',
        'smt',
        'sk',
        'sheikh',
      ];
      final tokens = s
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty && !prefixes.contains(t))
          .toList();
      return tokens.join(' ');
    }

    final normA = normalize(nameA);
    final normB = normalize(nameB);

    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;
    if (normA.contains(normB) || normB.contains(normA)) return true;

    final tokensA = normA.split(' ').where((t) => t.length > 1).toSet();
    final tokensB = normB.split(' ').where((t) => t.length > 1).toSet();

    if (tokensA.isEmpty || tokensB.isEmpty) return false;

    int matchedTokens = 0;
    for (final tA in tokensA) {
      if (tokensB.any(
          (tB) => tB == tA || tB.startsWith(tA) || tA.startsWith(tB))) {
        matchedTokens++;
      }
    }

    final int minLen =
        tokensA.length < tokensB.length ? tokensA.length : tokensB.length;
    return matchedTokens >= minLen;
  }

  Future<String> _callGeminiVision({
    required String prompt,
    required List<File> imageFiles,
  }) async {
    final List<Part> parts = [TextPart(prompt)];

    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      final mimeType = _detectMimeType(file.path);
      parts.add(InlineDataPart(mimeType, bytes));
    }

    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 1024,
      ),
    );

    final response = await model.generateContent([
      Content.multi(parts),
    ]);

    final String output = response.text?.trim() ?? '';
    if (output.isEmpty) {
      throw Exception('Empty response from vision model.');
    }
    return output;
  }

  Future<Map<String, dynamic>> verifyGovernmentIdDocument({
    required File documentFile,
    required String selectedDocType,
    String? expectedFullName,
  }) async {
    try {
      final String prompt = '''
You are a strict document forensics verification system.
The user claims this image is their "$selectedDocType" (Allowed types: "Aadhaar Card", "PAN Card", "Passport").

Inspect the image carefully and respond ONLY with a valid JSON object using this exact schema:
{
  "isRealGovernmentId": true or false,
  "detectedDocumentType": "Aadhaar Card" or "PAN Card" or "Passport" or "Invalid",
  "matchesSelectedType": true or false,
  "hasFacePhoto": true or false,
  "extractedFullName": "Full name in English written on the document, or empty string if unreadable",
  "fatherOrGuardianName": "Father or guardian name if visible, or empty string",
  "dateOfBirth": "DOB if visible, or empty string",
  "rejectionReason": "Clear English message if invalid or mismatched, otherwise empty string"
}

Strict Rules:
1. If the image is a random object, plant leaf, blank page, scenery, selfie only, screenshot of random text, or blurry/unreadable, set "isRealGovernmentId": false and provide a clear English "rejectionReason" such as "Invalid image: No valid government ID card could be scanned from this photo."
2. If the user selected "$selectedDocType" but uploaded a different document (for example, selected PAN Card but uploaded Aadhaar Card or a certificate), set "matchesSelectedType": false and provide a clear English "rejectionReason" such as "Document mismatch: You selected $selectedDocType, but the uploaded image is not a valid $selectedDocType."
3. Do NOT output or echo any sensitive national identification numbers in the JSON. Only extract the holder's English name, DOB, and validity flags.
''';

      final String rawResponse = await _callGeminiVision(
        prompt: prompt,
        imageFiles: [documentFile],
      );

      final Map<String, dynamic> parsed = _extractJsonMap(rawResponse);

      final bool isRealId = parsed['isRealGovernmentId'] == true;
      final String detectedType =
          (parsed['detectedDocumentType'] ?? 'Invalid').toString().trim();
      final bool matchesType = parsed['matchesSelectedType'] == true &&
          detectedType.toLowerCase() == selectedDocType.toLowerCase();
      final bool hasFace = parsed['hasFacePhoto'] == true ||
          parsed['hasClearFacePhoto'] == true;
      final String extractedName =
          (parsed['extractedFullName'] ?? '').toString().trim();

      if (!isRealId || !matchesType || extractedName.isEmpty) {
        final String reason =
            (parsed['rejectionReason'] ?? '').toString().trim();
        return {
          'isValid': false,
          'detectedDocumentType': detectedType,
          'extractedName': extractedName,
          'hasFacePhoto': hasFace,
          'nameMatches': false,
          'errorMessage': reason.isNotEmpty
              ? reason
              : 'Could not verify this image as a valid $selectedDocType. Please upload a clear and original photo of your $selectedDocType.',
        };
      }

      if (!hasFace) {
        return {
          'isValid': false,
          'detectedDocumentType': detectedType,
          'extractedName': extractedName,
          'hasFacePhoto': false,
          'nameMatches': false,
          'errorMessage':
              'The uploaded $selectedDocType does not have a clear portrait photo for face verification. Please upload the front side showing your photo and name clearly.',
        };
      }

      bool nameMatches = true;
      if (expectedFullName != null && expectedFullName.trim().isNotEmpty) {
        nameMatches = doNamesMatch(expectedFullName, extractedName);
      }

      return {
        'isValid': true,
        'detectedDocumentType': detectedType,
        'extractedName': extractedName,
        'fatherOrGuardianName':
            (parsed['fatherOrGuardianName'] ?? '').toString().trim(),
        'dateOfBirth': (parsed['dateOfBirth'] ?? '').toString().trim(),
        'hasFacePhoto': hasFace,
        'nameMatches': nameMatches,
        'errorMessage': nameMatches
            ? ''
            : 'Name Mismatch: Full Name entered ("$expectedFullName") does not match the name on your $selectedDocType ("$extractedName").',
      };
    } catch (e) {
      debugPrint('verifyGovernmentIdDocument error: $e');
      return {
        'isValid': false,
        'detectedDocumentType': 'Invalid',
        'extractedName': '',
        'hasFacePhoto': false,
        'nameMatches': false,
        'errorMessage':
            'Unable to scan the uploaded document. Please ensure you have an active internet connection and upload a clear photo of your $selectedDocType.',
      };
    }
  }

  Future<Map<String, dynamic>> verifyQualificationCertificate({
    required File certificateFile,
    String? expectedFullName,
  }) async {
    try {
      const String prompt = '''
You are an academic credential verification engine.
Inspect this image and determine whether it is a genuine educational qualification certificate, degree certificate, diploma, or official academic examination marksheet (such as Secondary/Madhyamik, Higher Secondary, B.A, B.Sc, B.Com, B.Tech, MBBS, M.A, M.Sc, B.Ed, D.El.Ed, Ph.D, or university/board credential).

Respond ONLY with a valid JSON object in English using this exact schema:
{
  "isValidEducationalDocument": true or false,
  "documentCategory": "Degree Certificate" or "Academic Marksheet" or "Board Certificate" or "Diploma Certificate" or "Invalid",
  "qualificationTitle": "Full name of the exam or degree in English (e.g., Bachelor of Science, Secondary Examination, MBBS, Higher Secondary Examination)",
  "institutionOrCollege": "Name of the School, College, or Institute in English (or 'Specified by Board/University' if only board is printed)",
  "boardOrUniversity": "Name of the University, Board, or Examination Council in English",
  "candidateName": "Full name of the student/candidate on the certificate in English",
  "streamOrSubjects": "Main subjects, specialization, honours, or stream in English",
  "passingYear": "Year of passing or examination session if visible, otherwise 'Verified'",
  "divisionOrGrade": "Division, class, grade, or percentage if visible, otherwise 'Passed'",
  "rejectionReason": "Clear English explanation if the image is not a valid educational certificate or is unreadable"
}

Strict Rules:
1. If the image is a plant leaf, random object, selfie, government ID card (like Aadhaar/PAN), blank page, or unreadable photo, set "isValidEducationalDocument": false and set "rejectionReason" to "Unable to scan any valid educational qualification certificate from this image. Please upload a clear photo of your academic certificate or marksheet."
2. Translate any regional script text into clean English in the JSON values.
''';

      final String rawResponse = await _callGeminiVision(
        prompt: prompt,
        imageFiles: [certificateFile],
      );

      final Map<String, dynamic> parsed = _extractJsonMap(rawResponse);
      final bool isValidDoc = parsed['isValidEducationalDocument'] == true;
      final String qualificationTitle =
          (parsed['qualificationTitle'] ?? '').toString().trim();
      final String candidateName =
          (parsed['candidateName'] ?? '').toString().trim();
      final String boardOrUniversity =
          (parsed['boardOrUniversity'] ?? '').toString().trim();
      final String institutionOrCollege =
          (parsed['institutionOrCollege'] ?? '').toString().trim();

      if (!isValidDoc ||
          qualificationTitle.isEmpty ||
          (boardOrUniversity.isEmpty && institutionOrCollege.isEmpty)) {
        final String reason =
            (parsed['rejectionReason'] ?? '').toString().trim();
        return {
          'isValid': false,
          'errorMessage': reason.isNotEmpty
              ? reason
              : 'Unable to scan any valid educational qualification certificate from this image. Please upload a clear photo of your certificate or marksheet.',
        };
      }

      bool nameMatches = true;
      if (expectedFullName != null &&
          expectedFullName.trim().isNotEmpty &&
          candidateName.isNotEmpty) {
        nameMatches = doNamesMatch(expectedFullName, candidateName);
      }

      return {
        'isValid': true,
        'documentCategory':
            (parsed['documentCategory'] ?? 'Educational Certificate')
                .toString()
                .trim(),
        'qualificationTitle': qualificationTitle,
        'institutionOrCollege': institutionOrCollege.isNotEmpty
            ? institutionOrCollege
            : boardOrUniversity,
        'boardOrUniversity': boardOrUniversity.isNotEmpty
            ? boardOrUniversity
            : institutionOrCollege,
        'candidateName': candidateName,
        'streamOrSubjects':
            (parsed['streamOrSubjects'] ?? 'General Academic Stream')
                .toString()
                .trim(),
        'passingYear':
            (parsed['passingYear'] ?? 'Verified').toString().trim(),
        'divisionOrGrade':
            (parsed['divisionOrGrade'] ?? 'Qualified').toString().trim(),
        'nameMatches': nameMatches,
        'errorMessage': nameMatches
            ? ''
            : 'Name Mismatch: Candidate name on the certificate ("$candidateName") does not match your Full Name ("$expectedFullName").',
      };
    } catch (e) {
      debugPrint('verifyQualificationCertificate error: $e');
      return {
        'isValid': false,
        'errorMessage':
            'Could not scan this image. Please upload a clear, well-lit photo of your educational qualification certificate.',
      };
    }
  }

  Future<Map<String, dynamic>> verifyFaceMatchWithIdCard({
    required File idDocumentFile,
    required File liveFaceFile,
    double minimumSimilarityThreshold = 85.0,
  }) async {
    try {
      const String prompt = '''
You are a biometric face comparison expert.
Image 1 is the user's official Government ID Card containing their portrait photo.
Image 2 is a live selfie captured during Face Liveness Verification.

Compare the face on the ID Card (Image 1) with the live face (Image 2).
Important Biometric Guidelines:
1. Government ID cards often contain childhood, teenage, or 5-to-15-year-old photographs.
2. You MUST account for natural aging, weight changes, facial hair differences (clean-shaven vs heavy beard/mustache), hairstyle changes, receding hairline, or baldness, and eyeglasses.
3. Focus on permanent craniofacial structure: interpupillary distance, eye shape, nasal bridge and tip proportion, philtrum, ear alignment, and bone structure.
4. If the underlying facial bone structure belongs to the same person (even with age, beard, or hair changes), assign a biometric similarity score between 85 and 98.
5. If the two faces clearly belong to two different individuals (or if either image does not contain a real human face), assign a similarity score below 50 and set "isSamePerson": false.

Respond ONLY with a valid JSON object in English using this exact schema:
{
  "hasFaceInIdCard": true or false,
  "hasFaceInLivePhoto": true or false,
  "isSamePerson": true or false,
  "similarityPercentage": number between 0 and 100,
  "verificationSummary": "Brief English explanation of the biometric comparison result"
}
''';

      final String rawResponse = await _callGeminiVision(
        prompt: prompt,
        imageFiles: [idDocumentFile, liveFaceFile],
      );

      final Map<String, dynamic> parsed = _extractJsonMap(rawResponse);
      final bool hasIdFace = parsed['hasFaceInIdCard'] == true;
      final bool hasLiveFace = parsed['hasFaceInLivePhoto'] == true;
      final bool isSame = parsed['isSamePerson'] == true;
      final double similarity =
          (parsed['similarityPercentage'] as num?)?.toDouble() ?? 0.0;
      final String summary =
          (parsed['verificationSummary'] ?? '').toString().trim();

      if (!hasIdFace || !hasLiveFace) {
        return {
          'isMatched': false,
          'similarityPercentage': 0.0,
          'message':
              'Face could not be clearly detected on both the ID proof and live capture. Please ensure clear lighting.',
        };
      }

      final bool passed =
          isSame && similarity >= minimumSimilarityThreshold;

      return {
        'isMatched': passed,
        'similarityPercentage': similarity,
        'message': passed
            ? 'Face matched with ID proof (${similarity.toStringAsFixed(0)}% biometric similarity).'
            : (summary.isNotEmpty
                ? 'Face Verification Failed (${similarity.toStringAsFixed(0)}% match): $summary'
                : 'Face Verification Failed: Live face does not match the photo on your uploaded ID card (${similarity.toStringAsFixed(0)}% similarity, minimum ${minimumSimilarityThreshold.toStringAsFixed(0)}% required).'),
      };
    } catch (e) {
      debugPrint('verifyFaceMatchWithIdCard error: $e');
      return {
        'isMatched': false,
        'similarityPercentage': 0.0,
        'message':
            'Could not complete biometric face comparison with ID proof. Please try again with clear lighting.',
      };
    }
  }

  Future<String> generateContent(String prompt, {String? systemPrompt}) async {
    final String cleanPrompt = prompt.trim().toLowerCase();
    final RegExp greetingRegExp = RegExp(
      r'^(hi|hello|hey|hlw|hlo|helo|hi there|hello fybtt|hi fybtt|good morning|good afternoon|good evening)[!?. ]*$',
      caseSensitive: false,
    );

    if (greetingRegExp.hasMatch(cleanPrompt)) {
      const String quickReply =
          'Hello! How can I help you with your studies or concepts today?';
      _recordTurn(prompt, quickReply);
      return quickReply;
    }

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-lite',
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 800,
        ),
        systemInstruction:
            Content.system(_buildSystemInstruction(systemPrompt)),
      );

      final List<Content> contents = [
        ..._conversationHistory,
        Content.text(prompt),
      ];

      final response = await model.generateContent(contents);
      final String reply = response.text?.trim() ?? '';
      if (reply.isNotEmpty) {
        _recordTurn(prompt, reply);
        return reply;
      }
    } catch (e) {
      debugPrint('Gemini generateContent error: $e');
    }

    return 'I apologize, but I encountered a temporary network or quota issue while processing your request. Please try asking again in a moment.';
  }

  Stream<String> generateContentStream(
    String prompt, {
    String? systemPrompt,
  }) async* {
    if (_isBusy) {
      _isBusy = false;
    }

    _isBusy = true;
    try {
      final String cleanPrompt = prompt.trim().toLowerCase();
      final RegExp greetingRegExp = RegExp(
        r'^(hi|hello|hey|hlw|hlo|helo|hi there|hello fybtt|hi fybtt|good morning|good afternoon|good evening)[!?. ]*$',
        caseSensitive: false,
      );

      if (greetingRegExp.hasMatch(cleanPrompt)) {
        const String quickReply =
            'Hello! How can I help you with your studies or concepts today?';
        _recordTurn(prompt, quickReply);
        yield quickReply;
        return;
      }

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-lite',
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 800,
        ),
        systemInstruction:
            Content.system(_buildSystemInstruction(systemPrompt)),
      );

      final List<Content> contents = [
        ..._conversationHistory,
        Content.text(prompt),
      ];

      final StringBuffer totalResponse = StringBuffer();
      final Stream<GenerateContentResponse> responseStream =
          model.generateContentStream(contents);

      await for (final chunk in responseStream) {
        final String? chunkText = chunk.text;
        if (chunkText != null && chunkText.isNotEmpty) {
          totalResponse.write(chunkText);
          yield chunkText;
        }
      }

      final String completeText = totalResponse.toString().trim();
      if (completeText.isNotEmpty) {
        _recordTurn(prompt, completeText);
      }
    } catch (e) {
      debugPrint('Gemini generateContentStream error: $e');
      yield 'I apologize, but I encountered a temporary network or quota issue while processing your request. Please try asking again in a moment.';
    } finally {
      _isBusy = false;
    }
  }

  Future<String?> sendChatMessage(String prompt) async {
    try {
      final res = await generateContent(prompt);
      return res.trim().isNotEmpty ? res : null;
    } catch (e) {
      debugPrint('sendChatMessage error: $e');
      return 'I am sorry, but I am unable to connect to the educational database right now. Please verify your internet connection and try again.';
    }
  }

  void resetChat() {
    _isBusy = false;
    _conversationHistory.clear();
  }
}