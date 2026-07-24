import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum representing the 4 recurring yearly seasons for teacher ranking leaderboards.
enum SeasonName {
  spring,
  summer,
  autumn,
  winter;

  String toMapValue() {
    return name;
  }

  static SeasonName fromMapValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'summer':
        return SeasonName.summer;
      case 'autumn':
        return SeasonName.autumn;
      case 'winter':
        return SeasonName.winter;
      case 'spring':
      default:
        return SeasonName.spring;
    }
  }

  String get displayName {
    switch (this) {
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

/// Class representing the metadata of an active or historical ranking season.
class SeasonModel extends Equatable {
  final String id; // e.g., "2026_SPRING"
  final SeasonName name;
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const SeasonModel({
    required this.id,
    required this.name,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  /// Factory constructor to generate the current active season dynamically based on date
  factory SeasonModel.current() {
    final now = DateTime.now();
    final year = now.year;

    SeasonName name;
    DateTime start;
    DateTime end;

    if (now.month >= 3 && now.month <= 5) {
      name = SeasonName.spring;
      start = DateTime(year, 3, 1);
      end = DateTime(year, 5, 31, 23, 59, 59);
    } else if (now.month >= 6 && now.month <= 8) {
      name = SeasonName.summer;
      start = DateTime(year, 6, 1);
      end = DateTime(year, 8, 31, 23, 59, 59);
    } else if (now.month >= 9 && now.month <= 11) {
      name = SeasonName.autumn;
      start = DateTime(year, 9, 1);
      end = DateTime(year, 11, 30, 23, 59, 59);
    } else {
      name = SeasonName.winter;
      final startYear = now.month == 12 ? year : year - 1;
      final endYear = now.month == 12 ? year + 1 : year;
      start = DateTime(startYear, 12, 1);
      end = DateTime(endYear, 2, 28, 23, 59, 59);
    }

    final id = "${year}_${name.name.toUpperCase()}";

    return SeasonModel(
      id: id,
      name: name,
      year: year,
      startDate: start,
      endDate: end,
      isActive: true,
    );
  }

  factory SeasonModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return SeasonModel.fromMap(map, doc.id);
  }

  factory SeasonModel.fromMap(Map<String, dynamic> map, String docId) {
    return SeasonModel(
      id: docId,
      name: SeasonName.fromMapValue(map['name'] as String?),
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.toMapValue(),
      'year': year,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
    };
  }

  SeasonModel copyWith({
    String? id,
    SeasonName? name,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) {
    return SeasonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      year: year ?? this.year,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        year,
        startDate,
        endDate,
        isActive,
      ];
}
