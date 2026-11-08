import 'package:cloud_firestore/cloud_firestore.dart';

class TeachingScheduleModel {
  final String id;
  final String locationId;
  final String batchId;
  final String batchName;
  final String teacherId;
  final String dayOfWeek; // 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  final String slotType; // 'morning', 'afternoon', 'evening'
  final String startTime; // e.g., '07:00 AM' or '17:00'
  final String endTime; // e.g., '08:00 AM' or '18:00'
  final String subject;
  final String classLevel;
  final String recurrenceType; // 'weekly', 'biweekly', 'custom'
  final String status; // 'active', 'cancelled', 'holiday', 'rescheduled'
  final bool isTemporaryChange;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeachingScheduleModel({
    required this.id,
    required this.locationId,
    required this.batchId,
    this.batchName = '',
    required this.teacherId,
    required this.dayOfWeek,
    this.slotType = 'morning',
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.classLevel,
    String? recurrenceType,
    String? recurrence,
    this.status = 'active',
    this.isTemporaryChange = false,
    String? note,
    String? notes,
    this.createdAt,
    this.updatedAt,
  })  : recurrenceType = recurrenceType ?? recurrence ?? 'weekly',
        note = note ?? notes;

  /// Factory constructor to create a TeachingScheduleModel from a Firestore document
  factory TeachingScheduleModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return TeachingScheduleModel(
      id: docId,
      locationId: map['locationId']?.toString() ?? '',
      batchId: map['batchId']?.toString() ?? '',
      batchName: map['batchName']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      dayOfWeek: map['dayOfWeek']?.toString() ?? 'Monday',
      slotType: map['slotType']?.toString() ?? 'morning',
      startTime: map['startTime']?.toString() ?? '',
      endTime: map['endTime']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      classLevel: map['classLevel']?.toString() ?? '',
      recurrenceType: (map['recurrenceType'] ?? map['recurrence'])?.toString() ?? 'weekly',
      status: map['status']?.toString() ?? 'active',
      isTemporaryChange: map['isTemporaryChange'] is bool
          ? map['isTemporaryChange'] as bool
          : false,
      note: (map['note'] ?? map['notes'])?.toString(),
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  /// Converts this instance to a map compatible with Firestore
  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'batchId': batchId,
      'batchName': batchName,
      'teacherId': teacherId,
      'dayOfWeek': dayOfWeek,
      'slotType': slotType,
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'classLevel': classLevel,
      'recurrenceType': recurrenceType,
      'recurrence': recurrenceType,
      'status': status,
      'isTemporaryChange': isTemporaryChange,
      'note': note,
      'notes': note,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a copy of the model with updated fields
  TeachingScheduleModel copyWith({
    String? id,
    String? locationId,
    String? batchId,
    String? batchName,
    String? teacherId,
    String? dayOfWeek,
    String? slotType,
    String? startTime,
    String? endTime,
    String? subject,
    String? classLevel,
    String? recurrenceType,
    String? recurrence,
    String? status,
    bool? isTemporaryChange,
    String? note,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeachingScheduleModel(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      teacherId: teacherId ?? this.teacherId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      slotType: slotType ?? this.slotType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
      classLevel: classLevel ?? this.classLevel,
      recurrenceType: recurrenceType ?? recurrence ?? this.recurrenceType,
      status: status ?? this.status,
      isTemporaryChange: isTemporaryChange ?? this.isTemporaryChange,
      note: note ?? notes ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Backward-compatible Getters
  String? get notes => note;
  String get recurrence => recurrenceType;

  // Getters & Helper Methods
  String get displayTiming => '$startTime – $endTime';

  bool get isActive => status == 'active';

  /// Parses a time string (e.g. "07:30 AM", "7:30pm", "14:00") into minutes since midnight
  static int parseTimeToMinutes(String timeStr) {
    final cleanStr = timeStr.trim();
    if (cleanStr.isEmpty) return 0;

    final regex = RegExp(
      r'^\s*(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?\s*$',
      caseSensitive: false,
    );
    final match = regex.firstMatch(cleanStr);

    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final int minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final String? period = match.group(3)?.toUpperCase();

      if (period != null) {
        hours = hours % 12;
        if (period == 'PM') {
          hours += 12;
        }
      }

      return (hours * 60) + minutes;
    }

    return 0;
  }

  int get startMinutesSinceMidnight => parseTimeToMinutes(startTime);

  int get endMinutesSinceMidnight => parseTimeToMinutes(endTime);

  /// Checks if two schedules on the same dayOfWeek have overlapping time ranges
  bool overlapsWith(TeachingScheduleModel other) {
    if (dayOfWeek.trim().toLowerCase() != other.dayOfWeek.trim().toLowerCase()) {
      return false;
    }

    final s1 = startMinutesSinceMidnight;
    final e1 = endMinutesSinceMidnight;
    final s2 = other.startMinutesSinceMidnight;
    final e2 = other.endMinutesSinceMidnight;

    if (s1 >= e1 || s2 >= e2) {
      return false;
    }

    return s1 < e2 && s2 < e1;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeachingScheduleModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TeachingScheduleModel(id: $id, teacherId: $teacherId, locationId: $locationId, dayOfWeek: $dayOfWeek, timing: $displayTiming, status: $status)';
  }
}
