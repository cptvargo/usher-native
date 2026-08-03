import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/screens/home_screen.dart';
import 'package:gate_guardians/services/auth_service.dart';
import 'package:gate_guardians/services/bulletin_service.dart';
import 'package:gate_guardians/services/deployment_service.dart';
import 'package:gate_guardians/services/roster_service.dart';
import 'package:gate_guardians/services/team_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'uid-1', email: 'jordan@church.org'),
    );
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    bool settle = true,
    bool skipApprovalGateForTesting = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        user: auth.currentUser!,
        authService: AuthService(auth: auth, firestore: firestore),
        teamService: TeamService(firestore: firestore),
        bulletinService: BulletinService(firestore: firestore),
        deploymentService: DeploymentService(firestore: firestore),
        rosterService: RosterService(firestore: firestore),
        skipApprovalGateForTesting: skipApprovalGateForTesting,
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // The pending-approval screen has an indefinite spinner, so
      // pumpAndSettle would never return — pump a couple of frames instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('shows the denied screen and can sign out', (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'approved': false,
      'denied': true,
    });

    await pumpHome(tester);

    expect(find.text('Registration Denied'), findsOneWidget);
    await tester.tap(find.text('SIGN OUT'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
  });

  testWidgets('shows the pending-approval screen', (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'approved': false,
      'denied': false,
    });

    await pumpHome(tester, settle: false);

    expect(find.text('Pending Approval'), findsOneWidget);
  });

  testWidgets(
      'skipApprovalGateForTesting reaches the dashboard despite approved being false',
      (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'approved': false,
      'denied': false,
    });

    await pumpHome(tester, skipApprovalGateForTesting: true);

    expect(find.text('Pending Approval'), findsNothing);
    expect(find.text('Sunday Connect'), findsOneWidget);
  });

  testWidgets(
      'shows the dashboard with bulletin, empty deployments state, and nav tabs',
      (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'role': 'Usher',
      'approved': true,
      'denied': false,
    });

    await pumpHome(tester);

    expect(find.text('Sunday Connect'), findsOneWidget);
    expect(find.text('Welcome back, Jordan.'), findsOneWidget);
    expect(
      find.text('Let our service be a blessing to all who enter these gates.'),
      findsOneWidget,
    );
    expect(
      find.text('No upcoming assignments yet. Check back once the next roster is posted.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Coming soon.'), findsOneWidget);
  });

  testWidgets('admins see the Admin nav destination', (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Lead Usher',
      'role': 'Admin',
      'approved': true,
      'denied': false,
    });

    await pumpHome(tester);

    expect(find.byTooltip('Admin'), findsOneWidget);
  });

  testWidgets('non-admins do not see the Admin nav destination', (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'role': 'Usher',
      'approved': true,
      'denied': false,
    });

    await pumpHome(tester);

    expect(find.byTooltip('Admin'), findsNothing);
  });

  testWidgets('editing and saving the bulletin persists the new text',
      (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'approved': true,
      'denied': false,
    });

    await pumpHome(tester);

    final editButton = find.byKey(const ValueKey('bulletinEditButton'));
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Doors open at 9am.');
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    final doc = await firestore.collection('content').doc('service_bulletin').get();
    expect(doc.data()?['text'], 'Doors open at 9am.');
    expect(find.text('Doors open at 9am.'), findsOneWidget);
  });

  group('bulletin inline block editor', () {
    testWidgets('entering edit mode gives each block its own field, matching the read layout',
        (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Jordan Usher',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('content').doc('service_bulletin').set({
        'text': 'Good evening, all\nLouis\nMatthias\nBrandt\nHave a blessed weekend.',
      });

      await pumpHome(tester);
      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();

      // Header + Closing lines, plus one team-roster text field = 3 fields.
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('ADD LINE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets('ADD LINE appends an empty editable paragraph', (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Jordan Usher',
        'approved': true,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(1));
      await tester.tap(find.text('ADD LINE'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('the close icon removes a line before saving', (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Jordan Usher',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('content').doc('service_bulletin').set({
        'text': 'Good evening, all\nSee you Sunday.',
      });

      await pumpHome(tester);
      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(1));

      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('content').doc('service_bulletin').get();
      expect(doc.data()?['text'], 'See you Sunday.');
    });

    testWidgets('CANCEL discards edits without saving', (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Jordan Usher',
        'approved': true,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'This should not be saved.');
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('content').doc('service_bulletin').get();
      expect(doc.data(), isNull);
      expect(
        find.text('Let our service be a blessing to all who enter these gates.'),
        findsOneWidget,
      );
    });

    testWidgets('a "Name - Role" line round-trips through the team text field',
        (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Jordan Usher',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('content').doc('service_bulletin').set({
        'text': 'Louis\nMatthias\nRobert - Lead Usher',
      });

      await pumpHome(tester);

      expect(find.textContaining('LEAD USHER'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();

      final teamField = tester.widget<TextField>(find.byType(TextField).first);
      expect(teamField.controller!.text, 'Louis\nMatthias\nRobert - Lead Usher');

      await tester.tap(find.byKey(const ValueKey('bulletinEditButton')));
      await tester.pumpAndSettle();

      final doc = await firestore.collection('content').doc('service_bulletin').get();
      expect(doc.data()?['text'], 'Louis\nMatthias\nRobert - Lead Usher');
    });
  });

  testWidgets('opening the profile sheet shows the name and a sign-out action',
      (tester) async {
    await firestore.collection('team').doc('uid-1').set({
      'name': 'Jordan Usher',
      'approved': true,
      'denied': false,
    });

    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('avatarButton')));
    await tester.pumpAndSettle();

    expect(find.text('AUTHENTICATED ID'), findsOneWidget);
    expect(find.text('Jordan Usher'), findsWidgets);
  });

  group('Roster tab', () {
    testWidgets('lists active roster members and hides Add Name for a plain usher',
        (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Jordan Usher',
        'role': 'Usher',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('other').set({
        'name': 'Alex Lead',
        'role': 'Lead',
        'phone': '555-2222',
        'approved': true,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byTooltip('Roster'));
      await tester.pumpAndSettle();

      expect(find.text('Usher Database'), findsOneWidget);
      expect(find.text('Alex Lead'), findsOneWidget);
      expect(find.text('Add Name'), findsNothing);
    });

    testWidgets('a lead can add a new usher through the dialog', (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Lead Usher',
        'role': 'Lead',
        'approved': true,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byTooltip('Roster'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New Usher');
      await tester.enterText(find.byType(TextField).last, '555-9999');
      await tester.tap(find.text('Save to Database'));
      await tester.pumpAndSettle();

      expect(find.text('New Usher'), findsOneWidget);
      final snap = await firestore
          .collection('team')
          .where('name', isEqualTo: 'New Usher')
          .get();
      expect(snap.docs.single.data()['approved'], isTrue);
    });

    testWidgets('a lead can remove a usher after confirming', (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Lead Usher',
        'role': 'Lead',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('other').set({
        'name': 'Removable Usher',
        'role': 'Usher',
        'approved': true,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byTooltip('Roster'));
      await tester.pumpAndSettle();

      // Both the signed-in lead and "Removable Usher" show delete icons;
      // alphabetical sort ("Lead Usher" < "Removable Usher") puts the
      // target row's icon last.
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Removable Usher'), findsNothing);
      final doc = await firestore.collection('team').doc('other').get();
      expect(doc.exists, isFalse);
    });
  });

  group('Admin tab', () {
    testWidgets('shows the caught-up empty state with no pending registrations',
        (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Admin Usher',
        'role': 'Admin',
        'approved': true,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byTooltip('Admin'));
      await tester.pumpAndSettle();

      expect(find.text("No pending registrations. You're all caught up."),
          findsOneWidget);
    });

    testWidgets('approving a pending registration removes it from the list',
        (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Admin Usher',
        'role': 'Admin',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('pending-1').set({
        'name': 'Pending Pat',
        'phone': '555-1111',
        'approved': false,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byTooltip('Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Pending Pat'), findsOneWidget);

      await tester.tap(find.text('APPROVE'));
      await tester.pumpAndSettle();

      expect(find.text('Pending Pat'), findsNothing);
      final doc = await firestore.collection('team').doc('pending-1').get();
      expect(doc.data()?['approved'], isTrue);
    });

    testWidgets('denying a pending registration removes it from the list',
        (tester) async {
      await firestore.collection('team').doc('uid-1').set({
        'name': 'Admin Usher',
        'role': 'Admin',
        'approved': true,
        'denied': false,
      });
      await firestore.collection('team').doc('pending-1').set({
        'name': 'Pending Pat',
        'phone': '555-1111',
        'approved': false,
        'denied': false,
      });

      await pumpHome(tester);
      await tester.tap(find.byTooltip('Admin'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DENY'));
      await tester.pumpAndSettle();

      expect(find.text('Pending Pat'), findsNothing);
      final doc = await firestore.collection('team').doc('pending-1').get();
      expect(doc.data()?['denied'], isTrue);
    });
  });
}
