import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_study_assistant_service.dart';
import '../../services/chat_service.dart';

class AiStudyAssistantSheet extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;
  final bool isTeacher;
  final String subjectName;
  final int initialTabIndex;

  const AiStudyAssistantSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    required this.isTeacher,
    this.subjectName = '',
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String groupName,
    required String currentUserId,
    required bool isTeacher,
    String subjectName = '',
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiStudyAssistantSheet(
        groupId: groupId,
        groupName: groupName,
        currentUserId: currentUserId,
        isTeacher: isTeacher,
        subjectName: subjectName,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<AiStudyAssistantSheet> createState() => _AiStudyAssistantSheetState();
}

class _AiStudyAssistantSheetState extends State<AiStudyAssistantSheet>
    with SingleTickerProviderStateMixin {
  final AiStudyAssistantService _aiService = AiStudyAssistantService();
  final ChatService _chatService = ChatService();

  late TabController _tabController;

  final TextEditingController _tutorTopicController = TextEditingController();
  final TextEditingController _tutorInputController = TextEditingController();
  final TextEditingController _quizTopicController = TextEditingController();

  bool _hasPrivacyConsent = false;
  bool _isLoadingConsent = true;
  bool _isGeneratingSummary = false;
  bool _isGeneratingTutorResponse = false;
  bool _isGeneratingQuiz = false;

  String _summaryResult = '';
  String _tutorMode = 'explain';
  String _tutorResult = '';
  int _requestedQuizCount = 3;
  List<Map<String, dynamic>> _generatedQuizzes = [];
  final Map<int, int> _practiceSelectedAnswers = {};
  final Set<int> _publishedQuizIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tutorTopicController.text = widget.subjectName;
    _loadConsentState();
  }

  Future<void> _loadConsentState() async {
    final granted =
        await _aiService.hasUserGrantedAiConsent(widget.currentUserId);
    if (mounted) {
      setState(() {
        _hasPrivacyConsent = granted;
        _isLoadingConsent = false;
      });
    }
  }

  Future<void> _togglePrivacyConsent(bool value) async {
    setState(() => _hasPrivacyConsent = value);
    await _aiService.setUserAiConsent(
      userId: widget.currentUserId,
      granted: value,
    );
    if (mounted) {
      _showSnackBar(
        value
            ? 'AI Privacy Consent enabled. Student identities remain masked.'
            : 'AI Privacy Consent disabled for chat message processing.',
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tutorTopicController.dispose();
    _tutorInputController.dispose();
    _quizTopicController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleDiscussionSummary() async {
    if (!_hasPrivacyConsent) {
      _showSnackBar(
          'Please enable the AI Privacy Consent switch above to summarize group messages.');
      return;
    }

    setState(() => _isGeneratingSummary = true);
    try {
      final result = await _aiService.summarizeGroupDiscussion(
        groupId: widget.groupId,
        userId: widget.currentUserId,
      );
      if (mounted) {
        setState(() => _summaryResult = result);
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
      }
    }
  }

  Future<void> _handleImportantNoticesSummary() async {
    if (!_hasPrivacyConsent) {
      _showSnackBar(
          'Please enable the AI Privacy Consent switch above to summarize announcements.');
      return;
    }

    setState(() => _isGeneratingSummary = true);
    try {
      final result = await _aiService.summarizeImportantAnnouncements(
        groupId: widget.groupId,
        userId: widget.currentUserId,
      );
      if (mounted) {
        setState(() => _summaryResult = result);
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
      }
    }
  }

  Future<void> _postSummaryToGroup() async {
    if (!widget.isTeacher || _summaryResult.trim().isEmpty) return;
    try {
      await _chatService.sendGroupMessage(
        groupId: widget.groupId,
        senderId: widget.currentUserId,
        message: _summaryResult.trim(),
        type: 'text',
        messageCategory: 'announcement',
        clientMessageId:
            '${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showSnackBar('AI Summary posted to group announcements!');
    } catch (e) {
      _showSnackBar('Failed to post summary: $e');
    }
  }

  Future<void> _handleGenerateTutorResponse() async {
    final String input = _tutorInputController.text.trim();
    final String topic = _tutorTopicController.text.trim();

    if (input.isEmpty) {
      _showSnackBar('Please enter a question, homework prompt, or study notes.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isGeneratingTutorResponse = true);

    try {
      String output = '';
      if (_tutorMode == 'explain') {
        output = await _aiService.explainDifficultQuestion(
          question: input,
          subject: topic,
          userId: widget.currentUserId,
        );
      } else if (_tutorMode == 'homework') {
        output = await _aiService.assistWithHomework(
          homeworkPrompt: input,
          subject: topic,
          userId: widget.currentUserId,
        );
      } else {
        output = await _aiService.summarizeStudyMaterial(
          title: topic,
          contentOrNotes: input,
          userId: widget.currentUserId,
        );
      }

      if (mounted) {
        setState(() => _tutorResult = output);
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTutorResponse = false);
      }
    }
  }

  Future<void> _handleGenerateQuiz() async {
    final String notes = _quizTopicController.text.trim();
    if (notes.isEmpty) {
      _showSnackBar('Please enter a study topic or paste lesson notes.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isGeneratingQuiz = true;
      _practiceSelectedAnswers.clear();
      _publishedQuizIndices.clear();
    });

    try {
      final quizzes = await _aiService.generateQuizFromMaterial(
        topicOrNotes: notes,
        questionCount: _requestedQuizCount,
        userId: widget.currentUserId,
      );
      if (mounted) {
        setState(() => _generatedQuizzes = quizzes);
      }
    } catch (e) {
      _showSnackBar('Failed to generate quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingQuiz = false);
      }
    }
  }

  Future<void> _publishQuizItemToGroup(int index) async {
    if (!widget.isTeacher || index >= _generatedQuizzes.length) return;
    try {
      await _aiService.publishGeneratedQuizToGroup(
        groupId: widget.groupId,
        teacherId: widget.currentUserId,
        quizItem: _generatedQuizzes[index],
      );
      if (mounted) {
        setState(() => _publishedQuizIndices.add(index));
      }
      _showSnackBar('MCQ Quiz published to ${widget.groupName}!');
    } catch (e) {
      _showSnackBar('Error publishing quiz: $e');
    }
  }

  Widget _buildPrivacyConsentCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _hasPrivacyConsent
            ? Colors.green.shade50
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasPrivacyConsent
              ? Colors.green.shade200
              : Colors.blueGrey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasPrivacyConsent
                ? Icons.verified_user_rounded
                : Icons.privacy_tip_outlined,
            color: _hasPrivacyConsent ? Colors.green.shade700 : Colors.blueGrey,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Privacy & Consent Control',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Allow AI to summarize batch messages. Personal names, phone numbers & emails are strictly masked.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingConsent)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: _hasPrivacyConsent,
              activeColor: Colors.green.shade700,
              onChanged: _togglePrivacyConsent,
            ),
        ],
      ),
    );
  }

  Widget _buildSummariesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Instant Batch Summaries',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quickly catch up on long group discussions or filter out important teacher announcements and pending homework.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      _isGeneratingSummary ? null : _handleDiscussionSummary,
                  icon: const Icon(Icons.forum_outlined,
                      color: Colors.white, size: 18),
                  label: const Text(
                    'Discussion Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isGeneratingSummary
                      ? null
                      : _handleImportantNoticesSummary,
                  icon: const Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 19),
                  label: const Text(
                    'Important Notices',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isGeneratingSummary)
            const Padding(
              padding: EdgeInsets.all(28.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            )
          else if (_summaryResult.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _summaryResult,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                      height: 1.45,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: _summaryResult));
                          _showSnackBar('Summary copied to clipboard!');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Copy'),
                      ),
                      if (widget.isTeacher) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _postSummaryToGroup,
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 16),
                          label: const Text(
                            'Share with Batch',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 46, color: Colors.blueAccent.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap either button above to generate a privacy-safe AI summary of this group.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyTutorTab() {
    final List<Map<String, dynamic>> modes = [
      {
        'key': 'explain',
        'label': 'Question Explanation',
        'icon': Icons.psychology_outlined,
      },
      {
        'key': 'homework',
        'label': 'Homework Assistance',
        'icon': Icons.menu_book_rounded,
      },
      {
        'key': 'material',
        'label': 'Study Material Summary',
        'icon': Icons.summarize_outlined,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.map((m) {
              final bool isSelected = _tutorMode == m['key'];
              return ChoiceChip(
                avatar: Icon(
                  m['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.blueAccent,
                ),
                label: Text(m['label'] as String),
                selected: isSelected,
                selectedColor: Colors.blueAccent,
                backgroundColor: Colors.blue.shade50,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                onSelected: (_) {
                  setState(() {
                    _tutorMode = m['key'] as String;
                    _tutorResult = '';
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tutorTopicController,
            decoration: InputDecoration(
              labelText: 'Subject or Chapter Name',
              hintText: 'e.g. Physics - Laws of Motion',
              prefixIcon: const Icon(Icons.subject_rounded,
                  color: Colors.blueAccent, size: 20),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tutorInputController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _tutorMode == 'explain'
                  ? 'Type the difficult question or concept you want explained simply...'
                  : (_tutorMode == 'homework'
                      ? 'Paste your homework question for step-by-step guidance...'
                      : 'Paste study notes or chapter text to summarize key points...'),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isGeneratingTutorResponse
                  ? null
                  : _handleGenerateTutorResponse,
              icon: _isGeneratingTutorResponse
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
              label: Text(
                _tutorMode == 'explain'
                    ? 'Explain Simply'
                    : (_tutorMode == 'homework'
                        ? 'Get Homework Guide'
                        : 'Summarize Study Material'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_tutorResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _tutorResult,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: _tutorResult));
                        _showSnackBar('Copied to clipboard!');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Response'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizGeneratorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Practice MCQ Quizzes from Notes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quizTopicController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Paste lesson notes, key definitions, or topic summary to generate MCQs...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Number of Questions:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(width: 10),
              ...[1, 2, 3, 5].map((count) {
                final bool isSel = _requestedQuizCount == count;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$count'),
                    selected: isSel,
                    selectedColor: Colors.deepPurple.withOpacity(0.18),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.deepPurple : Colors.black87,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() => _requestedQuizCount = count);
                    },
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isGeneratingQuiz ? null : _handleGenerateQuiz,
              icon: _isGeneratingQuiz
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.quiz_rounded,
                      color: Colors.white, size: 18),
              label: const Text(
                'Generate AI Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_generatedQuizzes.length, (qIdx) {
            final quiz = _generatedQuizzes[qIdx];
            final String question = (quiz['question'] ?? '').toString();
            final List<dynamic> options =
                (quiz['options'] as List<dynamic>?) ?? const [];
            final int correctIdx = (quiz['correctIndex'] as num?)?.toInt() ?? 0;
            final String explanation = (quiz['explanation'] ?? '').toString();
            final int? selectedAns = _practiceSelectedAnswers[qIdx];
            final bool isPublished = _publishedQuizIndices.contains(qIdx);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${qIdx + 1}. $question',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(options.length, (optIdx) {
                    final bool hasSelected = selectedAns != null;
                    final bool isThisCorrect = optIdx == correctIdx;
                    final bool isThisSelected = selectedAns == optIdx;

                    Color bg = const Color(0xFFF8FAFC);
                    Color border = Colors.grey.shade300;
                    if (hasSelected) {
                      if (isThisCorrect) {
                        bg = Colors.green.shade50;
                        border = Colors.green;
                      } else if (isThisSelected) {
                        bg = Colors.red.shade50;
                        border = Colors.redAccent;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _practiceSelectedAnswers[qIdx] = optIdx;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  options[optIdx].toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (hasSelected && isThisCorrect)
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                              if (hasSelected &&
                                  isThisSelected &&
                                  !isThisCorrect)
                                const Icon(Icons.cancel,
                                    color: Colors.redAccent, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (selectedAns != null && explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '💡 $explanation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (widget.isTeacher) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPublished
                              ? Colors.green
                              : const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isPublished
                            ? null
                            : () => _publishQuizItemToGroup(qIdx),
                        icon: Icon(
                          isPublished
                              ? Icons.check_rounded
                              : Icons.publish_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          isPublished
                              ? 'Published to Group'
                              : 'Publish Quiz to Batch',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FYBTT AI Study Assistant',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.5,
                              ),
                            ),
                            Text(
                              widget.groupName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.amber,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  tabs: const [
                    Tab(text: 'Chat Summary'),
                    Tab(text: 'Study Tutor'),
                    Tab(text: 'Quiz Maker'),
                  ],
                ),
              ],
            ),
          ),
          _buildPrivacyConsentCard(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummariesTab(),
                _buildStudyTutorTab(),
                _buildQuizGeneratorTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
