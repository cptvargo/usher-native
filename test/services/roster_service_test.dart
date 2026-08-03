import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/services/roster_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late RosterService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = RosterService(firestore: firestore);
  });

  group('watchActiveRoster', () {
    test('only returns approved members without a linkedTo, sorted by name',
        () async {
      await firestore.collection('team').doc('a').set({
        'name': 'Zack Usher',
        'role': 'Usher',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('b').set({
        'name': 'Amy Usher',
        'role': 'Lead',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('c').set({
        'name': 'Pending Pat',
        'approved': false,
        'denied': false,
      });
      await firestore.collection('team').doc('d').set({
        'linkedTo': 'b',
        'approved': true,
        'denied': false,
      });

      final roster = await service.watchActiveRoster().first;

      expect(roster.map((m) => m.name), ['Amy Usher', 'Zack Usher']);
    });

    test(
        'parses createdAt whether it is a Firestore Timestamp or an ISO string',
        () async {
      await firestore.collection('team').doc('a').set({
        'name': 'Timestamp Usher',
        'approved': true,
        'denied': false,
        'createdAt': Timestamp.fromDate(DateTime(2024, 3, 15)),
      });
      await firestore.collection('team').doc('b').set({
        'name': 'String Usher',
        'approved': true,
        'denied': false,
        'createdAt': '2024-03-15T00:00:00.000Z',
      });

      final roster = await service.watchActiveRoster().first;

      expect(roster.every((m) => m.createdAt?.year == 2024), isTrue);
    });
  });

  group('watchPendingRegistrations', () {
    test('only returns members that are neither approved nor denied',
        () async {
      await firestore.collection('team').doc('a').set({
        'name': 'Pending Pat',
        'approved': false,
        'denied': false,
      });
      await firestore.collection('team').doc('b').set({
        'name': 'Already Approved',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('c').set({
        'name': 'Already Denied',
        'approved': false,
        'denied': true,
      });

      final pending = await service.watchPendingRegistrations().first;

      expect(pending, hasLength(1));
      expect(pending.single.name, 'Pending Pat');
    });
  });

  test('approve sets approved true and denied false', () async {
    await firestore.collection('team').doc('a').set({
      'name': 'Pat',
      'approved': false,
      'denied': false,
    });

    await service.approve('a');

    final doc = await firestore.collection('team').doc('a').get();
    expect(doc.data()?['approved'], isTrue);
    expect(doc.data()?['denied'], isFalse);
  });

  test('deny sets approved false and denied true', () async {
    await firestore.collection('team').doc('a').set({
      'name': 'Pat',
      'approved': false,
      'denied': false,
    });

    await service.deny('a');

    final doc = await firestore.collection('team').doc('a').get();
    expect(doc.data()?['approved'], isFalse);
    expect(doc.data()?['denied'], isTrue);
  });

  test('addUsher creates a pre-approved team doc', () async {
    await service.addUsher(name: 'New Usher', phone: '555-1234', role: 'Usher');

    final snap = await firestore.collection('team').get();
    expect(snap.docs, hasLength(1));
    final data = snap.docs.single.data();
    expect(data['name'], 'New Usher');
    expect(data['phone'], '555-1234');
    expect(data['approved'], isTrue);
  });

  test('updateUsher updates name/phone/role without touching other fields',
      () async {
    await firestore.collection('team').doc('a').set({
      'name': 'Old Name',
      'phone': '000',
      'role': 'Usher',
      'approved': true,
      'denied': false,
    });

    await service.updateUsher('a', name: 'New Name', phone: '111', role: 'Lead');

    final doc = await firestore.collection('team').doc('a').get();
    expect(doc.data()?['name'], 'New Name');
    expect(doc.data()?['phone'], '111');
    expect(doc.data()?['role'], 'Lead');
    expect(doc.data()?['approved'], isTrue);
  });

  test('deleteUsher removes the doc', () async {
    await firestore.collection('team').doc('a').set({'name': 'Pat'});

    await service.deleteUsher('a');

    final doc = await firestore.collection('team').doc('a').get();
    expect(doc.exists, isFalse);
  });
}
