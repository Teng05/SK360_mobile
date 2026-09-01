import 'package:flutter_test/flutter_test.dart';

import 'package:sk360/main.dart';

void main() {
  testWidgets('SK360 app renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.textContaining('SK 360'), findsWidgets);
    expect(find.text('Empowering Youth Governance'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
