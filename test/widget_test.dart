import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';

void main() {
  testWidgets('App Theme & UI Basic Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeData.lightTheme,
        home: const Scaffold(
          body: Center(child: Text('Oksigen24 Medis POS')),
        ),
      ),
    );

    expect(find.text('Oksigen24 Medis POS'), findsOneWidget);
  });
}
