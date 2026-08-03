import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/services/bulletin_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BulletinService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = BulletinService(firestore: firestore);
  });

  test('falls back to the default message when no bulletin is set', () async {
    final text = await service.watch().first;
    expect(text, 'Let our service be a blessing to all who enter these gates.');
  });

  test('reflects the stored bulletin text', () async {
    await service.save('Doors open at 9am this Sunday.');
    final text = await service.watch().first;
    expect(text, 'Doors open at 9am this Sunday.');
  });

  test('falls back when the stored text is blank', () async {
    await service.save('   ');
    final text = await service.watch().first;
    expect(text, 'Let our service be a blessing to all who enter these gates.');
  });
}
