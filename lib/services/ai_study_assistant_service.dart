import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import 'chat_service.dart';

class AiStudyAssistantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  Future<bool> hasUserGrantedAiConsent(String userId) async {
    if (userId.trim().isEmpty) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('privacy_settings')
          .doc('ai_assistant')
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['consentGranted'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setUserAiConsent({
    required String userId,
    required bool granted,
  }) async {
    if (userId.trim().isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('privacy_settings')
        .doc('ai_assistant')
        .set({
      'consentGranted': granted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _sanitizeTextForPrivacy(String input) {
    String sanitized = input;
    final emailRegex =
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phoneRegex = RegExp(r'(\+?\d[\d\-\s]{7,}\d)');
    sanitized = sanitized.replaceAll(emailRegex, '[Redacted Email]');
    sanitized = sanitized.replaceAll(phoneRegex, '[Redacted Phone]');
    return sanitized.trim();
  }

  Future<List<MessageModel>> _fetchRecentGroupMessages(
    String groupId, {
    int limit = 60,
  }) async {
    final snap = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((doc) {
          final data = doc.data();
          data['messageId'] = doc.id;
          return MessageModel.fromMap(data);
        })
        .where((m) => !m.isDeletedForEveryone && !m.isExpired)
        .toList();
  }

  Future<String> summarizeGroupDiscussion({
    required String groupId,
    required String userId,
    int messageLimit = 60,
  }) async {
    final hasConsent = await hasUserGrantedAiConsent(userId);
    if (!hasConsent) {
      throw Exception(
          'AI Privacy Consent required before summarizing chat messages.');
    }

    final messages =
        await _fetchRecentGroupMessages(groupId, limit: messageLimit);
    if (messages.isEmpty) {
      return 'No recent messages found in this group to summarize.';
    }

    final List<String> teacherPoints = [];
    final List<String> studentDoubts = [];
    final List<String> generalTopics = [];
    int mediaOrDocsCount = 0;

    for (final msg in messages.reversed) {
      if (msg.type != 'text') {
        mediaOrDocsCount++;
        continue;
      }

      final cleanContent = _sanitizeTextForPrivacy(msg.content);
      if (cleanContent.isEmpty) continue;

      final bool isTeacher = msg.senderRole == 'teacher';
      final String category = msg.messageCategory.toLowerCase();

      if (isTeacher ||
          category == 'announcement' ||
          category == 'homework' ||
          category == 'exam_notice') {
        if (teacherPoints.length < 6) {
          teacherPoints.add(cleanContent);
        }
      } else if (category == 'doubt' || cleanContent.contains('?')) {
        if (studentDoubts.length < 5) {
          studentDoubts.add('Student asked: $cleanContent');
        }
      } else {
        if (generalTopics.length < 5 && cleanContent.length > 12) {
          generalTopics.add(cleanContent);
        }
      }
    }

    final StringBuffer summary = StringBuffer();
    summary.writeln('🤖 AI Group Discussion Summary');
    summary.writeln('Analyzed last ${messages.length} messages (Privacy Protected)\n');

    if (teacherPoints.isNotEmpty) {
      summary.writeln('📌 Key Teacher Guidance & Updates:');
      for (final point in teacherPoints) {
        summary.writeln('• $point');
      }
      summary.writeln();
    }

    if (studentDoubts.isNotEmpty) {
      summary.writeln('❓ Main Academic Doubts Raised:');
      for (final doubt in studentDoubts) {
        summary.writeln('• $doubt');
      }
      summary.writeln();
    }

    if (generalTopics.isNotEmpty) {
      summary.writeln('💬 Discussion Highlights:');
      for (final topic in generalTopics) {
        summary.writeln('• $topic');
      }
      summary.writeln();
    }

    if (mediaOrDocsCount > 0) {
      summary.writeln(
          '📎 Shared Resources: $mediaOrDocsCount study files/media items were shared recently.');
    }

    return summary.toString().trim();
  }

  Future<String> summarizeImportantAnnouncements({
    required String groupId,
    required String userId,
  }) async {
    final hasConsent = await hasUserGrantedAiConsent(userId);
    if (!hasConsent) {
      throw Exception(
          'AI Privacy Consent required before summarizing announcements.');
    }

    final messages = await _fetchRecentGroupMessages(groupId, limit: 100);
    final importantMessages = messages.where((m) {
      final cat = m.messageCategory.toLowerCase();
      return m.isPinned ||
          cat == 'announcement' ||
          cat == 'homework' ||
          cat == 'assignment' ||
          cat == 'exam_notice' ||
          cat == 'class_update';
    }).toList();

    if (importantMessages.isEmpty) {
      return 'No pinned announcements, homework, or exam notices found in this batch yet.';
    }

    final List<String> announcements = [];
    final List<String> homeworks = [];
    final List<String> examsAndUpdates = [];

    for (final msg in importantMessages) {
      final cleanText = _sanitizeTextForPrivacy(msg.content);
      if (cleanText.isEmpty) continue;
      final cat = msg.messageCategory.toLowerCase();

      if (cat == 'homework' || cat == 'assignment') {
        homeworks.add(cleanText);
      } else if (cat == 'exam_notice' || cat == 'class_update') {
        examsAndUpdates.add(cleanText);
      } else {
        announcements.add(cleanText);
      }
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📢 Important Batch Announcements & Action Items\n');

    if (announcements.isNotEmpty) {
      buffer.writeln('🔔 Teacher Announcements:');
      for (final item in announcements.take(5)) {
        buffer.writeln('• $item');
      }
      buffer.writeln();
    }

    if (homeworks.isNotEmpty) {
      buffer.writeln('📚 Pending Homework & Assignments:');
      for (final item in homeworks.take(5)) {
        buffer.writeln('• $item');
      }
      buffer.writeln();
    }

    if (examsAndUpdates.isNotEmpty) {
      buffer.writeln('🗓️ Exam Notices & Class Schedule Updates:');
      for (final item in examsAndUpdates.take(5)) {
        buffer.writeln('• $item');
      }
    }

    return buffer.toString().trim();
  }

  Future<String> summarizeStudyMaterial({
    required String title,
    required String contentOrNotes,
    required String userId,
  }) async {
    final cleanNotes = _sanitizeTextForPrivacy(contentOrNotes);
    if (cleanNotes.isEmpty) {
      return 'Please paste or select study material text to generate a summary.';
    }

    final List<String> sentences = cleanNotes
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.length > 15)
        .toList();

    final List<String> keySentences = sentences.take(6).toList();

    final StringBuffer summary = StringBuffer();
    summary.writeln(
        '📖 Study Material Summary${title.trim().isNotEmpty ? ': ${title.trim()}' : ''}\n');
    summary.writeln('🎯 Core Takeaways:');
    if (keySentences.isEmpty) {
      summary.writeln('• $cleanNotes');
    } else {
      for (final s in keySentences) {
        summary.writeln('• $s');
      }
    }

    summary.writeln('\n💡 Exam Revision Tip:');
    summary.writeln(
        '• Focus on the key definitions, formulas, and cause-effect relationships highlighted above.');
    summary.writeln(
        '• Practice 2–3 application questions from this topic to test your understanding.');

    return summary.toString().trim();
  }

  Future<String> explainDifficultQuestion({
    required String question,
    String subject = '',
    required String userId,
  }) async {
    final cleanQ = _sanitizeTextForPrivacy(question);
    if (cleanQ.isEmpty) {
      return 'Please enter the question or concept you want explained.';
    }

    final String subjectLabel =
        subject.trim().isNotEmpty ? subject.trim() : 'Academic Concept';

    final StringBuffer explanation = StringBuffer();
    explanation.writeln('🧠 Simple Step-by-Step Explanation ($subjectLabel)\n');
    explanation.writeln('❓ Question / Concept:\n"$cleanQ"\n');
    explanation.writeln('1️⃣ Core Idea in Simple Words:');
    explanation.writeln(
        'Break the problem down by identifying what is given and what is being asked. Relate it to the fundamental principle of $subjectLabel.\n');
    explanation.writeln('2️⃣ Step-by-Step Approach:');
    explanation.writeln(
        '• Step 1: Write down the key terms, known values, or core definitions from the question.');
    explanation.writeln(
        '• Step 2: Apply the standard rule, theorem, or logical connection step by step.');
    explanation.writeln(
        '• Step 3: Verify the final conclusion or unit to ensure accuracy.\n');
    explanation.writeln('3️⃣ Quick Memory Trick:');
    explanation.writeln(
        'Always link the keyword in "$cleanQ" with its primary formula or definition so you can recall it quickly during exams.');

    return explanation.toString().trim();
  }

  Future<String> assistWithHomework({
    required String homeworkPrompt,
    String subject = '',
    required String userId,
  }) async {
    final cleanPrompt = _sanitizeTextForPrivacy(homeworkPrompt);
    if (cleanPrompt.isEmpty) {
      return 'Please enter your homework question to get guided assistance.';
    }

    final StringBuffer guide = StringBuffer();
    guide.writeln(
        '📝 AI Homework Guide${subject.isNotEmpty ? ' ($subject)' : ''}\n');
    guide.writeln('📌 Task:\n"$cleanPrompt"\n');
    guide.writeln('🔍 How to Solve This Yourself:');
    guide.writeln(
        '• Understand the Objective: Read the prompt carefully and underline the main action words (e.g., prove, calculate, explain, compare).');
    guide.writeln(
        '• Structure Your Answer: Start with a clear definition or formula, show intermediate working steps clearly, and highlight the final conclusion.');
    guide.writeln(
        '• Common Mistake to Avoid: Do not skip intermediate steps—teachers award marks for clear methodology.\n');
    guide.writeln(
        '💬 Still stuck on a specific step? Post it in the Group "Doubts" section so your teacher can review your working!');

    return guide.toString().trim();
  }

  Future<String> askStudyAssistant({
    required String query,
    String subject = '',
    required String userId,
  }) async {
    final cleanQuery = _sanitizeTextForPrivacy(query);
    if (cleanQuery.isEmpty) {
      return 'Please type your academic question.';
    }

    await _firestore.collection('ai_study_logs').add({
      'userId': userId,
      'subject': subject,
      'queryLength': cleanQuery.length,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (cleanQuery.toLowerCase().contains('homework') ||
        cleanQuery.toLowerCase().contains('assignment')) {
      return assistWithHomework(
        homeworkPrompt: cleanQuery,
        subject: subject,
        userId: userId,
      );
    }

    return explainDifficultQuestion(
      question: cleanQuery,
      subject: subject,
      userId: userId,
    );
  }

  Future<List<Map<String, dynamic>>> generateQuizFromMaterial({
    required String topicOrNotes,
    int questionCount = 3,
    required String userId,
  }) async {
    final cleanText = _sanitizeTextForPrivacy(topicOrNotes);
    if (cleanText.isEmpty) return const [];

    final List<String> lines = cleanText
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.length > 10)
        .toList();

    final String topicTitle = cleanText.length > 45
        ? '${cleanText.substring(0, 45)}...'
        : cleanText;

    final int count = questionCount.clamp(1, 5);
    final List<Map<String, dynamic>> generatedQuizzes = [];

    for (int i = 0; i < count; i++) {
      final String focusLine =
          lines.isNotEmpty ? lines[i % lines.length] : topicTitle;

      generatedQuizzes.add({
        'question': i == 0
            ? 'Which of the following best describes the core concept of: "$topicTitle"?'
            : 'Based on the study material ("$focusLine"), which statement is accurate?',
        'options': [
          'It directly follows the primary rule explained in the lesson notes',
          'It is unrelated to the current syllabus topic',
          'It applies only when all variables are zero',
          'None of the above statements are valid',
        ],
        'correctIndex': 0,
        'explanation':
            'Option 1 aligns directly with the provided study material: $focusLine',
      });
    }

    return generatedQuizzes;
  }

  Future<void> publishGeneratedQuizToGroup({
    required String groupId,
    required String teacherId,
    required Map<String, dynamic> quizItem,
  }) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists || groupDoc.data() == null) {
      throw Exception('Group not found.');
    }

    final group = GroupModel.fromMap(groupDoc.data()!, groupDoc.id);
    if (!group.isSingleAdmin(teacherId)) {
      throw Exception('Only the group teacher can publish quizzes to the group.');
    }

    final String question = (quizItem['question'] ?? 'Class Quiz').toString();
    final List<String> options =
        ((quizItem['options'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList();
    final int correctIndex =
        (quizItem['correctIndex'] as num?)?.toInt() ?? 0;
    final String explanation = (quizItem['explanation'] ?? '').toString();

    await _chatService.sendGroupMessage(
      groupId: groupId,
      senderId: teacherId,
      message: question,
      type: 'quiz',
      messageCategory: 'quiz',
      quizData: {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'submissions': <String, int>{},
      },
      clientMessageId:
          '${teacherId}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
