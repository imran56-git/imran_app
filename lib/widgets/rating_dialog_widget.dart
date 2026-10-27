import 'package:flutter/material.dart';
import '../models/review_model.dart';

class RatingDialogWidget extends StatefulWidget {
  final String teacherName;
  final String? teacherProfileUrl;
  final Future<void> Function(
    double overallRating,
    CategoryRating categories,
    String comment,
  ) onSubmit;

  const RatingDialogWidget({
    super.key,
    required this.teacherName,
    this.teacherProfileUrl,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String teacherName,
    String? teacherProfileUrl,
    required Future<void> Function(
      double overallRating,
      CategoryRating categories,
      String comment,
    ) onSubmit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialogWidget(
        teacherName: teacherName,
        teacherProfileUrl: teacherProfileUrl,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<RatingDialogWidget> createState() => _RatingDialogWidgetState();
}

class _RatingDialogWidgetState extends State<RatingDialogWidget> {
  final TextEditingController _commentController = TextEditingController();

  double _teaching = 5.0;
  double _behaviour = 5.0;
  double _communication = 5.0;
  double _knowledge = 5.0;
  double _punctuality = 5.0;

  bool _isSubmitting = false;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _starYellow = Color(0xFFFFB300);

  double get _calculatedOverallRating {
    final avg = (_teaching + _behaviour + _communication + _knowledge + _punctuality) / 5.0;
    return double.parse(avg.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      final categories = CategoryRating(
        teaching: _teaching,
        behaviour: _behaviour,
        communication: _communication,
        knowledge: _knowledge,
        punctuality: _punctuality,
      );

      await widget.onSubmit(
        _calculatedOverallRating,
        categories,
        _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your review has been submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildCategoryStarPicker({
    required String label,
    required double currentRating,
    required ValueChanged<double> onRatingChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starVal = index + 1.0;
              final isFilled = currentRating >= starVal;
              return GestureDetector(
                onTap: () => onRatingChanged(starVal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFilled ? _starYellow : const Color(0xFFCBD5E1),
                    size: 24,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String initial = widget.teacherName.trim().isNotEmpty
        ? widget.teacherName.trim()[0].toUpperCase()
        : 'T';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.teacherProfileUrl != null &&
                        widget.teacherProfileUrl!.isNotEmpty) {
                      _openFullScreenImage(
                          widget.teacherProfileUrl!, widget.teacherName);
                    }
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: (widget.teacherProfileUrl != null &&
                            widget.teacherProfileUrl!.isNotEmpty)
                        ? NetworkImage(widget.teacherProfileUrl!)
                        : null,
                    child: (widget.teacherProfileUrl == null ||
                            widget.teacherProfileUrl!.isEmpty)
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _brandBlue,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.teacherName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primaryNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_calculatedOverallRating Average',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Performance Breakdown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _buildCategoryStarPicker(
                  label: 'Teaching Quality',
                  currentRating: _teaching,
                  onRatingChanged: (val) => setState(() => _teaching = val),
                ),
                _buildCategoryStarPicker(
                  label: 'Behaviour',
                  currentRating: _behaviour,
                  onRatingChanged: (val) => setState(() => _behaviour = val),
                ),
                _buildCategoryStarPicker(
                  label: 'Communication',
                  currentRating: _communication,
                  onRatingChanged: (val) =>
                      setState(() => _communication = val),
                ),
                _buildCategoryStarPicker(
                  label: 'Knowledge',
                  currentRating: _knowledge,
                  onRatingChanged: (val) => setState(() => _knowledge = val),
                ),
                _buildCategoryStarPicker(
                  label: 'Punctuality',
                  currentRating: _punctuality,
                  onRatingChanged: (val) =>
                      setState(() => _punctuality = val),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  maxLength: 250,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _primaryNavy,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your academic experience / review (optional)...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(12),
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
                      borderSide:
                          const BorderSide(color: _brandBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit Review',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
