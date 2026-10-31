import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../utils/image_utils.dart';
import '../../widgets/badge_details_sheet.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final String currentUserName;
  final VoidCallback? onOpenMediaDocsLinks;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
    this.onOpenMediaDocsLinks,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _memberSearchController = TextEditingController();

  StreamSubscription<GroupModel?>? _groupSubscription;
  GroupModel? _group;
  List<Map<String, dynamic>> _studentsList = [];
  Map<String, dynamic>? _teacherProfileData;

  bool _isLoadingMembers = true;
  bool _exitDialogShown = false;
  String _memberSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _listenToGroupChanges();
  }

  void _listenToGroupChanges() {
    _groupSubscription =
        _groupService.getGroupStream(widget.groupId).listen((groupData) {
      if (!mounted) return;

      if (groupData == null) {
        _handleForcedStudentExit(isDismissal: true);
        return;
      }

      final bool isTeacher = groupData.isSingleAdmin(widget.currentUserId);
      if (!isTeacher) {
        if (groupData.isDismissed ||
            groupData.unacknowledgedDismissMembers
                .contains(widget.currentUserId)) {
          _handleForcedStudentExit(isDismissal: true);
          return;
        }
        if (groupData.isStudentRemoved(widget.currentUserId) ||
            groupData.pendingRemovalNotices.contains(widget.currentUserId)) {
          _handleForcedStudentExit(isDismissal: false);
          return;
        }
      }

      setState(() {
        _group = groupData;
      });
      _loadMembersWithPrivacy();
    });
  }

  Future<void> _loadMembersWithPrivacy() async {
    try {
      final result = await _groupService.getGroupMembersWithPrivacy(
        groupId: widget.groupId,
        viewerId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _teacherProfileData = result['teacher'] as Map<String, dynamic>?;
        final rawStudents = result['students'] as List<dynamic>?;
        _studentsList = rawStudents != null
            ? rawStudents.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _isLoadingMembers = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _handleForcedStudentExit({required bool isDismissal}) async {
    if (_exitDialogShown || !mounted) return;
    _exitDialogShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            _group?.name ?? 'Group Notice',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Text(
            isDismissal
                ? 'This group has been dismissed by the teacher.'
                : 'You have been removed from this group by the teacher.',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
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
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: Text(
                  isDismissal ? 'Continue' : 'OK',
                  style: const TextStyle(color: Colors.white),
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
    _memberSearchController.dispose();
    super.dispose();
  }

  bool get _isViewerTeacher {
    return _group?.isSingleAdmin(widget.currentUserId) ?? false;
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openFullScreenImageViewer(String imageUrl, String title) {
    if (imageUrl.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.95),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.white54, size: 48),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTeacherIdBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Invalid Student ID',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This ID belongs to an Educator/Teacher. Only students can be enrolled in this batch.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadGroupPicture() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final file = File(picked.path);
    _showSnackBar('Uploading group picture...');

    try {
      File? compressed = await ImageHelper.compressImage(file);
      final ref = _storage.ref().child('groups/${widget.groupId}/profile.jpg');
      await ref.putFile(compressed ?? file);
      final downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('groups').doc(widget.groupId).update({
        'imageUrl': downloadUrl,
      });

      _showSnackBar('Group picture updated successfully!');
    } catch (e) {
      _showSnackBar('Failed to upload picture: $e');
    }
  }

  void _showEditGroupModal() {
    final group = _group;
    if (group == null || !_isViewerTeacher) return;

    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description);
    final batchCtrl = TextEditingController(text: group.batchName);
    final classCtrl = TextEditingController(text: group.className);
    final subjectCtrl = TextEditingController(text: group.subjectName);
    final courseCtrl = TextEditingController(text: group.courseName);
    final yearCtrl = TextEditingController(text: group.academicYear);
    final rulesCtrl = TextEditingController(text: group.groupRules);
    final welcomeCtrl = TextEditingController(text: group.welcomeMessage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
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
                const Text(
                  'Edit Group Information (Teacher Admin)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFEFF6FF),
                        backgroundImage: group.imageUrl.isNotEmpty
                            ? NetworkImage(group.imageUrl)
                            : null,
                        child: group.imageUrl.isEmpty
                            ? const Icon(Icons.groups_rounded,
                                color: Colors.blueAccent, size: 36)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadGroupPicture();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildEditField(nameCtrl, 'Group Name *', Icons.groups_rounded),
                _buildEditField(
                  descCtrl,
                  'Group Description & Purpose',
                  Icons.info_outline_rounded,
                  maxLines: 2,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditField(
                          classCtrl, 'Class', Icons.class_outlined),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEditField(
                          subjectCtrl, 'Subject', Icons.menu_book_rounded),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildEditField(
                          batchCtrl, 'Batch', Icons.schedule_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEditField(yearCtrl, 'Academic Year',
                          Icons.calendar_today_rounded),
                    ),
                  ],
                ),
                _buildEditField(courseCtrl, 'Course Name',
                    Icons.workspace_premium_outlined),
                _buildEditField(
                  rulesCtrl,
                  'Group Rules',
                  Icons.gavel_rounded,
                  maxLines: 2,
                ),
                _buildEditField(
                  welcomeCtrl,
                  'Welcome Message',
                  Icons.waving_hand_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        _showSnackBar('Group name cannot be empty.');
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await _groupService.updateGroupDetails(
                          groupId: widget.groupId,
                          teacherId: widget.currentUserId,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          batchName: batchCtrl.text.trim(),
                          className: classCtrl.text.trim(),
                          subjectName: subjectCtrl.text.trim(),
                          courseName: courseCtrl.text.trim(),
                          academicYear: yearCtrl.text.trim(),
                          groupRules: rulesCtrl.text.trim(),
                          welcomeMessage: welcomeCtrl.text.trim(),
                        );
                        _showSnackBar('Group details updated successfully!');
                      } catch (e) {
                        _showSnackBar('Update failed: $e');
                      }
                    },
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
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
  }

  Widget _buildEditField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19, color: Colors.blueAccent),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchConnectedStudentsForTeacher() async {
    final Set<String> connectedStudentIds = {};

    try {
      final connSnap = await _firestore
          .collection('teachers')
          .doc(widget.currentUserId)
          .collection('connected_students')
          .get();
      for (var d in connSnap.docs) {
        connectedStudentIds.add(d.id);
      }
    } catch (_) {}

    try {
      final followSnap = await _firestore
          .collection('teachers')
          .doc(widget.currentUserId)
          .collection('followers')
          .get();
      for (var d in followSnap.docs) {
        connectedStudentIds.add(d.id);
      }
    } catch (_) {}

    try {
      final reqSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: widget.currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();
      for (var d in reqSnap.docs) {
        final data = d.data();
        final sid = (data['studentId'] ?? data['senderId'] ?? '').toString();
        if (sid.isNotEmpty) connectedStudentIds.add(sid);
      }
    } catch (_) {}

    try {
      final feeSnap = await _firestore
          .collection('student_fees')
          .where('teacherId', isEqualTo: widget.currentUserId)
          .get();
      for (var d in feeSnap.docs) {
        final sid = (d.data()['studentId'] ?? '').toString();
        if (sid.isNotEmpty) connectedStudentIds.add(sid);
      }
    } catch (_) {}

    final List<Map<String, dynamic>> resultList = [];

    for (String sId in connectedStudentIds) {
      if (sId == widget.currentUserId) continue;

      try {
        var sDoc = await _firestore.collection('students').doc(sId).get();
        if (!sDoc.exists || sDoc.data() == null) {
          sDoc = await _firestore.collection('users').doc(sId).get();
        }

        if (sDoc.exists && sDoc.data() != null) {
          final data = sDoc.data()!;
          final rawName =
              (data['fullName'] ?? data['name'] ?? '').toString().trim();

          if (rawName.isEmpty || rawName.toLowerCase() == 'student') {
            continue;
          }

          final role = (data['role'] ?? data['userType'] ?? '')
              .toString()
              .toLowerCase();
          if (role == 'teacher') continue;

          resultList.add({
            'id': sDoc.id,
            'uid': (data['uid'] ?? data['fybttUid'] ?? sDoc.id).toString(),
            'name': rawName,
            'photoUrl': (data['profileImageUrl'] ??
                    data['profilePic'] ??
                    data['photoUrl'] ??
                    '')
                .toString(),
            'className':
                (data['className'] ?? data['studentClass'] ?? '').toString(),
          });
        }
      } catch (_) {}
    }

    resultList.sort((a, b) => (a['name'] as String)
        .toLowerCase()
        .compareTo((b['name'] as String).toLowerCase()));

    return resultList;
  }

  void _showAddOrInviteStudentDialog() {
    if (!_isViewerTeacher) return;
    final TextEditingController searchCtrl = TextEditingController();
    bool sendInviteMode = true;
    String searchKeyword = '';
    bool isLoading = true;
    List<Map<String, dynamic>> connectedStudents = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoading) {
              _fetchConnectedStudentsForTeacher().then((list) {
                if (bottomSheetCtx.mounted) {
                  setModalState(() {
                    connectedStudents = list;
                    isLoading = false;
                  });
                }
              });
            }

            final existingMembers = _group?.members ?? [];
            final filteredList = connectedStudents.where((student) {
              if (searchKeyword.isEmpty) return true;
              final name = (student['name'] ?? '').toString().toLowerCase();
              final uid = (student['uid'] ?? '').toString().toLowerCase();
              final id = (student['id'] ?? '').toString().toLowerCase();
              return name.contains(searchKeyword) ||
                  uid.contains(searchKeyword) ||
                  id.contains(searchKeyword);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select & Invite Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.grey),
                        onPressed: () => Navigator.pop(bottomSheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (val) {
                        setModalState(() {
                          searchKeyword = val.trim().toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search student by name or UID...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 20, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Send Official Invitation',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      sendInviteMode
                          ? 'Student will receive an Accept/Decline request.'
                          : 'Student will be added directly into this batch.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: sendInviteMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setModalState(() => sendInviteMode = val);
                    },
                  ),
                  const Divider(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Connected Students (${filteredList.length})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E4C7A),
                      ),
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.blueAccent),
                          )
                        : filteredList.isEmpty
                            ? Center(
                                child: Text(
                                  searchKeyword.isEmpty
                                      ? 'No connected students found.'
                                      : 'No connected student found matching "$searchKeyword".',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredList.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final student = filteredList[idx];
                                  final sId = student['id'].toString();
                                  final sUid = student['uid'].toString();
                                  final sName = student['name'].toString();
                                  final sPic =
                                      student['photoUrl'].toString();
                                  final bool alreadyInGroup =
                                      existingMembers.contains(sId);

                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      backgroundImage: sPic.isNotEmpty
                                          ? NetworkImage(sPic)
                                          : null,
                                      child: sPic.isEmpty
                                          ? Text(
                                              sName.isNotEmpty
                                                  ? sName[0].toUpperCase()
                                                  : 'S',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blueAccent),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      sName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5),
                                    ),
                                    subtitle: Text(
                                      'UID: $sUid',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontFamily: 'monospace'),
                                    ),
                                    trailing: alreadyInGroup
                                        ? Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Added',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(bottomSheetCtx);
                                              try {
                                                if (sendInviteMode) {
                                                  await _groupService
                                                      .sendInvitation(
                                                    groupId: widget.groupId,
                                                    groupName:
                                                        _group?.name ??
                                                            'Group',
                                                    invitedUserId: sId,
                                                    invitedByUserId: widget
                                                        .currentUserId,
                                                  );
                                                  _showSnackBar(
                                                      'Invitation sent to $sName!');
                                                } else {
                                                  await _groupService
                                                      .addStudentDirectlyByTeacher(
                                                    groupId: widget.groupId,
                                                    teacherId: widget
                                                        .currentUserId,
                                                    studentId: sId,
                                                  );
                                                  _showSnackBar(
                                                      '$sName added to group!');
                                                }
                                              } catch (e) {
                                                _showSnackBar('Failed: $e');
                                              }
                                            },
                                            child: Text(
                                              sendInviteMode
                                                  ? 'Invite'
                                                  : 'Add',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5),
                                            ),
                                          ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTeacherProfileShortcutDialog() {
    final group = _group;
    if (group == null) return;

    final String tName =
        group.teacherName.isNotEmpty ? group.teacherName : 'Teacher';
    final String tPic = group.teacherProfilePic;
    final String creds = group.teacherCredentials.isNotEmpty
        ? group.teacherCredentials
        : 'Verified Educator on FYBTT';
    final double tRating = group.teacherRating;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (tPic.isNotEmpty) {
                    Navigator.pop(ctx);
                    _openFullScreenImageViewer(tPic, tName);
                  }
                },
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: tPic.isNotEmpty ? NetworkImage(tPic) : null,
                  child: tPic.isEmpty
                      ? Text(
                          tName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  TeacherBadgesRow(
                    teacherName: tName,
                    isVerified: group.isTeacherVerified,
                    hasGoldenBadge: group.hasGoldenBadge,
                    qualityBadge: BadgeTierResolver.resolveAcademicQualityBadge({
                      'averageRating': tRating,
                    }),
                    badgeSize: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tCreds,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  if (group.isTeacherVerified)
                    InteractiveBadgeIcon(
                      badgeType: BadgeType.verified,
                      holderName: tName,
                      size: 16,
                      showLabelPill: true,
                    ),
                  if (group.hasGoldenBadge)
                    InteractiveBadgeIcon(
                      badgeType: BadgeType.golden,
                      holderName: tName,
                      size: 16,
                    ),
                  if (tRating > 0)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.orange.shade50,
                      avatar: const Icon(Icons.star_rounded,
                          color: Colors.orange, size: 16),
                      label: Text(
                        '${tRating.toStringAsFixed(1)} Rating',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_rounded,
                        color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _isViewerTeacher
                          ? 'You are the Single Admin of this batch'
                          : 'Connected Teacher for this Batch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!_isViewerTeacher)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showReportDialog(
                    targetId: group.createdBy,
                    targetType: 'teacher',
                    title: 'Report Teacher',
                  );
                },
                icon: const Icon(Icons.flag_outlined,
                    color: Colors.redAccent, size: 18),
                label: const Text(
                  'Report',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showReportDialog({
    required String targetId,
    required String targetType,
    required String title,
  }) {
    final List<String> reasons = [
      'Spam or unwanted messages',
      'Inappropriate or abusive behavior',
      'Fake credentials or misleading info',
      'Violation of academic group rules',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.flag_outlined, color: Colors.redAccent),
                title: Text(r, style: const TextStyle(fontSize: 13.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.reportAbuseOrSpam(
                    reporterId: widget.currentUserId,
                    targetId: targetId,
                    targetType: targetType,
                    reason: r,
                    chatOrGroupId: widget.groupId,
                  );
                  _showSnackBar('Report submitted securely.');
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
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
          title: const Text(
            'Remove Student from Group?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Text(
            'Are you sure you want to remove $studentName? They will see a notice ("You have been removed from this group by the teacher.") and will not be able to rejoin without your invitation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _groupService.removeStudentFromGroup(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                    studentId: studentId,
                  );
                  _showSnackBar('$studentName has been removed.');
                } catch (e) {
                  _showSnackBar('Error removing student: $e');
                }
              },
              child:
                  const Text('Remove', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.exit_to_app_rounded,
                    color: Colors.red.shade600, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Leave Group?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to leave this batch? You will no longer receive announcements, assignments, or group messages.',
            style: TextStyle(
                fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      _groupSubscription?.cancel();
                      try {
                        await _groupService.leaveGroup(
                          groupId: widget.groupId,
                          studentId: widget.currentUserId,
                        );
                        if (mounted) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          _showSnackBar('You have left the group.');
                        }
                      } catch (e) {
                        _showSnackBar('Failed to leave group: $e');
                      }
                    },
                    child: const Text(
                      'Leave',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDismissPasswordVerificationDialog() {
    final TextEditingController passwordController = TextEditingController();
    bool isVerifying = false;
    bool obscure = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verify Teacher Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To permanently dismiss this batch group and remove all group records, please enter your educator account password.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                enabled: !isVerifying,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: Colors.blueAccent, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: const Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () {
                      passwordController.dispose();
                      Navigator.pop(dialogCtx);
                    },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isVerifying
                  ? null
                  : () async {
                      final enteredPassword = passwordController.text.trim();
                      if (enteredPassword.isEmpty) {
                        setDialogState(() {
                          errorMessage = 'Please enter your password';
                        });
                        return;
                      }

                      setDialogState(() {
                        isVerifying = true;
                        errorMessage = null;
                      });

                      try {
                        final user = _auth.currentUser;
                        if (user == null || user.email == null) {
                          throw Exception('User authentication not found');
                        }

                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: enteredPassword,
                        );

                        await user.reauthenticateWithCredential(credential);

                        await _groupService.dismissGroup(
                          groupId: widget.groupId,
                          teacherId: widget.currentUserId,
                        );

                        passwordController.dispose();
                        Navigator.pop(dialogCtx);

                        if (mounted) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          _showSnackBar('Group dismissed permanently.');
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() {
                          isVerifying = false;
                          if (e.code == 'wrong-password' ||
                              e.code == 'invalid-credential') {
                            errorMessage =
                                'Incorrect password. Please try again.';
                          } else if (e.code == 'too-many-requests') {
                            errorMessage =
                                'Too many failed attempts. Try again later.';
                          } else {
                            errorMessage = e.message ?? 'Verification failed.';
                          }
                        });
                      } catch (e) {
                        setDialogState(() {
                          isVerifying = false;
                          errorMessage = 'Verification error: ${e.toString()}';
                        });
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm Dismiss',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
            ),
          ],
        ),
      ),
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
              Expanded(
                child: Text(
                  'Dismiss Group Permanently?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: const Text(
            'This will permanently close the group. Every student in this group will receive the notice ("This group has been dismissed by the teacher.") in real-time or when they next open the app. All group messages will be cleaned up.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(ctx);
                _showDismissPasswordVerificationDialog();
              },
              child: const Text(
                'Continue',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openInlineMediaDocsLinksSheet(List<MessageModel> allItems) {
    if (widget.onOpenMediaDocsLinks != null) {
      widget.onOpenMediaDocsLinks!();
      return;
    }

    final mediaItems = allItems
        .where((m) => m.type == 'image' || m.type == 'video')
        .toList();
    final docItems = allItems
        .where((m) => m.type == 'document' || m.type == 'file')
        .toList();
    final linkItems =
        allItems.where((m) => m.content.contains('http')).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Shared Media, Documents & Links',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const TabBar(
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blueAccent,
                  tabs: [
                    Tab(text: 'Media'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Links'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      mediaItems.isEmpty
                          ? const Center(child: Text('No media shared yet'))
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: mediaItems.length,
                              itemBuilder: (context, index) {
                                final item = mediaItems[index];
                                return InkWell(
                                  onTap: () {
                                    if (item.type == 'image') {
                                      _openFullScreenImageViewer(
                                          item.content, 'Shared Photo');
                                    } else {
                                      final uri = Uri.tryParse(item.content);
                                      if (uri != null) {
                                        launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: item.type == 'image'
                                        ? Image.network(item.content,
                                            fit: BoxFit.cover)
                                        : Container(
                                            color: const Color(0xFF0F172A),
                                            child: const Center(
                                              child: Icon(
                                                Icons.play_circle_fill_rounded,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                      docItems.isEmpty
                          ? const Center(child: Text('No documents shared yet'))
                          : ListView.builder(
                              itemCount: docItems.length,
                              itemBuilder: (context, index) {
                                final doc = docItems[index];
                                final fileName =
                                    doc.mediaMetaData?['fileName'] ??
                                        'Document';
                                return ListTile(
                                  leading: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  title: Text(fileName.toString()),
                                  subtitle: Text(doc.messageCategory
                                      .replaceAll('_', ' ')
                                      .toUpperCase()),
                                  trailing: const Icon(
                                      Icons.download_for_offline_outlined),
                                  onTap: () async {
                                    final uri = Uri.tryParse(doc.content);
                                    if (uri != null) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                );
                              },
                            ),
                      linkItems.isEmpty
                          ? const Center(child: Text('No links shared yet'))
                          : ListView.builder(
                              itemCount: linkItems.length,
                              itemBuilder: (context, index) {
                                final linkMsg = linkItems[index];
                                return ListTile(
                                  leading: const Icon(Icons.link_rounded,
                                      color: Colors.blueAccent),
                                  title: Text(
                                    linkMsg.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () async {
                                    final RegExp reg =
                                        RegExp(r'(https?:\/\/[^\s]+)');
                                    final match =
                                        reg.firstMatch(linkMsg.content);
                                    if (match != null) {
                                      final uri =
                                          Uri.tryParse(match.group(0)!);
                                      if (uri != null) {
                                        await launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(GroupModel group) {
    final List<String> tags = [
      if (group.className.isNotEmpty) group.className,
      if (group.subjectName.isNotEmpty) group.subjectName,
      if (group.batchName.isNotEmpty) 'Batch: ${group.batchName}',
      if (group.courseName.isNotEmpty) group.courseName,
      if (group.academicYear.isNotEmpty) group.academicYear,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  if (group.imageUrl.isNotEmpty) {
                    _openFullScreenImageViewer(group.imageUrl, group.name);
                  }
                },
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFFEFF6FF),
                  backgroundImage: group.imageUrl.isNotEmpty
                      ? NetworkImage(group.imageUrl)
                      : null,
                  child: group.imageUrl.isEmpty
                      ? const Icon(Icons.groups_rounded,
                          color: Colors.blueAccent, size: 46)
                      : null,
                ),
              ),
              if (group.isTeacherVerified)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: AvatarCornerBadge(
                    badgeType: BadgeType.verifiedBatch,
                    holderName: group.name,
                    size: 22,
                  ),
                ),
              if (_isViewerTeacher)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _pickAndUploadGroupPicture,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  group.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (group.isTeacherVerified) ...[
                const SizedBox(width: 5),
                InteractiveBadgeIcon(
                  badgeType: BadgeType.verifiedBatch,
                  holderName: group.name,
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${group.studentCount} Enrolled Student${group.studentCount == 1 ? '' : 's'} • Single Admin Batch',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: tags.map((t) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              group.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ],
          if (group.groupRules.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded,
                          size: 16, color: Colors.brown),
                      SizedBox(width: 6),
                      Text(
                        'Batch Rules & Guidelines',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.groupRules,
                    style:
                        const TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeacherTrustCard(GroupModel group) {
    final String tName =
        group.teacherName.isNotEmpty ? group.teacherName : 'Teacher';
    final String tPic = group.teacherProfilePic;
    final String creds = group.teacherCredentials.isNotEmpty
        ? group.teacherCredentials
        : 'Verified Batch Educator & Single Admin';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GROUP ADMIN (TEACHER ONLY)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  letterSpacing: 0.4,
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: Color(0xFFEFF6FF),
                label: Text(
                  'Single Admin',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showTeacherProfileShortcutDialog,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage:
                      tPic.isNotEmpty ? NetworkImage(tPic) : null,
                  child: tPic.isEmpty
                      ? Text(
                          tName[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blueAccent,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              tName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TeacherBadgesRow(
                            teacherName: tName,
                            isVerified: group.isTeacherVerified,
                            hasGoldenBadge: group.hasGoldenBadge,
                            qualityBadge:
                                BadgeTierResolver.resolveAcademicQualityBadge({
                              'averageRating': group.teacherRating,
                            }),
                            badgeSize: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        creds,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedMediaSummaryCard() {
    return StreamBuilder<List<MessageModel>>(
      stream: _chatService.getSharedMediaDocsLinksStream(
        chatOrGroupId: widget.groupId,
        isGroup: true,
      ),
      builder: (context, snapshot) {
        final allMessages = snapshot.data ?? const [];
        final int mediaCount = allMessages
            .where((m) => m.type == 'image' || m.type == 'video')
            .length;
        final int docsCount = allMessages
            .where((m) => m.type == 'document' || m.type == 'file')
            .length;
        final int linksCount =
            allMessages.where((m) => m.content.contains('http')).length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _openInlineMediaDocsLinksSheet(allMessages),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Media, Documents & Shared Links',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.blueAccent),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildCounterBox(Icons.photo_library_rounded,
                        'Photos & Videos', mediaCount, Colors.purple),
                    const SizedBox(width: 8),
                    _buildCounterBox(Icons.picture_as_pdf_rounded,
                        'Study Docs', docsCount, Colors.redAccent),
                    const SizedBox(width: 8),
                    _buildCounterBox(Icons.link_rounded, 'Shared Links',
                        linksCount, Colors.blueAccent),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounterBox(
      IconData icon, String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherAdminSettingsSection(GroupModel group) {
    if (!_isViewerTeacher) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEACHER ADMIN CONTROLS',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Admin-Only Posting Mode',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            subtitle: Text(
              group.onlyAdminCanPost
                  ? 'Active: Only you (Teacher) can send messages.'
                  : 'Student Discussion Mode: Students can ask doubts & discuss.',
              style: const TextStyle(fontSize: 12),
            ),
            value: group.onlyAdminCanPost,
            activeColor: Colors.blueAccent,
            onChanged: (val) async {
              await _groupService.setAdminOnlyPostingMode(
                groupId: widget.groupId,
                teacherId: widget.currentUserId,
                onlyAdminCanPost: val,
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.timer_outlined, color: Colors.blueAccent),
            title: const Text(
              'Disappearing Messages',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            subtitle: Text(
              group.disappearingDurationHours == 0
                  ? 'Off (Messages stay permanently)'
                  : 'Auto-expire after ${group.disappearingDurationHours} hours',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: DropdownButton<int>(
              value: [0, 24, 168, 720]
                      .contains(group.disappearingDurationHours)
                  ? group.disappearingDurationHours
                  : 0,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 24, child: Text('24 Hours')),
                DropdownMenuItem(value: 168, child: Text('7 Days')),
                DropdownMenuItem(value: 720, child: Text('30 Days')),
              ],
              onChanged: (hours) async {
                if (hours != null) {
                  await _groupService.updateGroupDetails(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                    disappearingDurationHours: hours,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersAndPrivacySection(GroupModel group) {
    if (!_isViewerTeacher) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip_rounded,
                    color: Colors.blueAccent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Batch Strength: ${group.studentCount} Students',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Student Privacy Protection: To protect everyone\'s privacy, individual student names, phone numbers, emails and profiles are strictly hidden from other students. Only your batch teacher can view and manage student identities.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final filteredStudents = _studentsList.where((s) {
      if (_memberSearchQuery.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final uid = (s['uid'] ?? '').toString().toLowerCase();
      return name.contains(_memberSearchQuery) ||
          uid.contains(_memberSearchQuery);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ENROLLED STUDENTS (${_studentsList.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddOrInviteStudentDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add / Invite'),
              ),
            ],
          ),
          if (_studentsList.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _memberSearchController,
                onChanged: (val) => setState(
                    () => _memberSearchQuery = val.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search student in group by name or UID...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_isLoadingMembers)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No students match your search.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                final String sUid = (student['uid'] ?? '').toString();
                final String sName =
                    (student['name'] ?? 'Student').toString();
                final String sPic =
                    (student['profilePic'] ?? '').toString();
                final bool isMuted = group.isStudentMuted(sUid);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: GestureDetector(
                    onTap: () {
                      if (sPic.isNotEmpty) {
                        _openFullScreenImageViewer(sPic, sName);
                      }
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage:
                          sPic.isNotEmpty ? NetworkImage(sPic) : null,
                      child: sPic.isEmpty
                          ? Text(
                              sName.isNotEmpty ? sName[0].toUpperCase() : 'S',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            )
                          : null,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          sName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      if (isMuted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Muted',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'UID: $sUid',
                    style: const TextStyle(
                        fontSize: 11.5, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isMuted ? 'Unmute Student' : 'Mute Student',
                        icon: Icon(
                          isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_none_rounded,
                          color: isMuted
                              ? Colors.redAccent
                              : Colors.blueGrey,
                        ),
                        onPressed: () async {
                          try {
                            await _groupService.setStudentMuteStatus(
                              groupId: widget.groupId,
                              teacherId: widget.currentUserId,
                              studentId: sUid,
                              mute: !isMuted,
                            );
                            _showSnackBar(
                              isMuted
                                  ? '$sName unmuted.'
                                  : '$sName muted temporarily.',
                            );
                          } catch (e) {
                            _showSnackBar('Error: $e');
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Remove Student from Group',
                        icon: const Icon(
                          Icons.person_remove_alt_1_outlined,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            _confirmRemoveStudent(sUid, sName),
                      ),
                      IconButton(
                        tooltip: 'Report Student',
                        icon: const Icon(
                          Icons.flag_outlined,
                          color: Colors.orange,
                          size: 20,
                        ),
                        onPressed: () => _showReportDialog(
                          targetId: sUid,
                          targetType: 'student',
                          title: 'Report $sName',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUtilitiesAndDismissSection(GroupModel group) {
    final bool isNotifMuted =
        group.mutedByUsers.contains(widget.currentUserId);
    final bool isArchived =
        group.archivedByUsers.contains(widget.currentUserId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              isNotifMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              color: Colors.blueAccent,
            ),
            title: const Text(
              'Mute Group Notifications',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            value: isNotifMuted,
            activeColor: Colors.blueAccent,
            onChanged: (val) async {
              await _groupService.toggleGroupNotificationMute(
                groupId: widget.groupId,
                userId: widget.currentUserId,
                mute: val,
              );
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.archive_outlined,
                color: Colors.blueAccent),
            title: const Text(
              'Archive Group',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            value: isArchived,
            activeColor: Colors.blueAccent,
            onChanged: (val) async {
              await _groupService.toggleGroupArchive(
                groupId: widget.groupId,
                userId: widget.currentUserId,
                archive: val,
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined,
                color: Colors.blueAccent),
            title: const Text(
              'Export Chat Transcript',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
            subtitle: const Text(
              'Copy privacy-safe chat history to clipboard',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              final text = await _chatService.exportChatTranscript(
                chatOrGroupId: widget.groupId,
                isGroup: true,
                currentUserId: widget.currentUserId,
                isViewerTeacherOfGroup: _isViewerTeacher,
              );
              if (text.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: text));
                _showSnackBar('Chat transcript copied to clipboard!');
              } else {
                _showSnackBar('No messages to export.');
              }
            },
          ),
          if (!_isViewerTeacher) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text(
                'Report Group or Abuse',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: Colors.orange,
                ),
              ),
              onTap: () => _showReportDialog(
                targetId: group.id,
                targetType: 'group',
                title: 'Report Group',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.exit_to_app_rounded,
                  color: Colors.redAccent),
              title: const Text(
                'Leave Group',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: Colors.redAccent,
                ),
              ),
              subtitle: const Text(
                'Leave this batch voluntarily',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: _confirmLeaveGroup,
            ),
          ],
          if (_isViewerTeacher) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
                onPressed: _confirmDismissGroup,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(
                  'Dismiss Group Permanently',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Group Information',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_isViewerTeacher)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              tooltip: 'Edit Group Info',
              onPressed: _showEditGroupModal,
            ),
        ],
      ),
      body: group == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeaderCard(group),
                  const SizedBox(height: 14),
                  _buildTeacherTrustCard(group),
                  const SizedBox(height: 14),
                  _buildSharedMediaSummaryCard(),
                  const SizedBox(height: 14),
                  if (_isViewerTeacher) ...[
                    _buildTeacherAdminSettingsSection(group),
                    const SizedBox(height: 14),
                  ],
                  _buildMembersAndPrivacySection(group),
                  const SizedBox(height: 14),
                  _buildUtilitiesAndDismissSection(group),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
