import 'package:flutter/material.dart';

class BadgeWidget extends StatelessWidget {
  final String badgeCode;
  final double size;

  const BadgeWidget({super.key, required this.badgeCode, this.size = 40});

  @override
  Widget build(BuildContext context) {
    String imagePath = '';
    switch (badgeCode) {
      case 'K':
        imagePath = 'assets/badges/k_badge.png';
        break;
      case 'B':
        imagePath = 'assets/badges/b_badge.png';
        break;
      case 'M':
        imagePath = 'assets/badges/m_badge.png';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Image.asset(
      imagePath,
      width: size,
      height: size,
    );
  }
}