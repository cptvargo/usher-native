import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/services/attendance_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late AttendanceService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = AttendanceService(firestore: firestore);
  });

  test('addLog writes the expected fields', () async {
    await service.addLog(
      headcount: 120,
      serviceType: 'Sunday Morning',
      notes: 'Great turnout',
      submittedBy: 'Jordan Usher',
    );

    final snap = await firestore.collection('attendance').get();
    expect(snap.docs, hasLength(1));
    final data = snap.docs.single.data();
    expect(data['headcount'], 120);
    expect(data['serviceType'], 'Sunday Morning');
    expect(data['notes'], 'Great turnout');
    expect(data['submittedBy'], 'Jordan Usher');
    expect(data['createdAt'], isA<String>());
  });

  test('watchLogs orders newest first', () async {
    await firestore.collection('attendance').add({
      'headcount': 50,
      'serviceType': 'Wednesday Midweek',
      'submittedBy': 'A',
      'createdAt': '2026-01-01T00:00:00.000Z',
    });
    await firestore.collection('attendance').add({
      'headcount': 200,
      'serviceType': 'Sunday Morning',
      'submittedBy': 'B',
      'createdAt': '2026-06-01T00:00:00.000Z',
    });

    final logs = await service.watchLogs().first;

    expect(logs.map((l) => l.headcount), [200, 50]);
  });

  test('parses createdAt whether it is a Timestamp or an ISO string', () async {
    await firestore.collection('attendance').add({
      'headcount': 10,
      'serviceType': 'Sunday Morning',
      'submittedBy': 'A',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    });

    final logs = await service.watchLogs().first;

    expect(logs.single.createdAt?.year, 2026);
  });

  test('updateLog updates headcount/notes without touching other fields', () async {
    final ref = await firestore.collection('attendance').add({
      'headcount': 10,
      'serviceType': 'Sunday Morning',
      'submittedBy': 'A',
      'createdAt': '2026-01-01T00:00:00.000Z',
    });

    await service.updateLog(ref.id, headcount: 15, notes: 'Updated notes');

    final doc = await ref.get();
    expect(doc.data()?['headcount'], 15);
    expect(doc.data()?['notes'], 'Updated notes');
    expect(doc.data()?['serviceType'], 'Sunday Morning');
  });

  test('deleteLog removes the doc', () async {
    final ref = await firestore.collection('attendance').add({'headcount': 1});

    await service.deleteLog(ref.id);

    final doc = await ref.get();
    expect(doc.exists, isFalse);
  });
}
