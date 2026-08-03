import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/team_profile.dart';

/// Resolves a signed-in user's `team` roster entry, following `linkedTo`
/// when the signed-in account is a secondary login (e.g. a phone number)
/// linked to a primary email record.
class TeamService {
  TeamService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _team =>
      _firestore.collection('team');

  Stream<TeamProfile?> watchProfile(String uid) {
    return _team.doc(uid).snapshots().asyncMap((snap) async {
      final data = snap.data();
      if (data == null) return null;

      final linkedTo = data['linkedTo'] as String?;
      if (linkedTo == null) return TeamProfile.fromMap(snap.id, data);

      final primary = await _team.doc(linkedTo).get();
      final primaryData = primary.data();
      if (primaryData == null) return null;
      return TeamProfile.fromMap(primary.id, primaryData);
    });
  }
}
