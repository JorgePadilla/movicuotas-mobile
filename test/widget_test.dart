import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movicuotas_mobile/main.dart';

void main() {
  testWidgets('App starts and shows the splash spinner', (WidgetTester tester) async {
    await tester.pumpWidget(const MovicuotasApp());

    // The splash screen is a bare CircularProgressIndicator while
    // AuthProvider.checkAuthStatus() decides where to route (there is no title text).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
