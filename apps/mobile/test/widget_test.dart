import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/main.dart';
import 'package:mobile/screens/login_screen.dart';

void main() {
  testWidgets('App boots to login screen when no token is stored', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DriverAnalyticsApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
