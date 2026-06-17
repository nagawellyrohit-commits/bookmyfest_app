// This is a basic Flutter widget test for CollegeConnect.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:student_app/main.dart';
import 'package:student_app/providers/user_provider.dart';

void main() {
  testWidgets('Dashboard screen rendering smoke test', (WidgetTester tester) async {
    final userProvider = UserProvider();
    userProvider.setSession('fake-token', {
      'id': '123',
      'fullName': 'Test User',
      'email': 'test@example.com',
      'role': 'student',
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: userProvider,
        child: const MyApp(),
      ),
    );

    // Let the initial frame render
    await tester.pump();

    // Verify that our dashboard screen title exists.
    expect(find.text('bookmyfest'), findsOneWidget);
  });
}
