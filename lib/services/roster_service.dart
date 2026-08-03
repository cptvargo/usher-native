import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/roster_member.dart';

/// Manages the `team` collection for roster/admin screens: the active
/// approved roster, pending registrations awaiting approval, and lead/admin
/// CRUD on individual members.
class RosterService {
  RosterService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _team =>
      _firestore.collection('team');

  /// Approved members, excluding secondary (`linkedTo`) accounts, sorted
  /// by name — matches the original web roster listing.
  Stream<List<RosterMember>> watchActiveRoster() {
    return _team.where('approved', isEqualTo: true).snapshots().map((snap) {
      final members = snap.docs
          .map((d) => RosterMember.fromMap(d.id, d.data()))
          .where((m) => m.linkedTo == null)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return members;
    });
  }

  /// Registrations still awaiting approval/denial.
  Stream<List<RosterMember>> watchPendingRegistrations() {
    return _team
        .where('approved', isEqualTo: false)
        .where('denied', isEqualTo: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RosterMember.fromMap(d.id, d.data())).toList());
  }

  Future<void> approve(String id) =>
      _team.doc(id).update({'approved': true, 'denied': false});

  Future<void> deny(String id) =>
      _team.doc(id).update({'approved': false, 'denied': true});

  Future<void> addUsher({
    required String name,
    required String phone,
    required String role,
  }) {
    return _team.add({
      'name': name,
      'phone': phone,
      'role': role,
      'approved': true,
      'denied': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateUsher(
    String id, {
    required String name,
    required String phone,
    required String role,
  }) {
    return _team.doc(id).update({
      'name': name,
      'phone': phone,
      'role': role,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteUsher(String id) => _team.doc(id).delete();
}
