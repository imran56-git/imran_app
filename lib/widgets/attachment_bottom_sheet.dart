import 'package:flutter/material.dart';

class AttachmentBottomSheet extends StatelessWidget {
  final VoidCallback onDocumentTap;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onAudioTap;
  final VoidCallback onLocationTap;
  final VoidCallback onContactTap;

  const AttachmentBottomSheet({
    super.key,
    required this.onDocumentTap,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onAudioTap,
    required this.onLocationTap,
    required this.onContactTap,
  });

  Widget _buildItem(BuildContext context, IconData icon, Color color, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 20,
            crossAxisSpacing: 10,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildItem(context, Icons.insert_drive_file, const Color(0xFF7F66FF), 'Document', onDocumentTap),
              _buildItem(context, Icons.camera_alt, const Color(0xFFFF4573), 'Camera', onCameraTap),
              _buildItem(context, Icons.image, const Color(0xFF1976D2), 'Gallery', onGalleryTap),
              _buildItem(context, Icons.headset, const Color(0xFFF57C00), 'Audio', onAudioTap),
              _buildItem(context, Icons.location_on, const Color(0xFF009688), 'Location', onLocationTap),
              _buildItem(context, Icons.person, const Color(0xFF00ACC1), 'Contact', onContactTap),
            ],
          ),
        ],
      ),
    );
  }
}
