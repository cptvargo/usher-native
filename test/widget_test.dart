import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gate_guardians/screens/auth_gate.dart';

void main() {
  testWidgets('AuthGate shows the landing screen when signed out',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(auth: MockFirebaseAuth())),
    );
    await tester.pumpAndSettle();

    expect(find.text('GUARDIANS OF THE GATE'), findsOneWidget);
  });
}
