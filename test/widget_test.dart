// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:youtube_downloader/ui/widgets/animated_button.dart';

void main() {
  testWidgets('AnimatedButton triggers tap callback', (
    WidgetTester tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedButton(
              onPressed: () => pressed = true,
              child: const Text('Fetch'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Fetch'), findsOneWidget);

    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });
}
