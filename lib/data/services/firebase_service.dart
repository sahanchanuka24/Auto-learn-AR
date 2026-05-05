import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import "package:flutter/foundation.dart";
class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // Save task result after completion
  static Future<void> saveTaskResult({
    required String taskId,
    required String taskTitle,
    required String component,
    required int totalSteps,
    required int completedSteps,
    required int timeTakenSeconds,
    required List<String> safetyWarnings,
  }) async {
    if (_uid == null) return;

    final score = ((completedSteps / totalSteps) * 100).toInt();

    try {
      // Save individual result
      await _db
          .collection('users')
          .doc(_uid)
          .collection('results')
          .add({
        'taskId': taskId,
        'taskTitle': taskTitle,
        'component': component,
        'totalSteps': totalSteps,
        'completedSteps': completedSteps,
        'score': score,
        'timeTakenSeconds': timeTakenSeconds,
        'safetyWarnings': safetyWarnings,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update user summary
      await _db.collection('users').doc(_uid).update({
        'completedTasks': FieldValue.arrayUnion([taskId]),
        'totalScore': FieldValue.increment(score),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      debugPrint('Task result saved successfully');
    } catch (e) {
      debugPrint('Error saving task result: $e');
    }
  }

  // Get all results for current user
  static Future<List<Map<String, dynamic>>> getUserResults() async {
    if (_uid == null) return [];

    try {
      final snapshot = await _db
          .collection('users')
          .doc(_uid)
          .collection('results')
          .orderBy('completedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      debugPrint('Error getting results: $e');
      return [];
    }
  }

  // Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (_uid == null) return null;

    try {
      final doc = await _db.collection('users').doc(_uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return null;
    }
  }

  // Check if task was completed before
  static Future<bool> isTaskCompleted(String taskId) async {
    if (_uid == null) return false;

    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final data = doc.data();
      if (data == null) return false;
      final completedTasks = List<String>.from(
          data['completedTasks'] ?? []);
      return completedTasks.contains(taskId);
    } catch (e) {
      return false;
    }
  }

  // Get best score for a task
  static Future<int?> getBestScore(String taskId) async {
    if (_uid == null) return null;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(_uid)
          .collection('results')
          .where('taskId', isEqualTo: taskId)
          .orderBy('score', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data()['score'] as int?;
    } catch (e) {
      return null;
    }
  }
}