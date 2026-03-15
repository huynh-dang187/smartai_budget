import 'package:flutter/material.dart';
import '../main.dart'; // Nạp file main để lấy cái công tắc isDarkGlobal
import 'category_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Biến tạm để làm UI cái công tắc bật/tắt (Lát mình sẽ nâng cấp nó thành biến Global)
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Cài đặt & Hồ sơ',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(
          16,
        ).copyWith(bottom: 100), // Kê cục gạch 100px ở đáy
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. THẺ PROFILE SIÊU VIP ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(3), // Viền trắng ngoài Avatar
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(
                        'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                      ), // Avatar mặc định ngầu ngầu
                      backgroundColor: Colors.blue.shade50,
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Thông tin cá nhân
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Duy (Chiến Thần)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Mobile Developer Intern",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "toeic.target.700@gmail.com",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Nút chỉnh sửa
                  IconButton(
                    icon: const Icon(Icons.edit_square, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- 2. NHÓM CÀI ĐẶT: GIAO DIỆN ---
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 10),
              child: Text(
                "GIAO DIỆN",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  // Nút bật tắt Dark Mode
                  SwitchListTile(
                    title: const Text(
                      "Chế độ tối (Dark Mode)",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dark_mode_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    value: false, // Ép nó luôn luôn tắt ở giao diện
                    activeColor: Colors.blueAccent,
                    onChanged: (bool value) {
                      // Không đổi màu app nữa, hiện ngay cái bảng thông báo lên
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "✨ Chức năng Dark Mode đang được phát triển!",
                          ),
                          backgroundColor: Colors.blueAccent,
                          behavior: SnackBarBehavior
                              .floating, // Bảng nổi lên cho sang chảnh
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. NHÓM CÀI ĐẶT: QUẢN LÝ DỮ LIỆU ---
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 10),
              child: Text(
                "QUẢN LÝ TÀI CHÍNH",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildMenuRow(
                    Icons.category_rounded,
                    Colors.orange,
                    "Quản lý Danh mục",
                    "Thêm/Sửa các icon thu chi",
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuRow(
                    Icons.data_usage_rounded,
                    Colors.green,
                    "Xuất báo cáo Excel",
                    "Tải dữ liệu tháng này",
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuRow(
                    Icons.delete_forever_rounded,
                    Colors.red,
                    "Xóa toàn bộ dữ liệu",
                    "Reset ứng dụng từ đầu",
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 4. NHÓM THÔNG TIN & HỖ TRỢ ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildMenuRow(
                    Icons.star_rounded,
                    Colors.amber,
                    "Đánh giá ứng dụng",
                    "Cho app 5 sao nhé!",
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuRow(
                    Icons.info_outline_rounded,
                    Colors.blue,
                    "Giới thiệu",
                    "Phiên bản 1.0.0",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm tiện ích để vẽ các hàng Menu cực mượt
  // Hàm tiện ích để vẽ các hàng Menu
  Widget _buildMenuRow(
    IconData icon,
    Color iconColor,
    String title,
    String subtitle, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey,
      ),
      onTap: () {
        // KIỂM TRA: NẾU BẤM VÀO "QUẢN LÝ DANH MỤC" THÌ CHUYỂN TRANG
        if (title == "Quản lý Danh mục") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CategoryManagementScreen(),
            ),
          );
        }
      },
    );
  }
}
