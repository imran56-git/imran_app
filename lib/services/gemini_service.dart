import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/ai_knowledge.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const String _envGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _envGroqKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  String _resolvedGeminiKey = _envGeminiKey.trim();
  String _resolvedGroqKey = _envGroqKey.trim();
  bool _checkedFirestoreKeys = false;

  static const List<String> _geminiModels = [
    'gemini-2.0-flash',
    'gemini-2.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.1-pro',
    'gemini-2.5-pro',
    'gemini-4-argon',
  ];

  static const List<String> _groqModels = [
    'llama-3.1-8b-instant',
    'llama-3.3-70b-versatile',
  ];

  static const List<String> _groqVisionModels = [
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'llama-3.2-90b-vision-preview',
    'llama-3.2-11b-vision-preview',
  ];

  int _activeModelIndex = 0;
  bool _isBusy = false;

  final List<Map<String, String>> _conversationHistory = [];

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
        '   - Support both English and Bengali naturally matching the language of the prompt.';
  }

  Future<void> _ensureApiKeysLoaded() async {
    if (_resolvedGeminiKey.isNotEmpty && _resolvedGroqKey.isNotEmpty) return;
    if (_checkedFirestoreKeys) return;
    _checkedFirestoreKeys = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('ai_keys')
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String fbGemini = (data['geminiApiKey'] ?? '').toString().trim();
        final String fbGroq = (data['groqApiKey'] ?? '').toString().trim();
        if (_resolvedGeminiKey.isEmpty && fbGemini.isNotEmpty) {
          _resolvedGeminiKey = fbGemini;
        }
        if (_resolvedGroqKey.isEmpty && fbGroq.isNotEmpty) {
          _resolvedGroqKey = fbGroq;
        }
      }
    } catch (_) {}
  }

  void _recordTurn(String userPrompt, String aiResponse) {
    _conversationHistory.add({'role': 'user', 'content': userPrompt});
    _conversationHistory.add({'role': 'model', 'content': aiResponse});
    while (_conversationHistory.length > 20) {
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
      if (tokensB.any((tB) => tB == tA || tB.startsWith(tA) || tA.startsWith(tB))) {
        matchedTokens++;
      }
    }

    final int minLen =
        tokensA.length < tokensB.length ? tokensA.length : tokensB.length;
    return matchedTokens >= minLen;
  }

  Future<String> _callGeminiVisionHttp({
    required String prompt,
    required List<File> imageFiles,
  }) async {
    await _ensureApiKeysLoaded();

    final List<Map<String, dynamic>> parts = [
      {'text': prompt},
    ];

    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final mimeType = _detectMimeType(file.path);
      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Data,
        }
      });
    }

    Object? lastError;

    if (_resolvedGeminiKey.isNotEmpty) {
      for (final modelName in _geminiModels) {
        try {
          final Uri uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_resolvedGeminiKey',
          );

          final Map<String, dynamic> requestBody = {
            'contents': [
              {
                'role': 'user',
                'parts': parts,
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': 1024,
            },
          };

          final response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 18));

          if (response.statusCode == 200) {
            final Map<String, dynamic> decoded =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            final List<dynamic> candidates =
                (decoded['candidates'] as List<dynamic>?) ?? const [];
            if (candidates.isNotEmpty) {
              final content =
                  candidates.first['content'] as Map<String, dynamic>?;
              final resParts =
                  (content?['parts'] as List<dynamic>?) ?? const [];
              final StringBuffer buffer = StringBuffer();
              for (final p in resParts) {
                if (p is Map && p['thought'] != true && p['text'] != null) {
                  buffer.write(p['text'].toString());
                }
              }
              final out = buffer.toString().trim();
              if (out.isNotEmpty) return out;
            }
          } else {
            lastError = 'HTTP ${response.statusCode}';
          }
        } catch (e) {
          lastError = e;
        }
      }
    }

    if (_resolvedGroqKey.isNotEmpty) {
      final List<Map<String, dynamic>> contentList = [
        {'type': 'text', 'text': prompt},
      ];
      for (final file in imageFiles) {
        final bytes = await file.readAsBytes();
        final base64Data = base64Encode(bytes);
        final mimeType = _detectMimeType(file.path);
        contentList.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mimeType;base64,$base64Data',
          },
        });
      }

      for (final groqModel in _groqVisionModels) {
        try {
          final response = await http
              .post(
                Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $_resolvedGroqKey',
                },
                body: jsonEncode({
                  'model': groqModel,
                  'messages': [
                    {
                      'role': 'user',
                      'content': contentList,
                    }
                  ],
                  'temperature': 0.1,
                  'max_tokens': 1024,
                }),
              )
              .timeout(const Duration(seconds: 16));

          if (response.statusCode == 200) {
            final Map<String, dynamic> data =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            final List<dynamic> choices =
                (data['choices'] as List<dynamic>?) ?? const [];
            if (choices.isNotEmpty) {
              final msg = choices.first['message'] as Map<String, dynamic>?;
              final String text = (msg?['content'] ?? '').toString().trim();
              if (text.isNotEmpty) return text;
            }
          }
        } catch (e) {
          lastError = e;
        }
      }
    }

    throw Exception(lastError ?? 'Vision verification service unavailable.');
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

      final String rawResponse = await _callGeminiVisionHttp(
        prompt: prompt,
        imageFiles: [documentFile],
      );

      final Map<String, dynamic> parsed = _extractJsonMap(rawResponse);

      final bool isRealId = parsed['isRealGovernmentId'] == true;
      final String detectedType =
          (parsed['detectedDocumentType'] ?? 'Invalid').toString().trim();
      final bool matchesType = parsed['matchesSelectedType'] == true &&
          detectedType.toLowerCase() == selectedDocType.toLowerCase();
      final bool hasFace = parsed['hasFacePhoto'] == true || parsed['hasClearFacePhoto'] == true;
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

      final String rawResponse = await _callGeminiVisionHttp(
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

      final String rawResponse = await _callGeminiVisionHttp(
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

  Future<String> _callGeminiDirectHttp({
    required String modelName,
    required String prompt,
    String? systemPrompt,
  }) async {
    final String sysInstruction = _buildSystemInstruction(systemPrompt);

    final List<Map<String, dynamic>> contents = [];
    for (final turn in _conversationHistory) {
      final String role = turn['role'] == 'user' ? 'user' : 'model';
      final String text = (turn['content'] ?? '').trim();
      if (text.isEmpty) continue;
      contents.add({
        'role': role,
        'parts': [
          {'text': text}
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_resolvedGeminiKey',
    );

    final Map<String, dynamic> requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': sysInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
      },
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini ($modelName) HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final List<dynamic> candidates =
        (decoded['candidates'] as List<dynamic>?) ?? const [];

    if (candidates.isEmpty) {
      throw Exception('Empty candidates from $modelName');
    }

    final Map<String, dynamic>? content =
        candidates.first['content'] as Map<String, dynamic>?;
    final List<dynamic> parts =
        (content?['parts'] as List<dynamic>?) ?? const [];

    final StringBuffer replyBuffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['thought'] != true && part['text'] != null) {
        replyBuffer.write(part['text'].toString());
      }
    }

    final String finalText = replyBuffer.toString().trim();
    if (finalText.isEmpty) {
      throw Exception('Empty text output from $modelName');
    }

    return finalText;
  }

  Future<String> _callGroqDirectHttp(
    String prompt, {
    String? systemPrompt,
  }) async {
    if (_resolvedGroqKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not configured');
    }

    final String sysInstruction = _buildSystemInstruction(systemPrompt);
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': sysInstruction},
      ..._conversationHistory.map((turn) => {
            'role': turn['role'] == 'user' ? 'user' : 'assistant',
            'content': turn['content'] ?? '',
          }),
      {'role': 'user', 'content': prompt},
    ];

    Object? lastErr;
    for (final groqModel in _groqModels) {
      try {
        final response = await http
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_resolvedGroqKey',
              },
              body: jsonEncode({
                'model': groqModel,
                'messages': messages,
                'temperature': 0.4,
                'max_tokens': 1024,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          final List<dynamic> choices =
              (data['choices'] as List<dynamic>?) ?? const [];
          if (choices.isNotEmpty) {
            final msg = choices.first['message'] as Map<String, dynamic>?;
            final String text = (msg?['content'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              _recordTurn(prompt, text);
              return text;
            }
          }
        } else {
          lastErr = 'Groq HTTP ${response.statusCode}';
        }
      } catch (e) {
        lastErr = e;
      }
    }

    throw Exception('Groq fallback error: $lastErr');
  }

  Future<String> generateContent(String prompt, {String? systemPrompt}) async {
    final String cleanPrompt = prompt.trim().toLowerCase();
    final RegExp greetingRegExp = RegExp(
      r'^(hi|hello|hey|hlw|hlo|helo|hi there|hello fybtt|hi fybtt|good morning|good afternoon|good evening|নমস্কার|হ্যালো|হাই|সালাম|কেমন আছো|কেমন আছেন)[!?. ]*$',
      caseSensitive: false,
    );

    if (greetingRegExp.hasMatch(cleanPrompt)) {
      final bool isBengali = cleanPrompt.contains(RegExp(r'[\u0980-\u09FF]'));
      final String quickReply = isBengali
          ? 'হ্যালো! আজ আপনার পড়াশোনা বা কোনো বিষয়ের কনসেপ্ট বুঝতে কী সাহায্য করতে পারি?'
          : 'Hello! How can I help you with your studies or concepts today?';
      _recordTurn(prompt, quickReply);
      return quickReply;
    }

    await _ensureApiKeysLoaded();

    Object? lastError;

    if (_resolvedGeminiKey.isNotEmpty) {
      for (int i = 0; i < _geminiModels.length; i++) {
        final int idx = (_activeModelIndex + i) % _geminiModels.length;
        final String modelName = _geminiModels[idx];
        try {
          final String reply = await _callGeminiDirectHttp(
            modelName: modelName,
            prompt: prompt,
            systemPrompt: systemPrompt,
          );
          _activeModelIndex = idx;
          _recordTurn(prompt, reply);
          return reply;
        } catch (e) {
          lastError = e;
          debugPrint('Gemini model $modelName fallback: $e');
        }
      }
    }

    if (_resolvedGroqKey.isNotEmpty) {
      try {
        return await _callGroqDirectHttp(prompt, systemPrompt: systemPrompt);
      } catch (e) {
        lastError = e;
        debugPrint('Groq fallback failed: $e');
      }
    }

    throw Exception(lastError ?? 'AI assistant is currently busy. Please try again.');
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
      final String fullResponse = await generateContent(
        prompt,
        systemPrompt: systemPrompt,
      );

      final List<String> words = fullResponse.split(' ');
      final StringBuffer chunk = StringBuffer();

      for (int i = 0; i < words.length; i++) {
        chunk.write(i == words.length - 1 ? words[i] : '${words[i]} ');
        if (i % 3 == 2 || i == words.length - 1) {
          yield chunk.toString();
          chunk.clear();
          await Future.delayed(const Duration(milliseconds: 12));
        }
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<String?> sendChatMessage(String prompt) async {
    try {
      return await generateContent(prompt);
    } catch (e) {
      debugPrint('sendChatMessage error: $e');
      return null;
    }
  }

  void resetChat() {
    _isBusy = false;
    _conversationHistory.clear();
  }
}