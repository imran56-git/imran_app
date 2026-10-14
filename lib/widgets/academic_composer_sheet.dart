import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';

class AcademicComposerSheet extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final bool isTeacher;
  final String initialCategory;

  const AcademicComposerSheet({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.isTeacher,
    this.initialCategory = 'announcement',
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String currentUserId,
    required bool isTeacher,
    String initialCategory = 'announcement',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AcademicComposerSheet(
        groupId: groupId,
        currentUserId: currentUserId,
        isTeacher: isTeacher,
        initialCategory: initialCategory,
      ),
    );
  }

  @override
  State<AcademicComposerSheet> createState() => _AcademicComposerSheetState();
}

class _AcademicComposerSheetState extends State<AcademicComposerSheet>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();

  late TabController _tabController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  final TextEditingController _quizQuestionController = TextEditingController();
  final List<TextEditingController> _quizOptionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final TextEditingController _quizExplanationController =
      TextEditingController();
  int _correctQuizOptionIndex = 0;

  String _selectedCategory = 'announcement';
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;

  File? _attachedFile;
  String? _attachedFileName;
  String? _attachedFileType;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _teacherCategories = [
    {
      'key': 'announcement',
      'label': 'Announcement',
      'icon': Icons.campaign_rounded,
      'color': Colors.blueAccent,
    },
    {
      'key': 'homework',
      'label': 'Homework',
      'icon': Icons.menu_book_rounded,
      'color': Colors.indigo,
    },
    {
      'key': 'assignment',
      'label': 'Assignment',
      'icon': Icons.assignment_rounded,
      'color': Colors.deepPurple,
    },
    {
      'key': 'study_material',
      'label': 'Study Material',
      'icon': Icons.library_books_rounded,
      'color': Colors.teal,
    },
    {
      'key': 'exam_notice',
      'label': 'Exam Notice',
      'icon': Icons.event_note_rounded,
      'color': Colors.redAccent,
    },
    {
      'key': 'class_update',
      'label': 'Class Update',
      'icon': Icons.schedule_rounded,
      'color': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isTeacher ? 3 : 1,
      vsync: this,
    );
    _selectedCategory =
        widget.isTeacher ? widget.initialCategory : 'doubt';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _dueDateController.dispose();
    _pollQuestionController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    _quizQuestionController.dispose();
    for (final c in _quizOptionControllers) {
      c.dispose();
    }
    _quizExplanationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickImageAttachment(ImageSource source) async {
    try {
      final XFile? picked =
          await _imagePicker.pickImage(source: source, imageQuality: 82);
      if (picked != null && mounted) {
        setState(() {
          _attachedFile = File(picked.path);
          _attachedFileName = picked.name;
          _attachedFileType = 'image';
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickDocumentAttachment() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
          'zip',
        ],
      );
      if (result != null &&
          result.files.single.path != null &&
          mounted) {
        setState(() {
          _attachedFile = File(result.files.single.path!);
          _attachedFileName = result.files.single.name;
          _attachedFileType = 'document';
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick document: $e');
    }
  }

  Future<void> _selectScheduleDateTime() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(minutes: 15)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15))),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _isScheduled = true;
      _scheduledDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _dueDateController.text = DateFormat('dd MMM yyyy').format(pickedDate);
      });
    }
  }

  Future<void> _submitAcademicPost() async {
    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    final String dueDate = _dueDateController.text.trim();

    if (body.isEmpty && _attachedFile == null) {
      _showSnackBar('Please enter details or attach a file.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final StringBuffer formattedContent = StringBuffer();
      if (title.isNotEmpty) {
        formattedContent.writeln('📌 $title');
      }
      if (dueDate.isNotEmpty &&
          (_selectedCategory == 'homework' ||
              _selectedCategory == 'assignment' ||
              _selectedCategory == 'exam_notice')) {
        formattedContent.writeln('📅 Due / Date: $dueDate');
      }
      if (body.isNotEmpty) {
        if (formattedContent.isNotEmpty) formattedContent.writeln();
        formattedContent.write(body);
      }

      final String finalMessageText = formattedContent.toString().trim();

      if (_attachedFile != null) {
        if (_attachedFileType == 'image') {
          await _chatService.sendImageFile(
            chatRoomId: widget.groupId,
            senderId: widget.currentUserId,
            receiverId: 'group',
            file: _attachedFile!,
            messageCategory: _selectedCategory,
          );
        } else if (_attachedFileType == 'document') {
          await _chatService.sendDocumentFile(
            chatRoomId: widget.groupId,
            senderId: widget.currentUserId,
            receiverId: 'group',
            file: _attachedFile!,
            fileName: _attachedFileName ?? 'Academic_Document.pdf',
            messageCategory: _selectedCategory,
          );
        }
      }

      if (finalMessageText.isNotEmpty) {
        await _chatService.sendGroupMessage(
          groupId: widget.groupId,
          senderId: widget.currentUserId,
          message: finalMessageText,
          type: 'text',
          messageCategory: _selectedCategory,
          isScheduled: widget.isTeacher ? _isScheduled : false,
          scheduledAt: widget.isTeacher ? _scheduledDateTime : null,
          clientMessageId:
              '${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to publish: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitPoll() async {
    final String question = _pollQuestionController.text.trim();
    final List<String> options = _pollOptionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      _showSnackBar('Please enter a poll question and at least 2 options.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _chatService.sendGroupMessage(
        groupId: widget.groupId,
        senderId: widget.currentUserId,
        message: question,
        type: 'poll',
        messageCategory: 'poll',
        pollData: {
          'question': question,
          'options': options,
          'votes': <String, int>{},
        },
        clientMessageId:
            '${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to create poll: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitQuiz() async {
    final String question = _quizQuestionController.text.trim();
    final List<String> options = _quizOptionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final String explanation = _quizExplanationController.text.trim();

    if (question.isEmpty || options.length < 2) {
      _showSnackBar('Please enter a quiz question and at least 2 options.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _chatService.sendGroupMessage(
        groupId: widget.groupId,
        senderId: widget.currentUserId,
        message: question,
        type: 'quiz',
        messageCategory: 'quiz',
        quizData: {
          'question': question,
          'options': options,
          'correctIndex': _correctQuizOptionIndex.clamp(0, options.length - 1),
          'explanation': explanation,
          'submissions': <String, int>{},
        },
        clientMessageId:
            '${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to create quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildAcademicPostTab() {
    final bool showDateField = _selectedCategory == 'homework' ||
        _selectedCategory == 'assignment' ||
        _selectedCategory == 'exam_notice';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isTeacher) ...[
            const Text(
              'Select Academic Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _teacherCategories.map((cat) {
                final String key = cat['key'] as String;
                final bool isSelected = _selectedCategory == key;
                final Color color = cat['color'] as Color;

                return ChoiceChip(
                  avatar: Icon(
                    cat['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : color,
                  ),
                  label: Text(cat['label'] as String),
                  selected: isSelected,
                  selectedColor: color,
                  backgroundColor: color.withOpacity(0.08),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategory = key);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.help_outline_rounded, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ask an Academic Doubt: Your question will be tagged under "Doubts". Your personal identity remains hidden from other students.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: widget.isTeacher
                  ? 'Topic / Subject Heading (Optional)'
                  : 'Chapter or Topic Name (Optional)',
              hintText: widget.isTeacher
                  ? 'e.g. Chapter 4: Quadratic Equations'
                  : 'e.g. Doubt in Exercise 4.2 Q3',
              prefixIcon: const Icon(Icons.title_rounded,
                  color: Colors.blueAccent, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          if (showDateField && widget.isTeacher) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _dueDateController,
              readOnly: true,
              onTap: _pickDueDate,
              decoration: InputDecoration(
                labelText: _selectedCategory == 'exam_notice'
                    ? 'Exam Date'
                    : 'Submission Due Date (Optional)',
                hintText: 'Tap to select date...',
                prefixIcon: const Icon(Icons.event_rounded,
                    color: Colors.blueAccent, size: 20),
                suffixIcon: _dueDateController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            setState(() => _dueDateController.clear()),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: widget.isTeacher
                  ? 'Write detailed instructions, announcement, study notes or homework questions...'
                  : 'Describe your academic question clearly...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_attachedFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _attachedFileType == 'image'
                        ? Icons.image_rounded
                        : Icons.picture_as_pdf_rounded,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachedFileName ?? 'Attached File',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _attachedFile = null;
                        _attachedFileName = null;
                        _attachedFileType = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _pickDocumentAttachment,
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Attach PDF / Doc',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _pickImageAttachment(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded,
                      color: Colors.purple, size: 18),
                  label: const Text(
                    'Attach Image',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Camera',
                onPressed: () => _pickImageAttachment(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded,
                    color: Colors.blueAccent),
              ),
            ],
          ),
          if (widget.isTeacher) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Schedule Message for Later',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _isScheduled && _scheduledDateTime != null
                    ? 'Will be sent on ${DateFormat('dd MMM yyyy, hh:mm a').format(_scheduledDateTime!)}'
                    : 'Publish immediately to the batch',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isScheduled,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                if (val) {
                  _selectScheduleDateTime();
                } else {
                  setState(() {
                    _isScheduled = false;
                    _scheduledDateTime = null;
                  });
                }
              },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitAcademicPost,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
              label: Text(
                _isSubmitting
                    ? 'Publishing...'
                    : (_isScheduled
                        ? 'Schedule Academic Post'
                        : (widget.isTeacher
                            ? 'Publish to Batch Group'
                            : 'Submit Academic Doubt')),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollCreatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _pollQuestionController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Poll Question *',
              hintText: 'e.g. Which topic should we revise in tomorrow\'s class?',
              prefixIcon:
                  const Icon(Icons.poll_rounded, color: Colors.blueAccent),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Poll Options (Minimum 2)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_pollOptionControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollOptionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_pollOptionControllers.length > 2)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _pollOptionControllers[index].dispose();
                          _pollOptionControllers.removeAt(index);
                        });
                      },
                    ),
                ],
              ),
            );
          }),
          if (_pollOptionControllers.length < 6)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _pollOptionControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add Another Option'),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitPoll,
              icon: const Icon(Icons.poll_rounded, color: Colors.white),
              label: const Text(
                'Publish Live Poll',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCreatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _quizQuestionController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'MCQ Quiz Question *',
              hintText: 'Enter the multiple-choice question...',
              prefixIcon:
                  const Icon(Icons.quiz_rounded, color: Colors.deepPurple),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Options (Select the radio button for the Correct Answer)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_quizOptionControllers.length, (index) {
            final bool isCorrect = _correctQuizOptionIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: _correctQuizOptionIndex,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _correctQuizOptionIndex = val);
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _quizOptionControllers[index],
                      decoration: InputDecoration(
                        labelText:
                            'Option ${index + 1}${isCorrect ? ' (Correct Answer ✓)' : ''}',
                        isDense: true,
                        filled: true,
                        fillColor: isCorrect
                            ? Colors.green.shade50
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          TextField(
            controller: _quizExplanationController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Solution Explanation / Hint (Optional)',
              hintText: 'Explain why this option is correct...',
              prefixIcon: const Icon(Icons.lightbulb_outline_rounded,
                  color: Colors.amber),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitQuiz,
              icon: const Icon(Icons.quiz_rounded, color: Colors.white),
              label: const Text(
                'Publish MCQ Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                        const Icon(Icons.school_rounded,
                            color: Colors.blueAccent, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          widget.isTeacher
                              ? 'Teacher Academic Studio'
                              : 'Student Doubt Desk',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (widget.isTeacher)
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blueAccent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Academic Post'),
                      Tab(text: 'Live Poll'),
                      Tab(text: 'MCQ Quiz'),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: widget.isTeacher
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAcademicPostTab(),
                      _buildPollCreatorTab(),
                      _buildQuizCreatorTab(),
                    ],
                  )
                : _buildAcademicPostTab(),
          ),
        ],
      ),
    );
  }
}
