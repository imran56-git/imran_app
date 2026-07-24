import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // 1. Give New Rating
  // ---------------------------------------------------------------------------
  Future<void> giveRating({
    required String teacherId,
    required String studentId,
    required double stars,
    required String review,
  }) async {
    // Check if student is verified for this teacher
    bool isVerified = await isStudentVerified(teacherId, studentId);

    if (!isVerified) {
      throw Exception('Only verified students can rate and review.');
    }

    String currentSeason = RatingModel.getCurrentSeason();
    DocumentReference ratingRef = _db.collection('ratings').doc();

    RatingModel newRating = RatingModel(
      ratingId: ratingRef.id,
      teacherId: teacherId,
      studentId: studentId,
      stars: stars,
      review: review,
      createdAt: DateTime.now(),
      season: currentSeason,
      isVerified: true,
    );

    // Batch write to update Rating, Student's rated list, and Recalculate Teacher stats
    WriteBatch batch = _db.batch();
    batch.set(ratingRef, newRating.toMap());

    // Update Student's rated list
    DocumentReference studentRef = _db.collection('students').doc(studentId);
    batch.update(studentRef, {
      'ratedTeachers': FieldValue.arrayUnion([teacherId]),
    });

    await batch.commit();

    // Recalculate ratings for the teacher
    await calculateTeacherRating(teacherId);
  }

  // ---------------------------------------------------------------------------
  // 2. Update Existing Rating
  // ---------------------------------------------------------------------------
  Future<void> updateRating({
    required String ratingId,
    required String teacherId,
    required double stars,
    required String review,
  }) async {
    await _db.collection('ratings').doc(ratingId).update({
      'stars': stars,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await calculateTeacherRating(teacherId);
  }

  // ---------------------------------------------------------------------------
  // 3. Delete Rating
  // ---------------------------------------------------------------------------
  Future<void> deleteRating({
    required String ratingId,
    required String teacherId,
    required String studentId,
  }) async {
    WriteBatch batch = _db.batch();

    batch.delete(_db.collection('ratings').doc(ratingId));

    DocumentReference studentRef = _db.collection('students').doc(studentId);
    batch.update(studentRef, {
      'ratedTeachers': FieldValue.arrayRemove([teacherId]),
    });

    await batch.commit();

    await calculateTeacherRating(teacherId);
  }

  // ---------------------------------------------------------------------------
  // 4. Calculate & Sync Teacher Rating (Current Season & All-Time)
  // ---------------------------------------------------------------------------
  Future<void> calculateTeacherRating(String teacherId) async {
    String currentSeason = RatingModel.getCurrentSeason();

    // Fetch all ratings for this teacher
    QuerySnapshot snapshot = await _db
        .collection('ratings')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    if (snapshot.docs.isEmpty) {
      await _db.collection('teachers').doc(teacherId).update({
        'averageRating': 0.0,
        'ratingCount': 0,
        'reviewCount': 0,
        'lastSeasonRating': 0.0,
        'allTimeRating': 0.0,
        'currentSeason': currentSeason,
      });
      return;
    }

    double totalAllTimeStars = 0.0;
    int totalAllTimeCount = snapshot.docs.length;

    double totalCurrentSeasonStars = 0.0;
    int currentSeasonCount = 0;

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      double stars = (data['stars'] as num).toDouble();
      String season = data['season'] ?? '';

      totalAllTimeStars += stars;

      if (season == currentSeason) {
        totalCurrentSeasonStars += stars;
        currentSeasonCount++;
      }
    }

    double allTimeAvg = totalAllTimeStars / totalAllTimeCount;
    double currentSeasonAvg = currentSeasonCount > 0
        ? totalCurrentSeasonStars / currentSeasonCount
        : 0.0;

    // Update teacher document
    await _db.collection('teachers').doc(teacherId).update({
      'averageRating': double.parse(currentSeasonAvg.toStringAsFixed(1)),
      'ratingCount': currentSeasonCount,
      'reviewCount': totalAllTimeCount,
      'allTimeRating': double.parse(allTimeAvg.toStringAsFixed(1)),
      'currentSeason': currentSeason,
    });

    // Update rating summary doc in teacher_rating_summary collection
    await _db.collection('teacher_rating_summary').doc(teacherId).set({
      'teacherId': teacherId,
      'currentSeasonRating': double.parse(currentSeasonAvg.toStringAsFixed(1)),
      'currentSeasonCount': currentSeasonCount,
      'allTimeRating': double.parse(allTimeAvg.toStringAsFixed(1)),
      'allTimeCount': totalAllTimeCount,
      'season': currentSeason,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // 5. Verify Student
  // ---------------------------------------------------------------------------
  Future<void> verifyStudent({
    required String teacherId,
    required String studentId,
  }) async {
    WriteBatch batch = _db.batch();

    // Add to verified_students subcollection or document
    DocumentReference verifyRef = _db
        .collection('verified_students')
        .doc(teacherId)
        .collection('students')
        .doc(studentId);

    batch.set(verifyRef, {
      'studentId': studentId,
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    // Update student's verifiedTeacherIds list
    DocumentReference studentRef = _db.collection('students').doc(studentId);
    batch.update(studentRef, {
      'verifiedTeacherIds': FieldValue.arrayUnion([teacherId]),
    });

    // Update teacher's verifiedStudents count
    DocumentReference teacherRef = _db.collection('teachers').doc(teacherId);
    batch.update(teacherRef, {
      'verifiedStudents': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Check if student is verified
  Future<bool> isStudentVerified(String teacherId, String studentId) async {
    DocumentSnapshot doc = await _db
        .collection('verified_students')
        .doc(teacherId)
        .collection('students')
        .doc(studentId)
        .get();

    return doc.exists;
  }

  // ---------------------------------------------------------------------------
  // 6. Teacher Reply to Review
  // ---------------------------------------------------------------------------
  Future<void> replyToReview({
    required String ratingId,
    required String replyText,
  }) async {
    await _db.collection('ratings').doc(ratingId).update({
      'teacherReply': replyText,
      'teacherReplyTime': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // 7. Get Reviews Stream for a Teacher
  // ---------------------------------------------------------------------------
  Stream<List<RatingModel>> getTeacherReviews(String teacherId) {
    return _db
        .collection('ratings')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ---------------------------------------------------------------------------
  // 8. Fetch Single Student Rating for a Specific Teacher (if exists)
  // ---------------------------------------------------------------------------
  Future<RatingModel?> getStudentRatingForTeacher({
    required String teacherId,
    required String studentId,
  }) async {
    QuerySnapshot snapshot = await _db
        .collection('ratings')
        .where('teacherId', isEqualTo: teacherId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return RatingModel.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>,
        snapshot.docs.first.id,
      );
    }
    return null;
  }
}
