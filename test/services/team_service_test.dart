import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/services/team_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TeamService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TeamService(firestore: firestore);
  });

  test('resolves a primary record directly', () async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'role': 'Usher',
      'approved': true,
      'denied': false,
    });

    final profile = await service.watchProfile('uid-1').first;

    expect(profile, isNotNull);
    expect(profile!.id, 'uid-1');
    expect(profile.name, 'Jordan Usher');
    expect(profile.approved, isTrue);
  });

  test('follows linkedTo to the primary record', () async {
    await firestore.collection('team').doc('primary-uid').set({
      'name': 'Alex Usher',
      'role': 'Admin',
      'approved': true,
      'denied': false,
    });
    await firestore.collection('team').doc('phone-uid').set({
      'linkedTo': 'primary-uid',
    });

    final profile = await service.watchProfile('phone-uid').first;

    expect(profile, isNotNull);
    expect(profile!.id, 'primary-uid');
    expect(profile.isAdmin, isTrue);
  });

  test('returns null when the doc does not exist', () async {
    final profile = await service.watchProfile('missing').first;
    expect(profile, isNull);
  });

  test('defaults role/name when missing and reads denied', () async {
    await firestore.collection('team').doc('uid-2').set({
      'approved': false,
      'denied': true,
    });

    final profile = await service.watchProfile('uid-2').first;

    expect(profile!.name, 'Guardian');
    expect(profile.role, 'Usher');
    expect(profile.denied, isTrue);
    expect(profile.approved, isFalse);
  });
}
