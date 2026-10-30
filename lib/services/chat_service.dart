Future<Map<String, dynamic>?> getUserProfile(
      String userId, bool isTeacher) async {
    if (userId.trim().isEmpty) return null;
    try {
      final String primaryCollection = isTeacher ? 'teachers' : 'students';
      final String secondaryCollection = isTeacher ? 'students' : 'teachers';

      var doc =
          await _firestore.collection(primaryCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) return doc.data();

      doc = await _firestore.collection(secondaryCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) return doc.data();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      _handleError('getUserProfile', e);
      return null;
    }
  }