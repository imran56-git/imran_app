import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../services/media_service.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/message_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupName;
  final String groupId;
  final String currentUserId;
  final String currentUserName;

  const GroupChatScreen({
    super.key,
    required this.groupName,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ChatService _chatService = ChatService();
  final GroupService _groupService = GroupService();
  final MediaService _mediaService = MediaService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<GroupModel?>? _groupSubscription;
  GroupModel? _currentGroup;

  String? _replyToMessageId;
  String? _replyToText;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showScrollToBottomBtn = false;
  bool _exitDialogShown = false;
  int _initialUnreadCount = 0;
  bool _capturedInitialUnread = false;

  final String _backgroundImage = 'assets/images/chat_bg.png';

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'All', 'icon': Icons.all_inbox_rounded},
    {
      'key': 'announcement',
      'label': 'Announcements',
      'icon': Icons.campaign_rounded
    },
    {'key': 'homework', 'label': 'Homework', 'icon': Icons.menu_book_rounded},
    {
      'key': 'assignment',
      'label': 'Assignments',
      'icon': Icons.assignment_rounded
    },
    {
      'key': 'study_material',
      'label': 'Study Material',
      'icon': Icons.library_books_rounded
    },
    {'key': 'doubt', 'label': 'Doubts', 'icon': Icons.help_outline_rounded},
    {'key': 'poll', 'label': 'Polls', 'icon': Icons.poll_rounded},
    {'key': 'quiz', 'label': 'Quizzes', 'icon': Icons.quiz_rounded},
    {
      'key': 'exam_notice',
      'label': 'Exam Notices',
      'icon': Icons.event_note_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    _listenToGroupRealtimeState();
    _chatService.markGroupMessagesAsSeen(widget.groupId, widget.currentUserId);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final bool shouldShow = _scrollController.offset > 280;
    if (shouldShow != _showScrollToBottomBtn && mounted) {
      setState(() => _showScrollToBottomBtn = shouldShow);
    }
  }

  void _listenToGroupRealtimeState() {
    _groupSubscription =
        _groupService.getGroupStream(widget.groupId).listen((group) {
      if (!mounted) return;

      if (group == null) {
        _triggerForcedExitDialog(isDismissal: true, teacherName: 'Teacher');
        return;
      }

      if (!_capturedInitialUnread) {
        _initialUnreadCount = group.getUnreadCountForUser(widget.currentUserId);
        _capturedInitialUnread = true;
      }

      final bool wasMuted =
          _currentGroup?.isStudentMuted(widget.currentUserId) ?? false;
      final bool isNowMuted = group.isStudentMuted(widget.currentUserId);
      if (!wasMuted && isNowMuted) {
        FocusScope.of(context).unfocus();
      }

      setState(() {
        _currentGroup = group;
      });

      final bool isTeacher = group.isSingleAdmin(widget.currentUserId);
      if (!isTeacher) {
        if (group.isDismissed ||
            group.unacknowledgedDismissMembers.contains(widget.currentUserId)) {
          _triggerForcedExitDialog(
            isDismissal: true,
            teacherName:
                group.teacherName.isNotEmpty ? group.teacherName : 'Teacher',
          );
          return;
        }

        if (group.isStudentRemoved(widget.currentUserId) ||
            group.pendingRemovalNotices.contains(widget.currentUserId) ||
            !group.members.contains(widget.currentUserId)) {
          _triggerForcedExitDialog(
            isDismissal: false,
            teacherName:
                group.teacherName.isNotEmpty ? group.teacherName : 'Teacher',
          );
          return;
        }
      }
    });
  }

  Future<void> _triggerForcedExitDialog({
    required bool isDismissal,
    required String teacherName,
  }) async {
    if (_exitDialogShown || !mounted) return;
    _exitDialogShown = true;
    FocusScope.of(context).unfocus();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDismissal
                      ? Icons.cancel_outlined
                      : Icons.person_remove_alt_1_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentGroup?.name ?? widget.groupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isDismissal
                ? "This group has been dismissed by the teacher."
                : "You have been removed from this group by the teacher.",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  try {
                    if (isDismissal) {
                      await _groupService.acknowledgeGroupDismissal(
                        groupId: widget.groupId,
                        studentId: widget.currentUserId,
                      );
                    } else {
                      await _groupService.acknowledgeStudentRemoval(
                        groupId: widget.groupId,
                        studentId: widget.currentUserId,
                      );
                    }
                  } catch (_) {}
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  isDismissal ? "Continue" : "OK",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ImageProvider? _buildBackgroundProvider() {
    try {
      if (_backgroundImage.startsWith('assets/')) {
        return AssetImage(_backgroundImage);
      }
      return FileImage(File(_backgroundImage));
    } catch (_) {
      return null;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _isViewerTeacher {
    return _currentGroup?.isSingleAdmin(widget.currentUserId) ?? false;
  }

  bool get _isStudentMuted {
    if (_isViewerTeacher) return false;
    return _currentGroup?.isStudentMuted(widget.currentUserId) ?? false;
  }

  bool get _isPostingRestrictedToAdmin {
    if (_isViewerTeacher) return false;
    return _currentGroup?.onlyAdminCanPost ?? false;
  }

  String _formatDateHeader(DateTime? date) {
    if (date == null) return 'Recent';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  bool _isSameCalendarDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showStudentModerationDialog({
    required String studentId,
    required String studentName,
  }) {
    if (!_isViewerTeacher || studentId == widget.currentUserId) return;
    final bool isMuted = _currentGroup?.isStudentMuted(studentId) ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      studentName.isNotEmpty
                          ? studentName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "UID: $studentId",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: isMuted ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    isMuted
                        ? "Unmute Student (Allow sending messages)"
                        : "Mute Student Temporarily",
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await _groupService.setStudentMuteStatus(
                        groupId: widget.groupId,
                        teacherId: widget.currentUserId,
                        studentId: studentId,
                        mute: !isMuted,
                      );
                      _showSnackBar(
                        isMuted
                            ? "$studentName has been unmuted."
                            : "$studentName has been muted.",
                      );
                    } catch (e) {
                      _showSnackBar("Action failed: $e");
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_alt_1_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Remove Student from Group",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmRemoveStudent(studentId, studentName);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveStudent(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Remove Student?"),
          content: Text(
            "Are you sure you want to remove $studentName from this group? They will be notified and will no longer have access.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _groupService.removeStudentFromGroup(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                    studentId: studentId,
                  );
                  _showSnackBar("$studentName removed from group.");
                } catch (e) {
                  _showSnackBar("Error: $e");
                }
              },
              child:
                  const Text("Remove", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDismissGroup() {
    if (!_isViewerTeacher) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Dismiss Group Permanently?"),
            ],
          ),
          content: const Text(
            "Once dismissed, this group will be permanently closed. Every student in this group will receive a real-time dismissal popup and no further messages can be sent.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _groupService.dismissGroup(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar("Group has been permanently dismissed.");
                  }
                } catch (e) {
                  _showSnackBar("Failed to dismiss group: $e");
                }
              },
              child: const Text(
                "Dismiss Group",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAcademicComposerSheet() {
    final TextEditingController textCtrl = TextEditingController();
    String selectedCat = _isViewerTeacher ? 'announcement' : 'doubt';
    bool isScheduled = false;
    DateTime? scheduledDateTime;

    final List<Map<String, String>> availableCategories = _isViewerTeacher
        ? [
            {'key': 'announcement', 'label': 'Announcement'},
            {'key': 'homework', 'label': 'Homework'},
            {'key': 'assignment', 'label': 'Assignment'},
            {'key': 'study_material', 'label': 'Study Material'},
            {'key': 'exam_notice', 'label': 'Exam Notification'},
            {'key': 'class_update', 'label': 'Class Update'},
          ]
        : [
            {'key': 'doubt', 'label': 'Academic Doubt / Question'},
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isViewerTeacher
                              ? "Academic & Batch Tools"
                              : "Ask an Academic Doubt",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_isViewerTeacher)
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openPollCreatorDialog();
                                },
                                icon: const Icon(Icons.poll_outlined, size: 18),
                                label: const Text("Create Poll"),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openQuizCreatorDialog();
                                },
                                icon: const Icon(Icons.quiz_outlined, size: 18),
                                label: const Text("Create Quiz"),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: availableCategories.map((cat) {
                        final bool isSel = selectedCat == cat['key'];
                        return ChoiceChip(
                          label: Text(cat['label']!),
                          selected: isSel,
                          selectedColor: Colors.blueAccent.withOpacity(0.18),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.blueAccent : Colors.black87,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) {
                            setSheetState(() => selectedCat = cat['key']!);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isViewerTeacher
                            ? "Write your notice, homework instructions or study update..."
                            : "Write your academic question clearly for the teacher...",
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_isViewerTeacher) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Switch(
                            value: isScheduled,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) async {
                              if (val) {
                                final now = DateTime.now();
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      now.add(const Duration(minutes: 15)),
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 60)),
                                );
                                if (pickedDate != null && context.mounted) {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                        now.add(const Duration(minutes: 15))),
                                  );
                                  if (pickedTime != null) {
                                    setSheetState(() {
                                      isScheduled = true;
                                      scheduledDateTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    });
                                  }
                                }
                              } else {
                                setSheetState(() {
                                  isScheduled = false;
                                  scheduledDateTime = null;
                                });
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              isScheduled && scheduledDateTime != null
                                  ? "Scheduled: ${DateFormat('dd MMM, hh:mm a').format(scheduledDateTime!)}"
                                  : "Schedule Message for Later",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final text = textCtrl.text.trim();
                          if (text.isEmpty) return;
                          Navigator.pop(ctx);
                          try {
                            await _chatService.sendGroupMessage(
                              groupId: widget.groupId,
                              senderId: widget.currentUserId,
                              message: text,
                              type: 'text',
                              messageCategory: selectedCat,
                              isScheduled: isScheduled,
                              scheduledAt: scheduledDateTime,
                            );
                          } catch (e) {
                            _showSnackBar("Failed: $e");
                          }
                        },
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          isScheduled ? "Schedule Post" : "Publish to Group",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openPollCreatorDialog() {
    final TextEditingController questionCtrl = TextEditingController();
    final List<TextEditingController> optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text(
                "Create Class Poll",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionCtrl,
                      decoration: const InputDecoration(
                        labelText: "Poll Question",
                        hintText: "Ask a question...",
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(optionCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: optionCtrls[i],
                          decoration: InputDecoration(
                            labelText: "Option ${i + 1}",
                            isDense: true,
                          ),
                        ),
                      );
                    }),
                    if (optionCtrls.length < 5)
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            optionCtrls.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Add Option"),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    final q = questionCtrl.text.trim();
                    final opts = optionCtrls
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    if (q.isEmpty || opts.length < 2) {
                      _showSnackBar("Enter a question and at least 2 options.");
                      return;
                    }
                    Navigator.pop(ctx);
                    await _chatService.sendGroupMessage(
                      groupId: widget.groupId,
                      senderId: widget.currentUserId,
                      message: q,
                      type: 'poll',
                      messageCategory: 'poll',
                      pollData: {
                        'question': q,
                        'options': opts,
                        'votes': <String, int>{},
                      },
                    );
                  },
                  child: const Text("Post Poll",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openQuizCreatorDialog() {
    final TextEditingController questionCtrl = TextEditingController();
    final List<TextEditingController> optionCtrls = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    int correctIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text(
                "Create MCQ Quiz",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionCtrl,
                      decoration: const InputDecoration(
                        labelText: "Quiz Question",
                        hintText: "Enter MCQ question...",
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(optionCtrls.length, (i) {
                      return Row(
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: correctIndex,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => correctIndex = val);
                              }
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: optionCtrls[i],
                              decoration: InputDecoration(
                                labelText:
                                    "Option ${i + 1}${correctIndex == i ? ' (Correct)' : ''}",
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    final q = questionCtrl.text.trim();
                    final opts = optionCtrls
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    if (q.isEmpty || opts.length < 2) {
                      _showSnackBar("Enter a question and options.");
                      return;
                    }
                    Navigator.pop(ctx);
                    await _chatService.sendGroupMessage(
                      groupId: widget.groupId,
                      senderId: widget.currentUserId,
                      message: q,
                      type: 'quiz',
                      messageCategory: 'quiz',
                      quizData: {
                        'question': q,
                        'options': opts,
                        'correctIndex':
                            correctIndex.clamp(0, opts.length - 1),
                        'submissions': <String, int>{},
                      },
                    );
                  },
                  child: const Text("Post Quiz",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openGroupDetailsAndAdminSheet() {
    final group = _currentGroup;
    if (group == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (context, scrollCtrl) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _groupService.getGroupMembersWithPrivacy(
                groupId: widget.groupId,
                viewerId: widget.currentUserId,
              ),
              builder: (context, snapshot) {
                final memberData = snapshot.data;
                final List<Map<String, dynamic>> students =
                    (memberData?['students'] as List<Map<String, dynamic>>?) ??
                        const [];

                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: group.imageUrl.isNotEmpty
                              ? NetworkImage(group.imageUrl)
                              : null,
                          child: group.imageUrl.isEmpty
                              ? const Icon(Icons.groups_rounded,
                                  color: Colors.blueAccent, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (group.isTeacherVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified,
                                        color: Colors.blueAccent, size: 17),
                                  ],
                                  if (group.hasGoldenBadge) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.workspace_premium,
                                        color: Colors.amber, size: 18),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Created by ${group.teacherName.isNotEmpty ? group.teacherName : 'Teacher'} • ${group.studentCount} Students",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (group.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        group.description,
                        style: const TextStyle(
                            fontSize: 13.5, color: Colors.black87),
                      ),
                    ],
                    if (group.groupRules.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Group Rules",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.groupRules,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    if (_isViewerTeacher) ...[
                      const Text(
                        "Single Admin Controls (Teacher Only)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          "Admin-Only Announcement Mode",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          "When enabled, only you (Teacher) can send messages.",
                          style: TextStyle(fontSize: 12),
                        ),
                        value: group.onlyAdminCanPost,
                        activeColor: Colors.blueAccent,
                        onChanged: (val) async {
                          await _groupService.setAdminOnlyPostingMode(
                            groupId: widget.groupId,
                            teacherId: widget.currentUserId,
                            onlyAdminCanPost: val,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                      const Divider(),
                      Text(
                        "Connected Students in Group (${students.length})",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...students.map((s) {
                        final String sId = (s['uid'] ?? '').toString();
                        final String sName =
                            (s['name'] ?? 'Student').toString();
                        final bool isMuted = s['isMuted'] == true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Text(
                              sName.isNotEmpty ? sName[0].toUpperCase() : 'S',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            sName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            isMuted ? "Status: Muted by you" : "UID: $sId",
                            style: TextStyle(
                              fontSize: 12,
                              color: isMuted ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: isMuted ? "Unmute" : "Mute",
                                icon: Icon(
                                  isMuted
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_none_rounded,
                                  color: isMuted ? Colors.red : Colors.blueGrey,
                                ),
                                onPressed: () async {
                                  await _groupService.setStudentMuteStatus(
                                    groupId: widget.groupId,
                                    teacherId: widget.currentUserId,
                                    studentId: sId,
                                    mute: !isMuted,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                              IconButton(
                                tooltip: "Remove Student",
                                icon: const Icon(
                                  Icons.person_remove_alt_1_outlined,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _confirmRemoveStudent(sId, sName);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDismissGroup();
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text(
                          "Dismiss Group Permanently",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Colors.blueAccent),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Student Identity Privacy Active: Your personal name, phone number and UID are hidden from other students in this group.",
                                style: TextStyle(
                                    fontSize: 12.5, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilterBar() {
    return Container(
      height: 44,
      color: const Color(0xFF0F172A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final bool isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() => _selectedCategory = cat['key'] as String);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blueAccent
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinnedMessageBanner(List<MessageModel> messages) {
    final pinnedList = messages.where((m) => m.isPinned).toList();
    if (pinnedList.isEmpty) return const SizedBox.shrink();
    final latestPinned = pinnedList.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.amber.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Pinned Announcement",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
                Text(
                  latestPinned.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
              ],
            ),
          ),
          if (_isViewerTeacher)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.brown),
              onPressed: () {
                _groupService.togglePinMessage(
                  groupId: widget.groupId,
                  teacherId: widget.currentUserId,
                  messageId: latestPinned.messageId,
                  pin: false,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInteractivePollOrQuizCard(MessageModel message, bool isMe) {
    if (message.type == 'poll' && message.pollData != null) {
      final poll = message.pollData!;
      final String question = (poll['question'] ?? message.content).toString();
      final List<dynamic> options =
          (poll['options'] as List<dynamic>?) ?? const [];
      final Map<String, dynamic> votes = poll['votes'] is Map
          ? Map<String, dynamic>.from(poll['votes'] as Map)
          : {};
      final int totalVotes = votes.length;
      final int? myVote = votes[widget.currentUserId] is int
          ? votes[widget.currentUserId] as int
          : int.tryParse(votes[widget.currentUserId]?.toString() ?? '');

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100),
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
            const Row(
              children: [
                Icon(Icons.poll_rounded, color: Colors.blueAccent, size: 18),
                SizedBox(width: 6),
                Text(
                  "CLASS POLL",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(options.length, (i) {
              final int count =
                  votes.values.where((v) => v.toString() == '$i').length;
              final double ratio = totalVotes > 0 ? count / totalVotes : 0.0;
              final bool isSelected = myVote == i;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isStudentMuted
                      ? null
                      : () {
                          _groupService.voteOnPoll(
                            groupId: widget.groupId,
                            messageId: message.messageId,
                            userId: widget.currentUserId,
                            optionIndex: i,
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade50
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blueAccent
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                options[i].toString(),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Text(
                              "$count (${(ratio * 100).toStringAsFixed(0)}%)",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey.shade200,
                          color: Colors.blueAccent,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            Text(
              "$totalVotes total vote${totalVotes == 1 ? '' : 's'}",
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (message.type == 'quiz' && message.quizData != null) {
      final quiz = message.quizData!;
      final String question = (quiz['question'] ?? message.content).toString();
      final List<dynamic> options =
          (quiz['options'] as List<dynamic>?) ?? const [];
      final int correctIndex = (quiz['correctIndex'] as num?)?.toInt() ?? 0;
      final Map<String, dynamic> submissions = quiz['submissions'] is Map
          ? Map<String, dynamic>.from(quiz['submissions'] as Map)
          : {};
      final int? myAnswer = submissions[widget.currentUserId] is int
          ? submissions[widget.currentUserId] as int
          : int.tryParse(submissions[widget.currentUserId]?.toString() ?? '');

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade100),
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
            const Row(
              children: [
                Icon(Icons.quiz_rounded, color: Colors.purple, size: 18),
                SizedBox(width: 6),
                Text(
                  "CLASS MCQ QUIZ",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(options.length, (i) {
              final bool hasAnswered = myAnswer != null || _isViewerTeacher;
              final bool isCorrectOption = i == correctIndex;
              final bool isMySelected = myAnswer == i;

              Color borderColor = Colors.grey.shade300;
              Color bgColor = const Color(0xFFF8FAFC);
              if (hasAnswered) {
                if (isCorrectOption) {
                  borderColor = Colors.green;
                  bgColor = Colors.green.shade50;
                } else if (isMySelected && !isCorrectOption) {
                  borderColor = Colors.redAccent;
                  bgColor = Colors.red.shade50;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: (myAnswer != null || _isStudentMuted)
                      ? null
                      : () {
                          _groupService.submitQuizAnswer(
                            groupId: widget.groupId,
                            messageId: message.messageId,
                            userId: widget.currentUserId,
                            selectedOptionIndex: i,
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            options[i].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (hasAnswered && isCorrectOption)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                        if (hasAnswered && isMySelected && !isCorrectOption)
                          const Icon(Icons.cancel,
                              color: Colors.redAccent, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }),
            Text(
              "${submissions.length} student response${submissions.length == 1 ? '' : 's'}",
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPrivacySafeMessageHeader(MessageModel message, bool isMe) {
    final String visibleName = message.getVisibleSenderName(
      currentUserId: widget.currentUserId,
      isViewerTeacherOfGroup: _isViewerTeacher,
    );
    final bool isTeacherMsg = message.senderRole == 'teacher' ||
        message.senderId == _currentGroup?.createdBy;
    final String category = message.messageCategory;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 12,
        right: isMe ? 12 : 0,
        top: 4,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            GestureDetector(
              onTap: () {
                if (_isViewerTeacher && !isTeacherMsg) {
                  _showStudentModerationDialog(
                    studentId: message.senderId,
                    studentName: visibleName,
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    visibleName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isTeacherMsg
                          ? Colors.blueAccent
                          : Colors.blueGrey.shade700,
                    ),
                  ),
                  if (isTeacherMsg &&
                      (message.isSenderVerified ||
                          (_currentGroup?.isTeacherVerified ?? false))) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.verified,
                        color: Colors.blueAccent, size: 13),
                  ],
                  if (isTeacherMsg &&
                      (message.hasSenderGoldenBadge ||
                          (_currentGroup?.hasGoldenBadge ?? false))) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.workspace_premium,
                        color: Colors.amber, size: 14),
                  ],
                  if (_isViewerTeacher && !isTeacherMsg) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.admin_panel_settings_outlined,
                        size: 12, color: Colors.grey),
                  ],
                ],
              ),
            ),
          if (category.isNotEmpty && category != 'general') ...[
            if (!isMe) const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomComposerOrRestrictionBar() {
    if (_currentGroup != null && _currentGroup!.isDismissed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.red.shade50,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Text(
              "This group has been dismissed by the teacher.",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_isStudentMuted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: true,
                  child: TextField(
                    enabled: false,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "Muted by teacher",
                      hintStyle: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.mic_off_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.red.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPostingRestrictedToAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: const SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined, color: Colors.blueGrey, size: 19),
              SizedBox(width: 8),
              Text(
                "Only the teacher can send messages in this group",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openAcademicComposerSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.school_rounded,
                          size: 15,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isViewerTeacher
                              ? "Post Homework / Poll / Quiz / Notice"
                              : "Ask Academic Doubt",
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ChatInputBar(
            chatRoomId: widget.groupId,
            senderId: widget.currentUserId,
            receiverId: 'group',
            replyToMessageId: _replyToMessageId,
            replyToText: _replyToText,
            onCancelReply: () {
              setState(() {
                _replyToMessageId = null;
                _replyToText = null;
              });
            },
            onTypingChanged: (isTyping) {
              _chatService.updateTypingStatus(
                widget.groupId,
                widget.currentUserId,
                isTyping,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgProvider = _buildBackgroundProvider();
    final group = _currentGroup;
    final String displayGroupName = group?.name.isNotEmpty == true
        ? group!.name
        : widget.groupName;
    final int studentCount = group?.studentCount ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: "Search messages in group...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              )
            : InkWell(
                onTap: _openGroupDetailsAndAdminSheet,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFF1E293B),
                        backgroundImage:
                            (group != null && group.imageUrl.isNotEmpty)
                                ? NetworkImage(group.imageUrl)
                                : null,
                        child: (group == null || group.imageUrl.isEmpty)
                            ? const Icon(Icons.groups_rounded,
                                color: Colors.blueAccent, size: 22)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayGroupName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (group?.isTeacherVerified == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified,
                                    color: Colors.blueAccent, size: 15),
                              ],
                              if (group?.hasGoldenBadge == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.workspace_premium,
                                    color: Colors.amber, size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$studentCount Students • Tap for Group Info',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.72),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
              size: 21,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 21),
            tooltip: "Group Info & Admin Controls",
            onPressed: _openGroupDetailsAndAdminSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: Colors.white, size: 20),
            onSelected: (value) async {
              if (value == 'info') {
                _openGroupDetailsAndAdminSheet();
              } else if (value == 'academic') {
                _openAcademicComposerSheet();
              } else if (value == 'export') {
                final transcript = await _chatService.exportChatTranscript(
                  chatOrGroupId: widget.groupId,
                  isGroup: true,
                  currentUserId: widget.currentUserId,
                  isViewerTeacherOfGroup: _isViewerTeacher,
                );
                if (transcript.isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: transcript));
                  _showSnackBar("Chat transcript copied to clipboard!");
                }
              } else if (value == 'dismiss') {
                _confirmDismissGroup();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Text('Group Information'),
              ),
              PopupMenuItem(
                value: 'academic',
                child: Text(_isViewerTeacher
                    ? 'Academic Tools (Homework/Poll/Quiz)'
                    : 'Ask a Doubt'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Export Chat Copy'),
              ),
              if (_isViewerTeacher)
                const PopupMenuItem(
                  value: 'dismiss',
                  child: Text(
                    'Dismiss Group Permanently',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          image: bgProvider != null
              ? DecorationImage(
                  image: bgProvider,
                  fit: BoxFit.cover,
                  opacity: 0.03,
                  onError: (_, __) {},
                )
              : null,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildCategoryFilterBar(),
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: _chatService.getGroupMessagesStream(
                      widget.groupId,
                      categoryFilter: _selectedCategory,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Failed to load group messages.',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w500),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent),
                        );
                      }

                      final rawMessages = snapshot.data ?? const [];
                      final messages = _searchQuery.isEmpty
                          ? rawMessages
                          : rawMessages
                              .where((m) => m.content
                                  .toLowerCase()
                                  .contains(_searchQuery))
                              .toList();

                      if (messages.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(
                              _selectedCategory == 'all'
                                  ? 'Welcome to FYBTT Secure Group Chat'
                                  : 'No messages in this category yet',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          _buildPinnedMessageBanner(rawMessages),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final bool isMe =
                                    message.senderId == widget.currentUserId;

                                final bool showDateHeader =
                                    index == messages.length - 1 ||
                                        !_isSameCalendarDay(
                                          message.timestamp,
                                          messages[index + 1].timestamp,
                                        );

                                final bool showUnreadBanner =
                                    _initialUnreadCount > 0 &&
                                        index == _initialUnreadCount - 1;

                                return Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (showDateHeader)
                                      Center(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.blueGrey.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _formatDateHeader(
                                                message.timestamp),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (showUnreadBanner)
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "$_initialUnreadCount Unread Messages",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                    _buildPrivacySafeMessageHeader(
                                        message, isMe),
                                    if (message.type == 'poll' ||
                                        message.type == 'quiz')
                                      _buildInteractivePollOrQuizCard(
                                          message, isMe)
                                    else
                                      MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                        chatRoomId: widget.groupId,
                                        currentUserId: widget.currentUserId,
                                        onReplyPressed: (repliedMsg) {
                                          setState(() {
                                            _replyToMessageId =
                                                repliedMsg.messageId;
                                            _replyToText =
                                                repliedMsg.type == 'text'
                                                    ? repliedMsg.content
                                                    : 'Attachment';
                                          });
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _buildBottomComposerOrRestrictionBar(),
              ],
            ),
            if (_showScrollToBottomBtn)
              Positioned(
                right: 16,
                bottom: 86,
                child: FloatingActionButton.small(
                  backgroundColor: const Color(0xFF0F172A),
                  onPressed: _scrollToBottom,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
