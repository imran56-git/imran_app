import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/group_service.dart';

class CreateGroupScreen extends StatefulWidget {
  final String teacherId;
  const CreateGroupScreen({super.key, required this.teacherId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService _groupService = GroupService();

  late TabController _tabController;

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _batchNameController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _academicYearController =
      TextEditingController(text: '2026-2027');
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _groupRulesController = TextEditingController();
  final TextEditingController _welcomeMessageController =
      TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _uidSearchController = TextEditingController();

  List<Map<String, dynamic>> selectedStudents = [];
  List<Map<String, dynamic>> connectedStudents = [];
  Set<String> connectedStudentIds = {};

  bool isLoading = true;
  bool isSearchingUid = false;
  bool isCreating = false;
  String searchQuery = '';
  String teacherName = 'Teacher';
  bool isTeacherVerified = false;
  bool hasGoldenBadge = false;

  final List<String> _quickClasses = [
    'Class 8',
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
    'Competitive',
  ];

  final List<String> _quickSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Computer Science',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadTeacherInfoAndConnections();
    await fetchConnectedStudents();
  }

  Future<void> _loadTeacherInfoAndConnections() async {
    try {
      final teacherDoc =
          await _firestore.collection('teachers').doc(widget.teacherId).get();
      if (teacherDoc.exists && teacherDoc.data() != null) {
        final data = teacherDoc.data()!;
        teacherName =
            (data['name'] ?? data['fullName'] ?? 'Teacher').toString();
        isTeacherVerified =
            (data['isVerified'] == true) || (data['status'] == 'approved');
        hasGoldenBadge = data['hasGoldenBadge'] == true;

        final List<dynamic> followers =
            (data['followers'] as List<dynamic>?) ??
                (data['students'] as List<dynamic>?) ??
                (data['connectedStudents'] as List<dynamic>?) ??
                const [];
        for (final id in followers) {
          connectedStudentIds.add(id.toString());
        }
      }

      final followSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: widget.teacherId)
          .where('status', isEqualTo: 'accepted')
          .get();
      for (final doc in followSnap.docs) {
        final data = doc.data();
        final String sId = (data['studentId'] ?? '').toString();
        if (sId.isNotEmpty) {
          connectedStudentIds.add(sId);
        }
      }

      final chatsSnap = await _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.teacherId)
          .get();
      for (final doc in chatsSnap.docs) {
        final parts =
            (doc.data()['participants'] as List<dynamic>?) ?? const [];
        for (final p in parts) {
          final pid = p.toString();
          if (pid.isNotEmpty && pid != widget.teacherId) {
            connectedStudentIds.add(pid);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> fetchConnectedStudents() async {
    try {
      final Map<String, Map<String, dynamic>> studentMap = {};

      for (final studentId in connectedStudentIds) {
        if (studentId == widget.teacherId || studentId.isEmpty) continue;

        DocumentSnapshot<Map<String, dynamic>> userDoc =
            await _firestore.collection('students').doc(studentId).get();
        if (!userDoc.exists || userDoc.data() == null) {
          userDoc = await _firestore.collection('users').doc(studentId).get();
        }

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          studentMap[studentId] = {
            'id': studentId,
            'uid': (data['uid'] ?? data['fybttUid'] ?? studentId).toString(),
            'name': (data['name'] ?? data['fullName'] ?? 'Connected Student')
                .toString(),
            'photoUrl': (data['profileImageUrl'] ??
                    data['profileUrl'] ??
                    data['photoUrl'] ??
                    '')
                .toString(),
            'className': (data['className'] ?? data['studentClass'] ?? '')
                .toString(),
            'isConnected': true,
          };
        }
      }

      final list = studentMap.values.toList();
      list.sort((a, b) => (a['name'] as String)
          .toLowerCase()
          .compareTo((b['name'] as String).toLowerCase()));

      if (mounted) {
        setState(() {
          connectedStudents = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      _showSnackBar("Error loading connected students: $e");
    }
  }

  Future<void> _searchAndAddByUid() async {
    final String rawUid = _uidSearchController.text.trim();
    if (rawUid.isEmpty) {
      _showSnackBar("Please enter a Student UID to search");
      return;
    }

    setState(() => isSearchingUid = true);
    try {
      final existingIndex = connectedStudents.indexWhere((s) =>
          s['id'].toString().toLowerCase() == rawUid.toLowerCase() ||
          s['uid'].toString().toLowerCase() == rawUid.toLowerCase());

      if (existingIndex != -1) {
        final foundStudent = connectedStudents[existingIndex];
        if (!selectedStudents.any((s) => s['id'] == foundStudent['id'])) {
          setState(() {
            selectedStudents.add(foundStudent);
          });
        }
        _uidSearchController.clear();
        _showSnackBar("${foundStudent['name']} selected for invitation!");
        setState(() => isSearchingUid = false);
        return;
      }

      DocumentSnapshot<Map<String, dynamic>>? docSnap =
          await _firestore.collection('students').doc(rawUid).get();

      if (!docSnap.exists) {
        docSnap = await _firestore.collection('users').doc(rawUid).get();
      }

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        final String docId = docSnap.id;

        final Map<String, dynamic> studentObj = {
          'id': docId,
          'uid': (data['uid'] ?? data['fybttUid'] ?? docId).toString(),
          'name':
              (data['name'] ?? data['fullName'] ?? 'Student').toString(),
          'photoUrl': (data['photoUrl'] ??
                  data['profileImageUrl'] ??
                  data['profileUrl'] ??
                  '')
              .toString(),
          'className': '',
          'isConnected': connectedStudentIds.contains(docId),
        };

        setState(() {
          if (!connectedStudents.any((s) => s['id'] == docId)) {
            connectedStudents.insert(0, studentObj);
          }
          if (!selectedStudents.any((s) => s['id'] == docId)) {
            selectedStudents.add(studentObj);
          }
        });
        _uidSearchController.clear();
        _showSnackBar("${studentObj['name']} added to invite list!");
      } else {
        _showSnackBar("No connected student found with UID: $rawUid");
      }
    } catch (e) {
      _showSnackBar("UID search error: $e");
    } finally {
      if (mounted) {
        setState(() => isSearchingUid = false);
      }
    }
  }

  void _toggleSelection(Map<String, dynamic> student) {
    setState(() {
      final index =
          selectedStudents.indexWhere((s) => s['id'] == student['id']);
      if (index != -1) {
        selectedStudents.removeAt(index);
      } else {
        selectedStudents.add(student);
      }
    });
  }

  void _showImageUrlDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Group Profile Photo",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: TextField(
            controller: _imageUrlController,
            decoration: InputDecoration(
              hintText: "Paste image URL (optional)...",
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _imageUrlController.clear();
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text("Clear"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> createGroup() async {
    final String groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      _showSnackBar("Please enter a group name");
      _tabController.animateTo(0);
      return;
    }
    if (selectedStudents.isEmpty) {
      _showSnackBar("Please select at least one connected student to invite");
      _tabController.animateTo(1);
      return;
    }

    setState(() => isCreating = true);

    try {
      final List<String> invitedIds =
          selectedStudents.map((s) => s['id'].toString()).toList();

      await _groupService.createGroup(
        name: groupName,
        createdBy: widget.teacherId,
        imageUrl: _imageUrlController.text.trim(),
        teacherName: teacherName,
        description: _descriptionController.text.trim(),
        batchName: _batchNameController.text.trim(),
        className: _classNameController.text.trim(),
        subjectName: _subjectNameController.text.trim(),
        courseName: _courseNameController.text.trim(),
        academicYear: _academicYearController.text.trim(),
        groupRules: _groupRulesController.text.trim(),
        welcomeMessage: _welcomeMessageController.text.trim(),
        invitedStudentIds: invitedIds,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Group created & invitations sent to ${invitedIds.length} connected student(s)!");
    } catch (e) {
      _showSnackBar("Failed to create group: $e");
    } finally {
      if (mounted) {
        setState(() => isCreating = false);
      }
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupDetailsTab() {
    final String imgUrl = _imageUrlController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showImageUrlDialog,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: const Color(0xFFEFF6FF),
                            backgroundImage:
                                imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
                            child: imgUrl.isEmpty
                                ? const Icon(Icons.groups_rounded,
                                    color: Colors.blueAccent, size: 32)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                        ],
                      ),
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
                                  "Created by $teacherName",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              if (isTeacherVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified,
                                    color: Colors.blueAccent, size: 15),
                              ],
                              if (hasGoldenBadge) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.workspace_premium,
                                    color: Colors.amber, size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _groupNameController,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Group / Tuition Batch Name *',
                              isDense: true,
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _descriptionController,
                  label: "Group Description & Purpose",
                  hint: "Write the objective of this group...",
                  icon: Icons.info_outline_rounded,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Academic Classification",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Quick Select Class:",
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _quickClasses.map((cls) {
                    final bool isSelected =
                        _classNameController.text.trim() == cls;
                    return ChoiceChip(
                      label: Text(cls, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: Colors.blueAccent.withOpacity(0.18),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _classNameController.text = cls);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  controller: _classNameController,
                  label: "Class Name",
                  hint: "e.g. Class 10, Class 12",
                  icon: Icons.class_outlined,
                ),
                const Text(
                  "Quick Select Subject:",
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _quickSubjects.map((subj) {
                    final bool isSelected =
                        _subjectNameController.text.trim() == subj;
                    return ChoiceChip(
                      label: Text(subj, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: Colors.blueAccent.withOpacity(0.18),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _subjectNameController.text = subj);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  controller: _subjectNameController,
                  label: "Subject Name",
                  hint: "e.g. Physics, Mathematics",
                  icon: Icons.menu_book_rounded,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: _batchNameController,
                        label: "Batch Name",
                        hint: "e.g. Morning Batch A",
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInputField(
                        controller: _academicYearController,
                        label: "Academic Year",
                        hint: "e.g. 2026-2027",
                        icon: Icons.calendar_today_rounded,
                      ),
                    ),
                  ],
                ),
                _buildInputField(
                  controller: _courseNameController,
                  label: "Course / Target Exam",
                  hint: "e.g. Board Exam Prep, JEE / NEET Foundation",
                  icon: Icons.workspace_premium_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Group Rules & Welcome Message",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  controller: _groupRulesController,
                  label: "Group Rules",
                  hint: "e.g. Respect everyone, ask academic doubts only...",
                  icon: Icons.gavel_rounded,
                  maxLines: 2,
                ),
                _buildInputField(
                  controller: _welcomeMessageController,
                  label: "Welcome Message (Auto-posted on creation)",
                  hint: "e.g. Welcome to our new batch group!",
                  icon: Icons.waving_hand_outlined,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  color: Colors.white),
              label: Text(
                "Next: Select Connected Students (${selectedStudents.length} Selected)",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStudentSelectionTab() {
    final filteredList = connectedStudents.where((student) {
      if (searchQuery.isEmpty) return true;
      final name = (student['name'] ?? '').toString().toLowerCase();
      final uid = (student['uid'] ?? '').toString().toLowerCase();
      final id = (student['id'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) ||
          uid.contains(searchQuery) ||
          id.contains(searchQuery);
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _uidSearchController,
                        decoration: const InputDecoration(
                          hintText: "Invite connected student by UID...",
                          hintStyle:
                              TextStyle(fontSize: 13.5, color: Colors.grey),
                          prefixIcon: Icon(Icons.qr_code_scanner_rounded,
                              color: Colors.blueAccent, size: 19),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSearchingUid ? null : _searchAndAddByUid,
                    child: isSearchingUid
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Add UID",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => searchQuery = val.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: "Filter connected students by name or UID...",
                    hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  "Showing My Connected Students (${connectedStudents.length})",
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E4C7A),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (selectedStudents.isNotEmpty)
          Container(
            height: 86,
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: selectedStudents.length,
              itemBuilder: (context, index) {
                final student = selectedStudents[index];
                final String name = (student['name'] ?? 'S').toString();
                final String photoUrl = (student['photoUrl'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: InkWell(
                              onTap: () => _toggleSelection(student),
                              child: const CircleAvatar(
                                radius: 9,
                                backgroundColor: Colors.redAccent,
                                child: Icon(Icons.close,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : filteredList.isEmpty
                  ? const Center(
                      child: Text(
                        "No connected students found",
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final student = filteredList[index];
                        final bool isSelected = selectedStudents
                            .any((s) => s['id'] == student['id']);
                        final String name =
                            (student['name'] ?? 'Student').toString();
                        final String photoUrl =
                            (student['photoUrl'] ?? '').toString();
                        final String uid =
                            (student['uid'] ?? student['id'] ?? '').toString();

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 23,
                            backgroundColor: isSelected
                                ? Colors.blueAccent
                                : Colors.blue.shade50,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'S',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            "UID: $uid • Connected",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.green),
                          ),
                          trailing: Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? Colors.blueAccent : Colors.grey,
                            size: 24,
                          ),
                          onTap: () => _toggleSelection(student),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Teacher Group",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              "Single Admin • Student Privacy Protected",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: [
            const Tab(text: "1. Batch & Group Info"),
            Tab(text: "2. Invite Students (${selectedStudents.length})"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupDetailsTab(),
          _buildStudentSelectionTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: isCreating ? null : createGroup,
        icon: isCreating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white),
        label: Text(
          isCreating
              ? "Creating..."
              : "Create Group (${selectedStudents.length})",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameController.dispose();
    _batchNameController.dispose();
    _classNameController.dispose();
    _subjectNameController.dispose();
    _courseNameController.dispose();
    _academicYearController.dispose();
    _descriptionController.dispose();
    _groupRulesController.dispose();
    _welcomeMessageController.dispose();
    _imageUrlController.dispose();
    _searchController.dispose();
    _uidSearchController.dispose();
    super.dispose();
  }
}
