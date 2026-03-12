import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Dòng này sẽ báo lỗi đỏ gạch chân, cứ bình tĩnh!
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Đổi hàm main thành async
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nạp két sắt lên!
  await dotenv.load(fileName: ".env");

  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatelessWidget {
  const SmartBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AI Budget',
      debugShowCheckedModeBanner: false, // Tắt cái chữ Debug góc phải màn hình
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Trỏ thẳng đến Màn hình chính
    );
  }
}
