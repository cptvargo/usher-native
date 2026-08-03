import 'package:cloud_firestore/cloud_firestore.dart';

const _kFallbackBulletin =
    'Let our service be a blessing to all who enter these gates.';

/// Reads/writes the single shared service bulletin at
/// `content/service_bulletin`.
class BulletinService {
  BulletinService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('content').doc('service_bulletin');

  Stream<String> watch() {
    return _doc.snapshots().map((snap) {
      final text = snap.data()?['text'] as String?;
      return (text == null || text.trim().isEmpty) ? _kFallbackBulletin : text;
    });
  }

  Future<void> save(String text) => _doc.set({'text': text});
}
