import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/services/auth_service.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore firestore;
  late AuthService service;

  setUp(() {
    auth = MockFirebaseAuth();
    firestore = FakeFirebaseFirestore();
    service = AuthService(auth: auth, firestore: firestore);
  });

  group('register — validation', () {
    test('rejects an empty display name without touching Firebase Auth', () async {
      expect(
        () => service.register(
          usePhone: false,
          displayName: '  ',
          email: 'new@church.org',
          phone: '',
          existingEmail: '',
          password: 'password123',
          adminCode: '',
        ),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', 'Please enter your full name.')),
      );
      expect(auth.currentUser, isNull);
    });

    test('rejects a phone number that is too short', () async {
      expect(
        () => service.register(
          usePhone: true,
          displayName: 'Jordan Usher',
          email: '',
          phone: '123',
          existingEmail: '',
          password: 'password123',
          adminCode: '',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            'Please enter a valid phone number.')),
      );
    });
  });

  group('register — new team record', () {
    test('creates an unapproved Usher record by default', () async {
      await service.register(
        usePhone: false,
        displayName: 'Jordan Usher',
        email: 'jordan@church.org',
        phone: '',
        existingEmail: '',
        password: 'password123',
        adminCode: '',
      );

      final uid = auth.currentUser!.uid;
      final doc = await firestore.collection('team').doc(uid).get();
      expect(doc.data(), containsPair('name', 'Jordan Usher'));
      expect(doc.data(), containsPair('email', 'jordan@church.org'));
      expect(doc.data(), containsPair('role', 'Usher'));
      expect(doc.data(), containsPair('approved', false));
      expect(doc.data(), containsPair('denied', false));
    });

    test('auto-approves as Admin when the admin code matches', () async {
      await service.register(
        usePhone: false,
        displayName: 'Lead Usher',
        email: 'lead@church.org',
        phone: '',
        existingEmail: '',
        password: 'password123',
        adminCode: kAdminCode,
      );

      final uid = auth.currentUser!.uid;
      final doc = await firestore.collection('team').doc(uid).get();
      expect(doc.data(), containsPair('role', 'Admin'));
      expect(doc.data(), containsPair('approved', true));
    });

    test('claims a pre-created team record matching the phone number',
        () async {
      await firestore.collection('team').doc('preseeded').set({
        'name': 'Pat Volunteer',
        'phone': '(555) 111-2222',
        'approved': false,
        'denied': false,
      });

      await service.register(
        usePhone: true,
        displayName: 'Pat Volunteer',
        email: '',
        phone: '555-111-2222',
        existingEmail: '',
        password: 'password123',
        adminCode: '',
      );

      final preseeded = await firestore.collection('team').doc('preseeded').get();
      expect(preseeded.data(), containsPair('approved', true));
      expect(preseeded.data(), contains('phoneUid'));

      final uid = auth.currentUser!.uid;
      final linkDoc = await firestore.collection('team').doc(uid).get();
      expect(linkDoc.data(), containsPair('linkedTo', 'preseeded'));
    });
  });

  group('register — phone linked to existing email account', () {
    test('links to the matching email record', () async {
      await firestore.collection('team').doc('existing-uid').set({
        'name': 'Alex Usher',
        'email': 'alex@church.org',
        'approved': true,
        'denied': false,
      });

      await service.register(
        usePhone: true,
        displayName: 'Alex Usher',
        email: '',
        phone: '555-999-0000',
        existingEmail: 'alex@church.org',
        password: 'password123',
        adminCode: '',
      );

      final existing = await firestore.collection('team').doc('existing-uid').get();
      expect(existing.data(), containsPair('phone', '555-999-0000'));
      expect(existing.data(), contains('phoneUid'));

      final uid = auth.currentUser!.uid;
      final linkDoc = await firestore.collection('team').doc(uid).get();
      expect(linkDoc.data(), containsPair('linkedTo', 'existing-uid'));
    });

    test('throws and does not leave a dangling team doc when no match exists',
        () async {
      await expectLater(
        service.register(
          usePhone: true,
          displayName: 'No Match',
          email: '',
          phone: '555-000-0000',
          existingEmail: 'nobody@church.org',
          password: 'password123',
          adminCode: '',
        ),
        throwsA(isA<AuthException>()),
      );

      final teamDocs = await firestore.collection('team').get();
      expect(teamDocs.docs, isEmpty);
    });
  });

  group('login', () {
    test('maps user-not-found to a phone-specific message', () async {
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null,
              {#email: anything, #password: anything}))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      expect(
        () => service.login(
          usePhone: true,
          email: '',
          phone: '555-123-4567',
          password: 'wrong',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            'Incorrect phone number or password.')),
      );
    });

    test('maps email-already-in-use style errors for email sign in', () async {
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null,
              {#email: anything, #password: anything}))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      expect(
        () => service.login(
          usePhone: false,
          email: 'jordan@church.org',
          phone: '',
          password: 'wrong',
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            'Incorrect email or password.')),
      );
    });
  });

  group('sendPasswordReset', () {
    test('rejects an empty email', () async {
      expect(
        () => service.sendPasswordReset(''),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', 'Please enter your email address.')),
      );
    });

    test('maps user-not-found to a friendly message', () async {
      whenCalling(Invocation.method(#sendPasswordResetEmail, null,
              {#email: anything, #actionCodeSettings: anything}))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      expect(
        () => service.sendPasswordReset('nobody@church.org'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            'No account found with that email.')),
      );
    });
  });
}
