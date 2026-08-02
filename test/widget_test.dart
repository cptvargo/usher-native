import 'package:flutter_test/flutter_test.dart';

import 'package:gate_guardians/main.dart';

void main() {
  testWidgets('App renders the landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GateGuardiansApp());
    await tester.pumpAndSettle();

    expect(find.text('GUARDIANS OF THE GATE'), findsOneWidget);
    expect(find.text('ENTER PORTAL'), findsOneWidget);
    expect(find.text('REQUEST ACCESS'), findsOneWidget);
  });
}
