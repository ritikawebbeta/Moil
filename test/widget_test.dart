import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:employee_management/main.dart';
import 'package:employee_management/modules/auth/controller/auth_controller.dart';
import 'package:employee_management/modules/leave/controller/leave_controller.dart';
import 'package:employee_management/modules/tour/controller/tour_controller.dart';
import 'package:employee_management/modules/profile/controller/profile_controller.dart';
import 'package:employee_management/modules/notifications/controller/notification_controller.dart';
import 'package:employee_management/modules/holiday/controller/holiday_controller.dart';
import 'package:employee_management/modules/bottom_nav_bar/controller/bottom_nav_bar_controller.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => LeaveController()),
          ChangeNotifierProvider(create: (_) => TourController()),
          ChangeNotifierProvider(create: (_) => ProfileController()),
          ChangeNotifierProvider(create: (_) => NotificationController()),
          ChangeNotifierProvider(create: (_) => HolidayController()),
          ChangeNotifierProvider(create: (_) => BottomNavBarController()),
        ],
        child: const EmployeeManagementApp(),
      ),
    );

    // Verify we are on the login screen
    expect(find.text('Welcome Back!'), findsOneWidget);
  });
}
