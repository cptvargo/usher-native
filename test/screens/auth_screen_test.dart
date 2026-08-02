import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/screens/auth_screen.dart';
import 'package:gate_guardians/services/auth_service.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.loginError, this.registerError, this.resetError})
      : super(auth: MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  final AuthException? loginError;
  final AuthException? registerError;
  final AuthException? resetError;

  bool loginCalled = false;
  bool registerCalled = false;
  bool resetCalled = false;

  @override
  Future<void> login({
    required bool usePhone,
    required String email,
    required String phone,
    required String password,
  }) async {
    loginCalled = true;
    if (loginError != null) throw loginError!;
  }

  @override
  Future<void> register({
    required bool usePhone,
    required String displayName,
    required String email,
    required String phone,
    required String existingEmail,
    required String password,
    required String adminCode,
  }) async {
    registerCalled = true;
    if (registerError != null) throw registerError!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalled = true;
    if (resetError != null) throw resetError!;
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String initialMode = 'login',
    AuthService? authService,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        initialMode: initialMode,
        authService: authService ?? _FakeAuthService(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('login mode shows the email field and Enter Gate button',
      (tester) async {
    await pump(tester);

    expect(find.text('Guardians Login'), findsOneWidget);
    expect(find.text('Full Name'), findsNothing);
    expect(find.text('ENTER GATE'), findsOneWidget);
  });

  testWidgets('register mode shows Full Name and Admin Code fields',
      (tester) async {
    await pump(tester, initialMode: 'register');

    expect(find.text('Join the Guard'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Admin Code (optional)'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('switching to "No Email" swaps the email field for phone',
      (tester) async {
    await pump(tester);

    expect(find.text('Email Address'), findsOneWidget);
    await tester.tap(find.text('NO EMAIL'));
    await tester.pumpAndSettle();

    expect(find.text('Email Address'), findsNothing);
    expect(find.text('Phone Number (used to sign in)'), findsOneWidget);
  });

  testWidgets('Forgot Password? switches to the reset form', (tester) async {
    await pump(tester);

    await tester.tap(find.text('FORGOT PASSWORD?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('SEND RESET LINK'), findsOneWidget);
  });

  testWidgets('successful login shows a welcome-back confirmation',
      (tester) async {
    final service = _FakeAuthService();
    await pump(tester, authService: service);

    await tester.enterText(find.byType(TextField).first, 'jordan@church.org');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.text('ENTER GATE'));
    await tester.pumpAndSettle();

    expect(service.loginCalled, isTrue);
    expect(find.text('Welcome back.'), findsOneWidget);
  });

  testWidgets('failed login shows the error banner from AuthService',
      (tester) async {
    final service =
        _FakeAuthService(loginError: AuthException('Incorrect email or password.'));
    await pump(tester, authService: service);

    await tester.enterText(find.byType(TextField).first, 'jordan@church.org');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('ENTER GATE'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('successful registration shows an approval-pending confirmation',
      (tester) async {
    final service = _FakeAuthService();
    await pump(tester, initialMode: 'register', authService: service);

    await tester.enterText(find.byType(TextField).at(0), 'Jordan Usher');
    await tester.enterText(find.byType(TextField).at(1), 'jordan@church.org');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(service.registerCalled, isTrue);
    expect(
      find.text('Account created! A lead usher will approve your access shortly.'),
      findsOneWidget,
    );
  });

  testWidgets('failed registration shows the error banner from AuthService',
      (tester) async {
    final service = _FakeAuthService(
      registerError: AuthException('This email is already registered.'),
    );
    await pump(tester, initialMode: 'register', authService: service);

    await tester.enterText(find.byType(TextField).at(0), 'Jordan Usher');
    await tester.enterText(find.byType(TextField).at(1), 'jordan@church.org');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsOneWidget);
  });

  testWidgets('successful password reset shows the success banner and hides the form',
      (tester) async {
    final service = _FakeAuthService();
    await pump(tester, authService: service);

    await tester.tap(find.text('FORGOT PASSWORD?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'jordan@church.org');
    await tester.tap(find.text('SEND RESET LINK'));
    await tester.pumpAndSettle();

    expect(service.resetCalled, isTrue);
    expect(find.text('Reset link sent! Check your email inbox.'), findsOneWidget);
    expect(find.text('SEND RESET LINK'), findsNothing);
  });

  testWidgets('failed password reset shows the error banner from AuthService',
      (tester) async {
    final service = _FakeAuthService(
      resetError: AuthException('No account found with that email.'),
    );
    await pump(tester, authService: service);

    await tester.tap(find.text('FORGOT PASSWORD?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'nobody@church.org');
    await tester.tap(find.text('SEND RESET LINK'));
    await tester.pumpAndSettle();

    expect(find.text('No account found with that email.'), findsOneWidget);
  });

  testWidgets('password visibility toggle switches obscureText',
      (tester) async {
    await pump(tester);

    final passwordField = find.byType(TextField).last;
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off_rounded));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
  });
}
