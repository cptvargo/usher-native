import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/screens/auth_gate.dart';
import 'package:gate_guardians/services/auth_service.dart';
import 'package:gate_guardians/services/bulletin_service.dart';
import 'package:gate_guardians/services/deployment_service.dart';
import 'package:gate_guardians/services/team_service.dart';

void main() {
  testWidgets('shows the landing screen when signed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(auth: MockFirebaseAuth())),
    );
    await tester.pumpAndSettle();

    expect(find.text('GUARDIANS OF THE GATE'), findsOneWidget);
  });

  testWidgets('jumps straight to the dashboard when already signed in',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'uid-1', email: 'jordan@church.org'),
    );
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'approved': true,
      'denied': false,
    });

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        auth: auth,
        authService: AuthService(auth: auth, firestore: firestore),
        teamService: TeamService(firestore: firestore),
        bulletinService: BulletinService(firestore: firestore),
        deploymentService: DeploymentService(firestore: firestore),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Connect'), findsOneWidget);
  });

  testWidgets(
      'logging in from the landing screen lands on the dashboard afterward',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'test-uid', email: 'jordan@church.org'),
    );
    await firestore.collection('team').doc('test-uid').set({
      'name': 'Jordan Usher',
      'approved': true,
      'denied': false,
    });

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        auth: auth,
        authService: AuthService(auth: auth, firestore: firestore),
        teamService: TeamService(firestore: firestore),
        bulletinService: BulletinService(firestore: firestore),
        deploymentService: DeploymentService(firestore: firestore),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('GUARDIANS OF THE GATE'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTER PORTAL'));
    await tester.pumpAndSettle();

    expect(find.text('Guardians Login'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'jordan@church.org');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.text('ENTER GATE'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Connect'), findsOneWidget);
  });
}
