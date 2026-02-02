// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reward_token_app/main.dart';

void main() {
  testWidgets('Bottom navigation switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Bottom navigation items exist.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('QR Scan'), findsWidgets);
    expect(find.text('Customer Registration'), findsWidgets);

    // Starts on Home tab.
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);

    // Switch to QR Scan.
    await tester.tap(find.text('QR Scan'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'QR Scan'), findsOneWidget);

    // Switch to Customer Registration.
    await tester.tap(find.text('Customer Registration'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Customer Registration'), findsOneWidget);
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
  });
}
