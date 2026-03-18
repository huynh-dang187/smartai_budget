import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Nhớ import thằng này vào
import 'package:shared_preferences/shared_preferences.dart'; // MỚI THÊM

// --- VŨ KHÍ BÍ MẬT: CÔNG TẮC TỔNG TOÀN CỤC ---
// Bất cứ màn hình nào cũng có thể gọi cái này để đổi màu app
final ValueNotifier<bool> isDarkGlobal = ValueNotifier(false);

// --- CẢM BIẾN ĐĂNG NHẬP
final ValueNotifier<String?> userTokenGlobal = ValueNotifier(null);
final ValueNotifier<String?> userNameGlobal = ValueNotifier(null);
final ValueNotifier<int?> userIdGlobal = ValueNotifier(
  null,
); // ĐẶT Ở NGOÀI NÀY NÈ!
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Không tìm thấy file .env! Lỗi: $e");
  }

  // --- TỰ ĐỘNG MÓC KÉT SẮT KHI MỞ APP (MỚI THÊM) ---

  final prefs = await SharedPreferences.getInstance();
  userTokenGlobal.value = prefs.getString('jwt_token');
  userNameGlobal.value = prefs.getString('username');
  userIdGlobal.value = prefs.getInt(
    'user_id',
  ); // Ở trong này chỉ lấy giá trị thôi
  runApp(const SmartBudgetApp());
}

class SmartBudgetApp extends StatelessWidget {
  const SmartBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder sẽ lắng nghe công tắc tổng
    // Cứ hễ có ai gạt công tắc là nó tự động vẽ lại toàn bộ App
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkGlobal,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Smart AI Budget',
          debugShowCheckedModeBanner: false,

          // --- 1. GIAO DIỆN SÁNG (MẶC ĐỊNH) ---
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.blueAccent,
            scaffoldBackgroundColor: Colors.grey.shade50,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87, // Chữ màu đen
              elevation: 0,
            ),
          ),

          // --- 2. GIAO DIỆN TỐI (DARK MODE SIÊU NGẦU) ---
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.blueAccent,
            scaffoldBackgroundColor: const Color(
              0xFF121212,
            ), // Đen nhám chuẩn iOS
            cardColor: const Color(0xFF1E1E1E), // Màu nổi cho các thẻ
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white, // Chữ màu trắng
              elevation: 0,
            ),
            bottomAppBarTheme: const BottomAppBarThemeData(
              color: Color(0xFF1E1E1E), // Thanh điều hướng màu đen xám
            ),
          ),

          // --- 3. NHẬN TÍN HIỆU TỪ CÔNG TẮC ---
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          home: const MainScreen(),
        );
      },
    );
  }
}
