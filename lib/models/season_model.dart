import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../constants/algorithm_config.dart';

enum SeasonName {
  season1,
  season2,
  spring,
  summer,
  autumn,
  winter;

  String toMapValue() {
    return name;
  }

  static SeasonName fromMapValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'season1':
      case 'season_1':
      case 's1':
        return SeasonName.season1;
      case 'season2':
      case 'season_2':
      case 's2':
        return SeasonName.season2;
      case 'spring':
        return SeasonName.spring;
      case 'summer':
        return SeasonName.summer;
      case 'autumn':
        return SeasonName.autumn;
      case 'winter':
        return SeasonName.winter;
      default:
        final month = DateTime.now().month;
        return (month >= 1 && month <= 6)
            ? SeasonName.season1
            : SeasonName.season2;
    }
  }

  String get displayName {
    switch (this) {
      case SeasonName.season1:
        return 'Season 1 (Jan - Jun)';
      case SeasonName.season2:
        return 'Season 2 (Jul - Dec)';
      case SeasonName.spring:
        return 'Spring Season';
      case SeasonName.summer:
        return 'Summer Season';
      case SeasonName.autumn:
        return 'Autumn Season';
      case SeasonName.winter:
        return 'Winter Season';
    }
  }
}

class SeasonModel extends Equatable {
  final String id;
  final SeasonName name;
  final int year;
  final int seasonNumber;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String status;
  final String ruleVersion;
  final bool isFinalized;
  final DateTime? finalizedAt;
  final bool promptBroadcastSent;

  const SeasonModel({
    required this.id,
    required this.name,
    required this.year,
    this.seasonNumber = 1,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.status = 'active',
    this.ruleVersion = AlgorithmConfig.currentRuleVersion,
    this.isFinalized = false,
    this.finalizedAt,
    this.promptBroadcastSent = false,
  });

  String get seasonId => id;

  factory SeasonModel.current() {
    return SeasonModel.forDate(DateTime.now());
  }

  factory SeasonModel.forDate(DateTime date) {
    final year = date.year;
    final isFirstHalf = date.month >= AlgorithmConfig.season1StartMonth &&
        date.month <= AlgorithmConfig.season1EndMonth;

    final name = isFirstHalf ? SeasonName.season1 : SeasonName.season2;
    final seasonNum = isFirstHalf ? 1 : 2;

    final start = isFirstHalf
        ? DateTime(year, 1, 1, 0, 0, 0)
        : DateTime(year, 7, 1, 0, 0, 0);
    final end = isFirstHalf
        ? DateTime(year, 6, 30, 23, 59, 59)
        : DateTime(year, 12, 31, 23, 59, 59);

    final id = "${year}_S$seasonNum";

    return SeasonModel(
      id: id,
      name: name,
      year: year,
      seasonNumber: seasonNum,
      startDate: start,
      endDate: end,
      isActive: true,
      status: 'active',
      ruleVersion: AlgorithmConfig.currentRuleVersion,
      isFinalized: false,
      promptBroadcastSent: false,
    );
  }

  factory SeasonModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return SeasonModel.fromMap(map, doc.id);
  }

  factory SeasonModel.fromMap(Map<String, dynamic> map, String docId) {
    final parsedName = SeasonName.fromMapValue(map['name'] as String?);
    final defaultNum = parsedName == SeasonName.season2 ? 2 : 1;
    final parsedActive = map['isActive'] ?? (map['status'] == 'active');

    return SeasonModel(
      id: docId.isNotEmpty ? docId : (map['seasonId'] ?? map['id'] ?? ''),
      name: parsedName,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      seasonNumber: (map['seasonNumber'] as num?)?.toInt() ?? defaultNum,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: parsedActive,
      status: map['status'] ?? (parsedActive ? 'active' : 'finalized'),
      ruleVersion: map['ruleVersion'] ?? AlgorithmConfig.currentRuleVersion,
      isFinalized: map['isFinalized'] ?? false,
      finalizedAt: (map['finalizedAt'] as Timestamp?)?.toDate(),
      promptBroadcastSent: map['promptBroadcastSent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seasonId': id,
      'name': name.toMapValue(),
      'year': year,
      'seasonNumber': seasonNumber,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'status': status,
      'ruleVersion': ruleVersion,
      'isFinalized': isFinalized,
      'finalizedAt':
          finalizedAt != null ? Timestamp.fromDate(finalizedAt!) : null,
      'promptBroadcastSent': promptBroadcastSent,
    };
  }

  SeasonModel copyWith({
    String? id,
    SeasonName? name,
    int? year,
    int? seasonNumber,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? status,
    String? ruleVersion,
    bool? isFinalized,
    DateTime? finalizedAt,
    bool? promptBroadcastSent,
  }) {
    return SeasonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      year: year ?? this.year,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      isFinalized: isFinalized ?? this.isFinalized,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      promptBroadcastSent: promptBroadcastSent ?? this.promptBroadcastSent,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        year,
        seasonNumber,
        startDate,
        endDate,
        isActive,
        status,
        ruleVersion,
        isFinalized,
        finalizedAt,
        promptBroadcastSent,
      ];
}
