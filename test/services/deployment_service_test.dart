import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/services/deployment_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DeploymentService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DeploymentService(firestore: firestore);
  });

  String isoDaysFromNow(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  test('only returns this usher\'s deployments from today onward, ordered by date',
      () async {
    await firestore.collection('deployments').add({
      'usherId': 'uid-1',
      'date': isoDaysFromNow(-1), // yesterday — excluded
      'serviceType': 'Sunday Morning',
    });
    await firestore.collection('deployments').add({
      'usherId': 'uid-1',
      'date': isoDaysFromNow(7),
      'serviceType': 'Sunday Morning',
      'station': 'Sanctuary',
    });
    await firestore.collection('deployments').add({
      'usherId': 'uid-1',
      'date': isoDaysFromNow(1),
      'serviceType': 'Events',
      'customEventName': 'Youth Night',
    });
    await firestore.collection('deployments').add({
      'usherId': 'someone-else',
      'date': isoDaysFromNow(2),
      'serviceType': 'Sunday Morning',
    });

    final upcoming = await service.watchUpcoming('uid-1').first;

    expect(upcoming, hasLength(2));
    expect(upcoming[0].label, 'Youth Night');
    expect(upcoming[1].station, 'Sanctuary');
  });

  test('returns an empty list when there are no upcoming deployments', () async {
    final upcoming = await service.watchUpcoming('nobody').first;
    expect(upcoming, isEmpty);
  });
}
