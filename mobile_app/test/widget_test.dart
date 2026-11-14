// This is a basic Flutter widget test for TuklasRizal.
import 'package:flutter_test/flutter_test.dart';

import 'package:tuklas_rizal/main.dart';

void main() {
  testWidgets('TuklasRizal app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TuklasRizalApp());

    // Verify the app title is present.
    expect(find.text('TuklasRizal'), findsOneWidget);
  });
}
