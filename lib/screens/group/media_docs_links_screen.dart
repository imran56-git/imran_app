import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';

class MediaDocsLinksScreen extends StatefulWidget {
  final String chatOrGroupId;
  final String title;
  final String currentUserId;
  final bool isGroup;
  final bool isViewerTeacherOfGroup;
  final int initialTabIndex;

  const MediaDocsLinksScreen({
    super.key,
    required this.chatOrGroupId,
    required this.title,
    required this.currentUserId,
    this.isGroup = true,
    this.isViewerTeacherOfGroup = false,
    this.initialTabIndex = 0,
  });

  @override
  State<MediaDocsLinksScreen> createState() => _MediaDocsLinksScreenState();
}

class _MediaDocsLinksScreenState extends State<MediaDocsLinksScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final List<Map<String, String>> _academicCategories = [
    {'key': 'all', 'label': 'All Resources'},
    {'key': 'study_material', 'label': 'Study Material'},
    {'key': 'homework', 'label': 'Homework'},
    {'key': 'assignment', 'label': 'Assignments'},
    {'key': 'announcement', 'label': 'Announcements'},
    {'key': 'exam_notice', 'label': 'Exam Notices'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  List<String> _extractUrls(String text) {
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    return urlRegExp
        .allMatches(text)
        .map((m) => m.group(0) ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final Uri? uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open file or link.');
      }
    } catch (e) {
      _showSnackBar('Error opening URL: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFullScreenImagePreview(MessageModel item) {
    final String senderLabel = widget.isGroup
        ? item.getVisibleSenderName(
            currentUserId: widget.currentUserId,
            isViewerTeacherOfGroup: widget.isViewerTeacherOfGroup,
          )
        : (item.senderId == widget.currentUserId ? 'You' : 'Shared');

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    item.content,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$senderLabel • ${_formatDate(item.timestamp)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download_rounded,
                              color: Colors.white),
                          tooltip: 'Download / Open Externally',
                          onPressed: () => _openExternalUrl(item.content),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesCategoryAndSearch(MessageModel msg, {String? extraSearchText}) {
    if (msg.deletedForUsers.contains(widget.currentUserId)) return false;

    if (_selectedCategory != 'all' &&
        msg.messageCategory.toLowerCase() != _selectedCategory.toLowerCase()) {
      return false;
    }

    if (_searchQuery.isEmpty) return true;

    final String fileName =
        (msg.mediaMetaData?['fileName'] ?? '').toString().toLowerCase();
    final String content = msg.content.toLowerCase();
    final String category = msg.messageCategory.toLowerCase();
    final String extra = (extraSearchText ?? '').toLowerCase();

    return fileName.contains(_searchQuery) ||
        content.contains(_searchQuery) ||
        category.contains(_searchQuery) ||
        extra.contains(_searchQuery);
  }

  Widget _buildSearchAndCategoryBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search files, PDF notes or links...',
                hintStyle: const TextStyle(fontSize: 13.5, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (widget.isGroup) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _academicCategories.length,
                itemBuilder: (context, index) {
                  final cat = _academicCategories[index];
                  final bool isSelected = _selectedCategory == cat['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat['label']!,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.blueAccent.withOpacity(0.15),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.black54,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.transparent,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat['key']!);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaGalleryTab(List<MessageModel> mediaMessages) {
    if (mediaMessages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No Photos or Videos Found',
        subtitle: 'Images and videos shared in this batch will appear here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.88,
      ),
      itemCount: mediaMessages.length,
      itemBuilder: (context, index) {
        final item = mediaMessages[index];
        final bool isVideo = item.type.toLowerCase() == 'video';
        final String senderLabel = widget.isGroup
            ? item.getVisibleSenderName(
                currentUserId: widget.currentUserId,
                isViewerTeacherOfGroup: widget.isViewerTeacherOfGroup,
              )
            : (item.senderId == widget.currentUserId ? 'You' : 'Member');

        return GestureDetector(
          onTap: () {
            if (isVideo) {
              _openExternalUrl(item.content);
            } else {
              _showFullScreenImagePreview(item);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  Container(
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  )
                else
                  Image.network(
                    item.content,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.grey),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            senderLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.senderRole == 'teacher' &&
                            item.isSenderVerified)
                          const Icon(
                            Icons.verified,
                            color: Colors.blueAccent,
                            size: 12,
                          ),
                      ],
                    ),
                  ),
                ),
                if (item.messageCategory != 'general')
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.messageCategory
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
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

  Widget _buildDocumentsTab(List<MessageModel> docMessages) {
    if (docMessages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: 'No Study Documents Found',
        subtitle:
            'PDFs, notes, homework & assignments shared in the group will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: docMessages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = docMessages[index];
        final String fileName =
            (doc.mediaMetaData?['fileName'] ?? 'Study_Material_Document.pdf')
                .toString();
        final String ext = fileName.contains('.')
            ? fileName.split('.').last.toUpperCase()
            : 'PDF';
        final String senderLabel = widget.isGroup
            ? doc.getVisibleSenderName(
                currentUserId: widget.currentUserId,
                isViewerTeacherOfGroup: widget.isViewerTeacherOfGroup,
              )
            : (doc.senderId == widget.currentUserId ? 'You' : 'Member');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description_rounded,
                        color: Colors.redAccent, size: 22),
                    Text(
                      ext.length > 4 ? 'DOC' : ext,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'By $senderLabel',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: doc.senderRole == 'teacher'
                                    ? Colors.blueAccent
                                    : Colors.blueGrey,
                              ),
                            ),
                            if (doc.senderRole == 'teacher' &&
                                doc.isSenderVerified) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified,
                                  color: Colors.blueAccent, size: 13),
                            ],
                          ],
                        ),
                        if (doc.messageCategory != 'general')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doc.messageCategory
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(doc.timestamp),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Download / Open Document',
                icon: const Icon(
                  Icons.download_for_offline_rounded,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onPressed: () => _openExternalUrl(doc.content),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSharedLinksTab(List<MessageModel> linkMessages) {
    if (linkMessages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_off_rounded,
        title: 'No Shared Links Found',
        subtitle:
            'Web links, reference videos & study URLs shared in the chat will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: linkMessages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = linkMessages[index];
        final urls = _extractUrls(msg.content);
        final String primaryUrl = urls.isNotEmpty ? urls.first : msg.content;
        final String senderLabel = widget.isGroup
            ? msg.getVisibleSenderName(
                currentUserId: widget.currentUserId,
                isViewerTeacherOfGroup: widget.isViewerTeacherOfGroup,
              )
            : (msg.senderId == widget.currentUserId ? 'You' : 'Member');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openExternalUrl(primaryUrl),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public_rounded,
                          color: Colors.blueAccent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          primaryUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded,
                          color: Colors.blueAccent, size: 17),
                    ],
                  ),
                ),
              ),
              if (msg.content.trim() != primaryUrl.trim()) ...[
                const SizedBox(height: 8),
                Text(
                  msg.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Shared by $senderLabel',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: msg.senderRole == 'teacher'
                              ? Colors.blueAccent
                              : Colors.blueGrey,
                        ),
                      ),
                      if (msg.senderRole == 'teacher' &&
                          msg.isSenderVerified) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.verified,
                            color: Colors.blueAccent, size: 13),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(msg.timestamp),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Copy Link',
                    icon: const Icon(Icons.copy_rounded,
                        size: 17, color: Colors.grey),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: primaryUrl));
                      _showSnackBar('Link copied to clipboard!');
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.5,
              ),
            ),
            const Text(
              'Media Gallery, Study Docs & Shared Links',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<MessageModel>>(
        stream: _chatService.getSharedMediaDocsLinksStream(
          chatOrGroupId: widget.chatOrGroupId,
          isGroup: widget.isGroup,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final allMessages = snapshot.data ?? const [];

          final mediaItems = allMessages
              .where((m) =>
                  (m.type.toLowerCase() == 'image' ||
                      m.type.toLowerCase() == 'video') &&
                  _matchesCategoryAndSearch(m))
              .toList();

          final docItems = allMessages
              .where((m) =>
                  (m.type.toLowerCase() == 'document' ||
                      m.type.toLowerCase() == 'file') &&
                  _matchesCategoryAndSearch(m))
              .toList();

          final linkItems = allMessages.where((m) {
            if (m.type.toLowerCase() != 'text') return false;
            final urls = _extractUrls(m.content);
            if (urls.isEmpty) return false;
            return _matchesCategoryAndSearch(m,
                extraSearchText: urls.join(' '));
          }).toList();

          return Column(
            children: [
              Container(
                color: const Color(0xFF0F172A),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: 'Media (${mediaItems.length})'),
                    Tab(text: 'Docs (${docItems.length})'),
                    Tab(text: 'Links (${linkItems.length})'),
                  ],
                ),
              ),
              _buildSearchAndCategoryBar(),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMediaGalleryTab(mediaItems),
                    _buildDocumentsTab(docItems),
                    _buildSharedLinksTab(linkItems),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
