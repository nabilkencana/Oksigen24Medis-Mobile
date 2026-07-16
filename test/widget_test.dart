import 'package:flutter_test/flutter_test.dart';
import 'package:oksigen24medis_mobile2/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const Oksigen24App());

    // Verify that our loading/initializing text is present.
    expect(find.text('Menginisialisasi aplikasi...'), findsOneWidget);
  });
}
