import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../models/rating_summary_model.dart';
import '../services/review_service.dart';
import '../services/rating_service.dart';
import '../widgets/rating_dialog_widget.dart';

class TeacherReviewsScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? teacherProfileUrl;
  final String currentStudentId;

  const TeacherReviewsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    this.teacherProfileUrl,
    required this.currentStudentId,
  });

  @override
  State<TeacherReviewsScreen> createState() => _TeacherReviewsScreenState();
}

class _TeacherReviewsScreenState extends State<TeacherReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  final RatingService _ratingService = RatingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  bool _canWriteReview = false;
  final Set<String> _expandedReviewIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<bool> _checkVerifiedStudentStatus() async {
    if (widget.currentStudentId.isEmpty || widget.teacherId.isEmpty) {
      return false;
    }
    if (widget.currentStudentId == widget.teacherId) {
      return false;
    }

    try {
      final reqSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: widget.teacherId)
          .where('senderId', isEqualTo: widget.currentStudentId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (reqSnap.docs.isNotEmpty) return true;

      final backupSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: widget.teacherId)
          .where('studentId', isEqualTo: widget.currentStudentId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (backupSnap.docs.isNotEmpty) return true;

      final connectedSnap = await _firestore
          .collection('teachers')
          .doc(widget.teacherId)
          .collection('connected_students')
          .doc(widget.currentStudentId)
          .get();

      if (connectedSnap.exists) return true;

      return await _reviewService.canStudentReviewTeacher(
        studentId: widget.currentStudentId,
        teacherId: widget.teacherId,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoadingReviews = true);
    try {
      final canReview = await _checkVerifiedStudentStatus();

      List<ReviewModel> reviews = await _reviewService.getTeacherReviews(
        teacherId: widget.teacherId,
        onlyVerified: false,
      );

      if (reviews.isEmpty) {
        final snap = await _firestore
            .collection('ratings')
            .where('teacherId', isEqualTo: widget.teacherId)
            .get();

        reviews = snap.docs.map((d) {
          final data = d.data();
          final rawCategories = data['categories'] as Map<String, dynamic>? ?? {};
          final Map<String, double> catMap = {};
          rawCategories.forEach((k, v) {
            if (v is num) catMap[k] = v.toDouble();
          });

          return ReviewModel(
            id: d.id,
            teacherId: (data['teacherId'] ?? widget.teacherId).toString(),
            studentId: (data['studentId'] ?? '').toString(),
            studentName: (data['studentName'] ?? data['name'] ?? 'Student').toString(),
            studentPhotoUrl: (data['studentPhotoUrl'] ?? data['studentPhoto'] ?? data['profileImageUrl'] ?? '').toString(),
            overallRating: (data['overallRating'] ?? data['rating'] as num?)?.toDouble() ?? 5.0,
            categories: catMap,
            comment: (data['comment'] ?? data['review'] ?? '').toString(),
            createdAt: (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
          );
        }).toList();

        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      if (mounted) {
        setState(() {
          _canWriteReview = canReview;
          _reviews = reviews;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reviews screen data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  void _openStudentProfile(String studentId, String fallbackName) async {
    if (studentId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('students').doc(studentId).get(),
        builder: (context, snapshot) {
          Map<String, dynamic>? data;
          if (snapshot.hasData && snapshot.data!.exists) {
            data = snapshot.data!.data() as Map<String, dynamic>?;
          }

          final String name = (data?['name'] ?? data?['fullName'] ?? fallbackName).toString();
          final String pic = (data?['profileImageUrl'] ?? data?['profilePic'] ?? data?['photoUrl'] ?? '').toString();
          final String className = (data?['className'] ?? data?['studentClass'] ?? data?['class'] ?? 'Student').toString();
          final String uid = (data?['uid'] ?? data?['fybttUid'] ?? studentId).toString();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 18),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFEFF6FF),
                  backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
                  child: pic.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E4C7A),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Verified Student',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'UID: $uid',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Academic Class: $className',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openFullScreenImage(String url, String title) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.96),
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
            body: SizedBox.expand(
              child: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(100),
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRatingDialog() async {
    String studentName = 'Student';
    String studentPhotoUrl = '';

    try {
      var studentDoc = await _firestore
          .collection('students')
          .doc(widget.currentStudentId)
          .get();
      if (!studentDoc.exists || studentDoc.data() == null) {
        studentDoc = await _firestore
            .collection('users')
            .doc(widget.currentStudentId)
            .get();
      }

      if (studentDoc.exists && studentDoc.data() != null) {
        final data = studentDoc.data()!;
        studentName =
            (data['fullName'] ?? data['name'] ?? 'Student').toString();
        studentPhotoUrl = (data['profileImageUrl'] ??
                data['profilePic'] ??
                data['photoUrl'] ??
                '')
            .toString();
      }
    } catch (_) {}

    if (!mounted) return;

    RatingDialogWidget.show(
      context,
      teacherName: widget.teacherName,
      teacherProfileUrl: widget.teacherProfileUrl,
      onSubmit: (overallRating, categories, comment) async {
        final String docId = '${widget.teacherId}_${widget.currentStudentId}';

        final review = ReviewModel(
          id: docId,
          teacherId: widget.teacherId,
          studentId: widget.currentStudentId,
          studentName: studentName,
          studentPhotoUrl: studentPhotoUrl,
          overallRating: overallRating,
          categories: categories,
          comment: comment,
          createdAt: DateTime.now(),
        );

        final success =
            await _reviewService.submitOrUpdateReview(review: review);

        await _firestore.collection('ratings').doc(docId).set({
          'teacherId': widget.teacherId,
          'studentId': widget.currentStudentId,
          'studentName': studentName,
          'studentPhotoUrl': studentPhotoUrl,
          'overallRating': overallRating,
          'categories': categories,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (success || mounted) {
          await _fetchData();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E4C7A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Reviews & Ratings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      floatingActionButton: _canWriteReview
          ? FloatingActionButton.extended(
              onPressed: _openRatingDialog,
              backgroundColor: primaryColor,
              icon: const Icon(Icons.rate_review_rounded, color: Colors.white),
              label: const Text(
                'Write Review',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: StreamBuilder<RatingSummaryModel>(
        stream: _ratingService.streamTeacherRatingSummary(widget.teacherId),
        builder: (context, snapshot) {
          final summary =
              snapshot.data ?? RatingSummaryModel.initial(widget.teacherId);

          return RefreshIndicator(
            onRefresh: _fetchData,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryHeader(summary, primaryColor),
                  const SizedBox(height: 20),
                  _buildCategoryBreakdown(summary, primaryColor),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Verified Student Reviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '(${_reviews.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingReviews)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    )
                  else if (_reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No verified reviews yet for ${widget.teacherName}.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        return _buildReviewTile(review, primaryColor);
                      },
                    ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(RatingSummaryModel summary, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                summary.publicRatingDisplay,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < summary.averageRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB300),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.verifiedReviewsCount} Verified Reviews',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final starNum = 5 - index;
                final count = summary.starDistribution[starNum] ?? 0;
                final pct = summary.totalReviews > 0
                    ? count / summary.totalReviews
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$starNum',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFFFB300)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: primaryColor,
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      RatingSummaryModel summary, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryRow('Teaching Quality',
              summary.categoryAverages['teaching'] ?? 0.0),
          _buildCategoryRow(
              'Behaviour', summary.categoryAverages['behaviour'] ?? 0.0),
          _buildCategoryRow('Communication',
              summary.categoryAverages['communication'] ?? 0.0),
          _buildCategoryRow(
              'Knowledge', summary.categoryAverages['knowledge'] ?? 0.0),
          _buildCategoryRow(
              'Punctuality', summary.categoryAverages['punctuality'] ?? 0.0),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB300)),
              const SizedBox(width: 4),
              Text(
                score.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(ReviewModel review, Color primaryColor) {
    final String reviewKey = review.id.isNotEmpty ? review.id : '${review.studentId}_${review.createdAt.millisecondsSinceEpoch}';
    final bool isExpanded = _expandedReviewIds.contains(reviewKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _openStudentProfile(review.studentId, review.studentName),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEFF6FF),
                        backgroundImage: (review.studentPhotoUrl.isNotEmpty)
                            ? NetworkImage(review.studentPhotoUrl)
                            : null,
                        child: (review.studentPhotoUrl.isEmpty)
                            ? Text(
                                review.studentName.isNotEmpty
                                    ? review.studentName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E4C7A),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _openStudentProfile(review.studentId, review.studentName),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 3),
                    Text(
                      review.overallRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ],
          if (review.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedReviewIds.remove(reviewKey);
                  } else {
                    _expandedReviewIds.add(reviewKey);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? 'Hide Category Ratings' : 'View Detailed Breakdown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: review.categories.entries.map((entry) {
                    final keyName = entry.key[0].toUpperCase() + entry.key.substring(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            keyName,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB300)),
                              const SizedBox(width: 2),
                              Text(
                                entry.value.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
