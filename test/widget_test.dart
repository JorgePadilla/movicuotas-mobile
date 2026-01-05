import 'package:flutter_test/flutter_test.dart';
import 'package:movicuotas_mobile/main.dart';

void main() {
  testWidgets('App starts and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MovicuotasApp());

    // Verify splash screen shows app title
    expect(find.text('MOVICUOTAS'), findsOneWidget);
  });
}
