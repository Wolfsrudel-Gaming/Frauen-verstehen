import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/main.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/services/app_mode.dart';

void main() {
  testWidgets('App boots to login screen when no token is stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppMode.init();

    await tester.pumpWidget(const DriverAnalyticsApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('App boots straight to home screen in offline mode', (tester) async {
    SharedPreferences.setMockInitialValues({'offline_mode': true});
    await AppMode.init();

    await tester.pumpWidget(const DriverAnalyticsApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Offline-Modus · Daten lokal'), findsOneWidget);
  });

  testWidgets('Login screen offers the offline mode option', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppMode.init();

    await tester.pumpWidget(const DriverAnalyticsApp());
    await tester.pumpAndSettle();

    expect(find.text('Offline-Modus (ohne Server)'), findsOneWidget);
  });
}
