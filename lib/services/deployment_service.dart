import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deployment.dart';

class DeploymentService {
  DeploymentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// This usher's assignments from today onward, soonest first.
  Stream<List<Deployment>> watchUpcoming(String usherId) {
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _firestore
        .collection('deployments')
        .where('usherId', isEqualTo: usherId)
        .where('date', isGreaterThanOrEqualTo: todayIso)
        .orderBy('date')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Deployment.fromMap(d.id, d.data())).toList());
  }
}
