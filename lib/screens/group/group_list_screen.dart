import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../utils/chat_colors.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import 'invitation_list_screen.dart';

class GroupListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final bool isEmbedded;

  const GroupListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.isEmbedded = false,
  });

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService _groupService = GroupService();

  String _searchQuery = "";
  String _selectedFilter = "all";
  bool _isTeacherRole = false;

  StreamSubscription<List<Map<String, dynamic>>>? _noticesSubscription;
  StreamSubscription<QuerySnapshot>? _groupStatusSubscription;
  final Set<String> _processingNoticeIds = {};
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _listenForRealtimeAndDelayedGroupNotices();
  }

  @override
  void dispose() {
    _noticesSubscription?.cancel();
    _groupStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    if (widget.currentUserId.trim().isEmpty) return;
    try {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(widget.currentUserId)
          .get();
      if (teacherDoc.exists) {
        if (mounted) {
          setState(() => _isTeacherRole = true);
        }
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final role = (data['role'] ?? data['type'] ?? '').toString();
        if (role == 'teacher' && mounted) {
          setState(() => _isTeacherRole = true);
        }
      }
    } catch (_) {}
  }

  void _listenForRealtimeAndDelayedGroupNotices() {
    if (widget.currentUserId.trim().isEmpty) return;

    _noticesSubscription = _groupService
        .getPendingGroupNoticesStream(widget.currentUserId)
        .listen((notices) {
      for (final notice in notices) {
        final String groupId =
            (notice['groupId'] ?? notice['docId'] ?? '').toString();
        if (groupId.isEmpty || _processingNoticeIds.contains(groupId)) continue;

        final String noticeType = (notice['noticeType'] ?? 'dismissed').toString();
        final String groupName =
            (notice['groupName'] ?? 'Group').toString();
        final String teacherName =
            (notice['teacherName'] ?? 'Teacher').toString();

        _processingNoticeIds.add(groupId);
        _enqueueNoticePopup(
          groupId: groupId,
          groupName: groupName,
          teacherName: teacherName,
          isDismissal: noticeType == 'dismissed',
        );
      }
    });

    _groupStatusSubscription = _firestore
        .collection('groups')
        .where('members', arrayContains: widget.currentUserId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final group = GroupModel.fromMap(doc.data(), doc.id);
        if (group.isSingleAdmin(widget.currentUserId)) continue;

        final bool needsDismissPopup = group.isDismissed ||
            group.unacknowledgedDismissMembers.contains(widget.currentUserId);
        final bool needsRemovalPopup =
            group.pendingRemovalNotices.contains(widget.currentUserId);

        if ((needsDismissPopup || needsRemovalPopup) &&
            !_processingNoticeIds.contains(group.id)) {
          _processingNoticeIds.add(group.id);
          _enqueueNoticePopup(
            groupId: group.id,
            groupName: group.name,
            teacherName:
                group.teacherName.isNotEmpty ? group.teacherName : 'Teacher',
            isDismissal: needsDismissPopup,
          );
        }
      }
    });
  }

  Future<void> _enqueueNoticePopup({
    required String groupId,
    required String groupName,
    required String teacherName,
    required bool isDismissal,
  }) async {
    while (_isDialogShowing && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!mounted) return;

    _isDialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDismissal ? Icons.cancel_outlined : Icons.person_remove_alt_1,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDismissal
                    ? "This group has been dismissed by the teacher."
                    : "You have been removed from this group by the teacher.",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDismissal
                    ? "Teacher ($teacherName) has permanently closed this batch group. No further messages can be sent."
                    : "You no longer have access to messages in this group.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatColors.primaryApp,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    if (isDismissal) {
                      await _groupService.acknowledgeGroupDismissal(
                        groupId: groupId,
                        studentId: widget.currentUserId,
                      );
                    } else {
                      await _groupService.acknowledgeStudentRemoval(
                        groupId: groupId,
                        studentId: widget.currentUserId,
                      );
                    }
                  } catch (_) {}
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

    _isDialogShowing = false;
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat.jm().format(date);
    }
    return DateFormat('dd/MM/yy').format(date);
  }

  void _showGroupOptionsSheet(GroupModel group) {
    final bool isMuted = group.mutedByUsers.contains(widget.currentUserId);
    final bool isArchived = group.archivedByUsers.contains(widget.currentUserId);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                leading: Icon(
                  isMuted ? Icons.notifications_active : Icons.notifications_off,
                  color: ChatColors.primaryApp,
                ),
                title: Text(
                  isMuted ? "Unmute Group Notifications" : "Mute Group Notifications",
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _groupService.toggleGroupNotificationMute(
                    groupId: group.id,
                    userId: widget.currentUserId,
                    mute: !isMuted,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: ChatColors.primaryApp,
                ),
                title: Text(isArchived ? "Unarchive Group" : "Archive Group"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _groupService.toggleGroupArchive(
                    groupId: group.id,
                    userId: widget.currentUserId,
                    archive: !isArchived,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingInvitesBanner() {
    if (_isTeacherRole) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .collection('group_invites')
          .snapshots(),
      builder: (context, snapshot) {
        final int inviteCount =
            snapshot.hasData ? snapshot.data!.docs.length : 0;
        if (inviteCount == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    InvitationListScreen(currentUserId: widget.currentUserId),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_rounded,
                    color: Colors.blueAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You have $inviteCount pending group invitation${inviteCount > 1 ? 's' : ''}",
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.blueAccent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All Groups'},
      {'key': 'unread', 'label': 'Unread'},
      {'key': 'archived', 'label': 'Archived'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: filters.map((f) {
          final bool isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              selectedColor: ChatColors.primaryApp.withOpacity(0.15),
              backgroundColor: const Color(0xFFF0F2F5),
              labelStyle: TextStyle(
                color: isSelected ? ChatColors.primaryApp : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? ChatColors.primaryApp
                      : Colors.transparent,
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedFilter = f['key']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBodyContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: const InputDecoration(
                hintText: "Search groups, batch or subject...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.5),
                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        _buildFilterChips(),
        _buildPendingInvitesBanner(),
        Expanded(
          child: StreamBuilder<List<GroupModel>>(
            stream: _groupService.getUserActiveGroupsStream(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: ChatColors.primaryApp),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyPlaceholder();
              }

              final allGroups = snapshot.data!;
              final filteredGroups = allGroups.where((group) {
                final bool isArchived =
                    group.archivedByUsers.contains(widget.currentUserId);
                if (_selectedFilter == 'archived' && !isArchived) return false;
                if (_selectedFilter != 'archived' && isArchived) return false;

                if (_selectedFilter == 'unread' &&
                    group.getUnreadCountForUser(widget.currentUserId) <= 0) {
                  return false;
                }

                if (_searchQuery.isEmpty) return true;
                final searchable =
                    '${group.name} ${group.batchName} ${group.className} ${group.subjectName} ${group.courseName}'
                        .toLowerCase();
                return searchable.contains(_searchQuery);
              }).toList();

              if (filteredGroups.isEmpty) {
                return _buildEmptyPlaceholder();
              }

              return ListView.separated(
                itemCount: filteredGroups.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  indent: 78,
                  color: Color(0xFFEEEEEE),
                ),
                itemBuilder: (context, index) {
                  final group = filteredGroups[index];
                  final int unreadCount =
                      group.getUnreadCountForUser(widget.currentUserId);
                  final bool isMutedByTeacher =
                      group.isStudentMuted(widget.currentUserId);
                  final bool isNotificationMuted =
                      group.mutedByUsers.contains(widget.currentUserId);

                  final List<String> metaTags = [
                    if (group.className.isNotEmpty) group.className,
                    if (group.subjectName.isNotEmpty) group.subjectName,
                    if (group.batchName.isNotEmpty) group.batchName,
                  ];

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: group.imageUrl.isNotEmpty
                              ? NetworkImage(group.imageUrl)
                              : null,
                          child: group.imageUrl.isEmpty
                              ? const Icon(Icons.groups_rounded,
                                  color: ChatColors.primaryApp, size: 28)
                              : null,
                        ),
                        if (group.isTeacherVerified)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.blueAccent,
                                size: 15,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (group.isTeacherVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Colors.blueAccent, size: 16),
                        ],
                        if (group.hasGoldenBadge) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.workspace_premium,
                              color: Colors.amber, size: 17),
                        ],
                        if (isNotificationMuted) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.volume_off_rounded,
                              color: Colors.grey, size: 15),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (metaTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              metaTags.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Row(
                            children: [
                              if (isMutedByTeacher) ...[
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Muted by teacher",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  group.lastMessage.isNotEmpty
                                      ? group.lastMessage
                                      : "Start a conversation...",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDateTime(
                              group.lastMessageTime ?? group.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: unreadCount > 0
                                ? ChatColors.primaryApp
                                : Colors.grey,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: ChatColors.primaryApp,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onLongPress: () => _showGroupOptionsSheet(group),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupChatScreen(
                            groupId: group.id,
                            groupName: group.name,
                            currentUserId: widget.currentUserId,
                            currentUserName: widget.currentUserName,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return Container(
        color: Colors.white,
        child: _buildBodyContent(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Groups',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: ChatColors.appBarLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded, color: Colors.white),
            tooltip: "Group Invitations",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InvitationListScreen(currentUserId: widget.currentUserId),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBodyContent(),
      floatingActionButton: _isTeacherRole
          ? FloatingActionButton(
              backgroundColor: ChatColors.primaryApp,
              elevation: 4,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateGroupScreen(teacherId: widget.currentUserId),
                  ),
                );
              },
              child: const Icon(Icons.group_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _selectedFilter == 'archived'
                ? "No archived groups"
                : "No active groups found",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
