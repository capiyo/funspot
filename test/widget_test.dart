
import 'package:flutter_test/flutter_test.dart';
import 'package:clash/main.dart';

void main() {
  testWidgets('App starts and shows title', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const PledgesApp());  // Changed from MyApp to PledgesApp

    // Verify that our app title appears
    expect(find.text('clash Pledges'), findsOneWidget);
  });
}