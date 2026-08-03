import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_log.dart';

/// Manages the `attendance` collection: submitting a new service headcount
/// and viewing/editing/deleting the history log.
class AttendanceService {
  AttendanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _attendance =>
      _firestore.collection('attendance');

  Stream<List<AttendanceLog>> watchLogs() {
    return _attendance
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AttendanceLog.fromMap(d.id, d.data())).toList());
  }

  Future<void> addLog({
    required int headcount,
    required String serviceType,
    required String notes,
    required String submittedBy,
  }) {
    return _attendance.add({
      'headcount': headcount,
      'serviceType': serviceType,
      'notes': notes,
      'submittedBy': submittedBy,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateLog(String id, {required int headcount, required String notes}) {
    return _attendance.doc(id).update({
      'headcount': headcount,
      'notes': notes,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteLog(String id) => _attendance.doc(id).delete();
}
