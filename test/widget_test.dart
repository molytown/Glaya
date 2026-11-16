import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaya/features/auth/presentation/screens/phone_input_screen.dart';

void main() {
  testWidgets('Phone input screen shows request OTP button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PhoneInputScreen(),
        ),
      ),
    );

    expect(find.text('Welcome to Glaya'), findsOneWidget);
    expect(find.text('Request OTP'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
