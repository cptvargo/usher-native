import 'package:cloud_firestore/cloud_firestore.dart';

/// A single service headcount entry from the `attendance` collection.
class AttendanceLog {
  const AttendanceLog({
    required this.id,
    required this.headcount,
    required this.serviceType,
    required this.submittedBy,
    this.notes,
    this.createdAt,
  });

  factory AttendanceLog.fromMap(String id, Map<String, dynamic> data) {
    return AttendanceLog(
      id: id,
      headcount: (data['headcount'] as num?)?.toInt() ?? 0,
      serviceType: (data['serviceType'] as String?) ?? 'Service',
      submittedBy: (data['submittedBy'] as String?) ?? 'Anonymous',
      notes: (data['notes'] as String?)?.trim().isNotEmpty == true
          ? data['notes'] as String
          : null,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  final String id;
  final int headcount;
  final String serviceType;
  final String submittedBy;
  final String? notes;
  final DateTime? createdAt;
}

/// `createdAt` is normally an ISO string, but some records store a
/// Firestore [Timestamp] instead — accept either (see RosterMember for the
/// same issue with older `team` docs).
DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
