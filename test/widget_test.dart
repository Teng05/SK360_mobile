import 'package:flutter_test/flutter_test.dart';

import 'package:sk360/main.dart';

void main() {
  testWidgets('SK360 app renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.textContaining('SK 360'), findsWidgets);
    // Keep this widget test independent from saved sessions and the API.
    expect(find.text('Empowering SK Governance'), findsOneWidget);
  });
}
