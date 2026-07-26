import 'package:flutter/material.dart';
import '../models/follow_model.dart';
import '../services/follow_service.dart';
import '../widgets/follow_request_tile.dart';

class TeacherFollowRequestsScreen extends StatelessWidget {
  final String teacherId;

  const TeacherFollowRequestsScreen({
    super.key,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context) {
    final FollowService followService = FollowService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow Requests'),
        elevation: 0,
      ),
      body: StreamBuilder<List<FollowModel>>(
        stream: followService.getPendingRequests(teacherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No pending follow requests',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: requests.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              return FollowRequestTile(
                followRequest: requests[index],
              );
            },
          );
        },
      ),
    );
  }
}
