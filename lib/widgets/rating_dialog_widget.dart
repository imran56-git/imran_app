import 'package:flutter/material.dart';

class RatingDialogWidget extends StatefulWidget {
  final String teacherName;
  final String? teacherProfileUrl;
  final Future<void> Function(double rating, String comment) onSubmit;

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
    required Future<void> Function(double rating, String comment) onSubmit,
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
  double _selectedRating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('দয়া করে রেটিং নির্বাচন করুন (১-৫ স্টার)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(_selectedRating, _commentController.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('আপনার রিভিউ সফলভাবে জমা দেওয়া হয়েছে!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('রিভিউ জমা দেওয়া সম্ভব হয়নি: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E4C7A);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: (widget.teacherProfileUrl != null &&
                        widget.teacherProfileUrl!.isNotEmpty)
                    ? NetworkImage(widget.teacherProfileUrl!)
                    : null,
                child: (widget.teacherProfileUrl == null ||
                        widget.teacherProfileUrl!.isEmpty)
                    ? const Icon(Icons.person_rounded,
                        size: 40, color: primaryColor)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                widget.teacherName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'শিক্ষককে কেমন রেটিং দিতে চান?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1.0;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _selectedRating >= starValue
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: _selectedRating >= starValue
                          ? const Color(0xFFFFB300)
                          : Colors.grey.shade400,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRating = starValue;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Review Comment Input Box
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 250,
                decoration: InputDecoration(
                  hintText: 'আপনার মতামত লিখুন (ঐচ্ছিক)...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'বাতিল',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
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
                              'জমা দিন',
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
    );
  }
}
