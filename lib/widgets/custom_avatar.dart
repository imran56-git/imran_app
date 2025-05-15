import 'package:flutter/material.dart';

class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;

  const CustomAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 24,
  });

  Color _getColorFromName(String name) {
    final colors = [
      Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple,
      Colors.teal, Colors.indigo, Colors.cyan, Colors.deepOrange, Colors.amber,
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _getColorFromName(name),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }
}