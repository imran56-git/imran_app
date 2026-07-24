import 'package:flutter/material.dart';
import '../services/season_service.dart';
import '../widgets/leaderboard_card_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SeasonService _seasonService = SeasonService();

  bool _isLoading = true;
  String _currentSeasonName = 'Loading...';
  String _currentSeasonId = '';
  List<Map<String, dynamic>> _seasonalLeaderboard = [];
  List<Map<String, dynamic>> _lifetimeLeaderboard = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeaderboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentSeason = await _seasonService.getCurrentActiveSeason();
      _currentSeasonName = currentSeason.name.displayName;
      _currentSeasonId = currentSeason.id;

      final seasonalData = await _seasonService.getSeasonLeaderboard(
        seasonId: _currentSeasonId,
      );

      final lifetimeData = await _seasonService.getLifetimeLeaderboard();

      setState(() {
        _seasonalLeaderboard = seasonalData;
        _lifetimeLeaderboard = lifetimeData;
      });
    } catch (e) {
      debugPrint("Error loading leaderboard screen: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E4C7A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Teacher Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          tabs: [
            Tab(
              text: 'Seasonal ($_currentSeasonName)',
            ),
            const Tab(
              text: 'Lifetime Champions',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Seasonal Leaderboard Tab
                _buildLeaderboardList(
                  items: _seasonalLeaderboard,
                  emptyMessage: 'No seasonal ratings recorded yet for $_currentSeasonName.',
                  isSeasonal: true,
                ),

                // Lifetime Leaderboard Tab
                _buildLeaderboardList(
                  items: _lifetimeLeaderboard,
                  emptyMessage: 'No lifetime leaderboard data available yet.',
                  isSeasonal: false,
                ),
              ],
            ),
    );
  }

  Widget _buildLeaderboardList({
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
    required bool isSeasonal,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboardData,
      color: const Color(0xFF1E4C7A),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final data = items[index];
          final double rating = isSeasonal
              ? (data['seasonalRating'] as num?)?.toDouble() ?? 0.0
              : (data['allTimeRating'] as num?)?.toDouble() ?? 0.0;

          return LeaderboardCardWidget(
            rank: index + 1,
            teacherName: data['teacherName'] ?? 'Unknown Teacher',
            profileImageUrl: data['profileImageUrl'],
            badgeType: data['highestBadgeType'] ?? 'verified',
            rating: rating,
            reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
            onTap: () {
              // Navigate to Teacher Details Profile if needed
            },
          );
        },
      ),
    );
  }
}
