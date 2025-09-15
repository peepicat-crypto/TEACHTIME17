import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- 1. เพิ่ม Import

// Import Services
import 'services/user_service.dart';
import 'models/auth_service.dart'; // ตรวจสอบ Path นี้ อาจจะเป็น 'services/auth_service.dart'
import 'services/room_service.dart';
import 'services/booking_service.dart';
import 'services/notification_service.dart';
import 'services/report_service.dart';

// Import Screens
import 'screen/login_screen.dart';
import 'screen/home_screen.dart';

// 2. แก้ไขฟังก์ชัน main ให้เป็น async และเพิ่มการ initialize
void main() async {
  // ต้องมีบรรทัดนี้เสมอเมื่อมีการ await ก่อน runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // รอให้ข้อมูลภาษาไทยพร้อมใช้งานสำหรับ DateFormat
  await initializeDateFormatting('th', null);

  // เริ่มการทำงานของแอป
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => RoomService()),
        ChangeNotifierProvider(create: (context) => BookingService()),
        ChangeNotifierProvider(create: (context) => NotificationService()),
        ChangeNotifierProvider(create: (context) => ReportService()),
        ChangeNotifierProvider(create: (context) => UserService()),
      ],
      child: MaterialApp(
        title: 'Classroom Booking App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, child) {
            // ใช้ FutureBuilder เพื่อรอสถานะการล็อกอินเริ่มต้น (ถ้ามี)
            // ช่วยป้องกันการกระพริบของหน้าจอตอนเปิดแอป
            return FutureBuilder(
              // สมมติว่ามีฟังก์ชัน tryAutoLogin ใน AuthService
              future: authService.tryAutoLogin(),
              builder: (ctx, authResultSnapshot) {
                if (authResultSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                return authService.isLoggedIn
                    ? const HomeScreen()
                    : const LoginScreen();
              },
            );
          },
        ),
      ),
    );
  }
}
