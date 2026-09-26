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
              final request = requests[index];
              return GenieDismissible(
                key: Key(request.id ?? index.toString()),
                onDismissed: () async {
                  // এখানে ডিসমিস করার পর ব্যাকএন্ড সার্ভিস কল করতে পারেন
                  // উদাহরণ: await followService.rejectFollowRequest(request.id);
                },
                child: FollowRequestTile(
                  followRequest: request,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// **macOS Genie (Funnel / Suck-in) Effect Dismissible Widget**
class GenieDismissible extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;

  const GenieDismissible({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  @override
  State<GenieDismissible> createState() => _GenieDismissibleState();
}

class _GenieDismissibleState extends State<GenieDismissible> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    setState(() {
      _isDismissing = true;
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDismissing) {
      return Dismissible(
        key: widget.key!,
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          _dismiss();
          return false; // Custom Genie animation সম্পন্ন হওয়ার অনুমতি দেয়া
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final val = _progress.value;
        return Opacity(
          opacity: (1 - val).clamp(0.0, 1.0),
          child: ClipPath(
            clipper: GenieClipper(progress: val),
            child: Transform(
              alignment: Alignment.bottomRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..scale(1.0 - (val * 0.7), 1.0 - (val * 0.95)),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class GenieClipper extends CustomClipper<Path> {
  final double progress;

  GenieClipper({required this.progress});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double topRightShift = size.width * progress * 0.8;
    double bottomRightShift = size.width * progress;

    path.moveTo(0, 0);
    path.lineTo(size.width - topRightShift, 0);
    
    // Curved Funnel Edge (macOS Genie Effect)
    path.quadraticBezierTo(
      size.width * (1 - progress * 0.5), 
      size.height * 0.5, 
      size.width - bottomRightShift, 
      size.height
    );

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant GenieClipper oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
