import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gate_guardians/screens/landing_screen.dart';

void main() {
  Future<void> pumpLanding(
    WidgetTester tester,
    void Function(String mode) onEnterPortal,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LandingScreen(onEnterPortal: onEnterPortal)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders headline, both CTAs, and all four feature cards',
      (tester) async {
    await pumpLanding(tester, (_) {});

    expect(find.textContaining('Servant leadership'), findsOneWidget);
    expect(find.text('ENTER PORTAL'), findsOneWidget);
    expect(find.text('REQUEST ACCESS'), findsOneWidget);

    for (final title in [
      'Live Deployments',
      'Attendance Hub',
      'Teammate Comms',
      'Instant Alerts',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('tapping Enter Portal invokes onEnterPortal with "login"',
      (tester) async {
    String? received;
    await pumpLanding(tester, (mode) => received = mode);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTER PORTAL'));
    await tester.pumpAndSettle();

    expect(received, 'login');
  });

  testWidgets(
      'tapping Request Access invokes onEnterPortal with "register"',
      (tester) async {
    String? received;
    await pumpLanding(tester, (mode) => received = mode);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REQUEST ACCESS'));
    await tester.pumpAndSettle();

    expect(received, 'register');
  });
}
