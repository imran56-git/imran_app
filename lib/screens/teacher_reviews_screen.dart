import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../models/rating_summary_model.dart';
import '../services/review_service.dart';
import '../services/rating_service.dart';
import '../widgets/rating_dialog_widget.dart';
import '../widgets/teacher_badge_widget.dart';

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

  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  bool _canWriteReview = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoadingReviews = true);
    try {
      final canReview = await _reviewService.canStudentReviewTeacher(
        studentId: widget.currentStudentId,
        teacherId: widget.teacherId,
      );

      final reviews = await _reviewService.getTeacherReviews(
        teacherId: widget.teacherId,
      );

      setState(() {
        _canWriteReview = canReview;
        _reviews = reviews;
      });
    } catch (e) {
      debugPrint("Error fetching reviews screen data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  void _openRatingDialog() {
    RatingDialogWidget.show(
      context,
      teacherName: widget.teacherName,
      teacherProfileUrl: widget.teacherProfileUrl,
      onSubmit: (rating, comment) async {
        final review = ReviewModel(
          id: '',
          teacherId: widget.teacherId,
          studentId: widget.currentStudentId,
          studentName: 'Verified Student',
          overallRating: rating,
          categories: CategoryRating(
            teaching: rating,
            behaviour: rating,
            communication: rating,
            knowledge: rating,
            punctuality: rating,
          ),
          comment: comment,
          createdAt: DateTime.now(),
        );

        await _reviewService.submitOrUpdateReview(review: review);
        await _fetchData();
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
          final summary = snapshot.data ?? RatingSummaryModel.initial(widget.teacherId);

          return RefreshIndicator(
            onRefresh: _fetchData,
            color: primaryColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Rating Overview Card
                  _buildSummaryHeader(summary, primaryColor),
                  const SizedBox(height: 20),

                  // Categorical Progress Breakdown
                  _buildCategoryBreakdown(summary, primaryColor),
                  const SizedBox(height: 24),

                  const Text(
                    'Student Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reviews List
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
                          'No reviews yet for ${widget.teacherName}.',
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
                summary.averageRating.toStringAsFixed(1),
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
                '${summary.totalReviews} Ratings',
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

  Widget _buildCategoryBreakdown(RatingSummaryModel summary, Color primaryColor) {
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
          _buildCategoryRow('Teaching Quality', summary.categoryAverages['teaching'] ?? 0.0),
          _buildCategoryRow('Behaviour', summary.categoryAverages['behaviour'] ?? 0.0),
          _buildCategoryRow('Communication', summary.categoryAverages['communication'] ?? 0.0),
          _buildCategoryRow('Knowledge', summary.categoryAverages['knowledge'] ?? 0.0),
          _buildCategoryRow('Punctuality', summary.categoryAverages['punctuality'] ?? 0.0),
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
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFF1F5F9),
                    child: Text(
                      review.studentName.isNotEmpty
                          ? review.studentName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E4C7A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
                  const SizedBox(width: 2),
                  Text(
                    review.overallRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
