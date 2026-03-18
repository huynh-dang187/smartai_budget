import 'package:flutter/material.dart';
import 'main_screen.dart'; // Nạp MainScreen để lát nữa đăng nhập xong thì nhảy vào đây
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // MỚI
import '../main.dart'; // Để gọi 2 cái biến toàn cầu

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Công tắc bật/tắt: true = Màn Đăng nhập, false = Màn Đăng ký
  bool _isLogin = true;
  bool _anMatKhau = true; // Ẩn/hiện password
  bool _isLoadingAuth = false; // MỚI THÊM: Biến quản lý vòng xoay loading

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // --- HÀM XỬ LÝ NÚT BẤM (Tối nay tạm làm UI, mai sẽ nhúng API Strapi vào đây) ---
  // --- HÀM XỬ LÝ ĐĂNG NHẬP / ĐĂNG KÝ (GỌI API STRAPI) ---
  Future<void> _xuLyXacThuc() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String username = _usernameController.text.trim();

    // 1. Kiểm tra rỗng
    if (email.isEmpty || password.isEmpty || (!_isLogin && username.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Vui lòng điền đầy đủ thông tin!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Bật vòng xoay Loading
    setState(() => _isLoadingAuth = true);

    try {
      http.Response response;
      final String ipServer =
          'http://10.57.162.167:1337'; // CHÚ Ý: Cập nhật IP của ông ở đây nếu cần

      if (_isLogin) {
        // --- LUỒNG ĐĂNG NHẬP ---
        response = await http.post(
          Uri.parse('$ipServer/api/auth/local'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "identifier":
                email, // Strapi dùng chữ 'identifier' cho Email lúc đăng nhập
            "password": password,
          }),
        );
      } else {
        // --- LUỒNG ĐĂNG KÝ ---
        response = await http.post(
          Uri.parse('$ipServer/api/auth/local/register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "username": username,
            "email": email,
            "password": password,
          }),
        );
      }

      // 3. Xử lý kết quả trả về
      if (response.statusCode == 200) {
        // THÀNH CÔNG: Lấy Chìa khóa JWT ra
        final data = json.decode(response.body);
        final jwtToken = data['jwt'];
        final user = data['user'];

        // Tạm thời in ra màn hình Console để ông ngắm cái Token nó hình thù thế nào
        debugPrint("🔥 LẤY TOKEN THÀNH CÔNG: $jwtToken");
        debugPrint("👤 User: ${user['username']}");
        // --- CẤT VÀO KÉT SẮT VÀ BẬT CẢM BIẾN (MỚI THÊM) ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', jwtToken);
        await prefs.setString('username', user['username']);
        await prefs.setInt('user_id', user['id']); // MỚI THÊM: Lưu ID

        // Bật cảm biến để toàn app biết sếp đã login!
        userTokenGlobal.value = jwtToken;
        userNameGlobal.value = user['username'];
        userIdGlobal.value = user['id']; // MỚI THÊM: Bật cảm biến ID
        if (mounted) {
          Navigator.pop(context); // Đóng bảng Auth lại, cho vào app
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✨ ${_isLogin ? 'Đăng nhập' : 'Đăng ký'} thành công!",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // THẤT BẠI: Bắt lỗi từ Strapi (Sai pass, trùng email...)
        final errorData = json.decode(response.body);
        String errorMsg =
            errorData['error']?['message'] ?? "Có lỗi xảy ra, thử lại sau!";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ $errorMsg"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Lỗi kết nối mạng: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // 4. Tắt vòng xoay Loading dù thành công hay thất bại
      if (mounted) setState(() => _isLoadingAuth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // LẮP THÊM NÚT BACK Ở ĐÂY LÀ XONG
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.black87,
            size: 30,
          ),
          onPressed: () => Navigator.pop(context), // Bấm dấu X để thoát
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- 1. LOGO HOÀNH TRÁNG ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 80,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 30),

              // --- 2. LỜI CHÀO ---
              Text(
                _isLogin ? "Chào mừng trở lại!" : "Tạo tài khoản mới",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Smart AI Budget - Quản lý chi tiêu thông minh",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // --- 3. FORM NHẬP LIỆU ---

              // Ô Username (Chỉ hiện khi đang ở chế độ Đăng ký)
              if (!_isLogin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: "Tên hiển thị (Username)",
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Colors.blueAccent,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

              // Ô Email (Lúc nào cũng hiện)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email của bạn",
                  prefixIcon: const Icon(Icons.email, color: Colors.blueAccent),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Ô Mật khẩu (Có nút ẩn/hiện con mắt)
              TextField(
                controller: _passwordController,
                obscureText: _anMatKhau, // Ẩn chữ thành dấu chấm
                decoration: InputDecoration(
                  labelText: "Mật khẩu",
                  prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _anMatKhau ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(
                      () => _anMatKhau = !_anMatKhau,
                    ), // Bật tắt con mắt
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- 4. NÚT ĐĂNG NHẬP / ĐĂNG KÝ ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                onPressed: _xuLyXacThuc,
                child: Text(
                  _isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ NGAY",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- 5. NÚT CHUYỂN ĐỔI CHẾ ĐỘ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? "Chưa có tài khoản?" : "Đã có tài khoản?",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin; // Lật ngược công tắc
                      });
                    },
                    child: Text(
                      _isLogin ? "Đăng ký ngay" : "Đăng nhập",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
