import 'package:flutter_test/flutter_test.dart';

import 'package:gate_guardians/main.dart';

void main() {
  testWidgets('App renders scaffold status screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GateGuardiansApp());

    expect(find.text('Gate Guardians'), findsOneWidget);
  });
}
