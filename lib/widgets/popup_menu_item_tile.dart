import 'package:flutter/material.dart';

class PopupMenuItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? textColor;
  final VoidCallback? onTap;

  const PopupMenuItemTile({
    super.key,
    required this.icon,
    required this.title,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: textColor ?? Colors.black87,
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
