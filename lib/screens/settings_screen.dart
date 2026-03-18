import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Nạp file main để lấy cái công tắc isDarkGlobal
import 'category_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Nhớ import thư viện này ở đầu file nhé
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Biến tạm để làm UI cái công tắc bật/tắt (Lát mình sẽ nâng cấp nó thành biến Global)
  bool _isDarkMode = false;
  // --- NHÀ MÁY SẢN XUẤT EXCEL ---
  Future<void> _xuatBaoCaoExcel() async {
    // 1. Hiện vòng xoay loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Lấy toàn bộ giao dịch từ Strapi
      final url = Uri.parse(
        'http://10.57.162.167:1337/api/transactions?populate=*',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List giaoDich = data['data'];

        // 3. Khởi tạo file Excel
        var excel = Excel.createExcel();
        Sheet sheetObject = excel['Báo cáo chi tiêu']; // Tạo sheet mới
        excel.setDefaultSheet('Báo cáo chi tiêu');

        // Kẻ dòng Tiêu đề (Header)
        sheetObject.appendRow([
          TextCellValue('Ngày tháng'),
          TextCellValue('Danh mục'),
          TextCellValue('Số tiền (VNĐ)'),
          TextCellValue('Ghi chú'),
        ]);

        // Đổ data vào từng dòng
        for (var gd in giaoDich) {
          final attrs = gd['attributes'] ?? gd;

          // Lấy Ngày
          String ngay = '';
          if (attrs['date'] != null) {
            DateTime dt = DateTime.parse(attrs['date']).toLocal();
            ngay = DateFormat('dd/MM/yyyy HH:mm').format(dt);
          }

          // Lấy Tên Danh Mục (Fix chuẩn logic AI)
          String tenDM = 'Khác';
          if (attrs['category'] != null) {
            var cat = attrs['category'];
            if (cat['Name'] != null) {
              tenDM = cat['Name'];
            } else if (cat['data'] != null) {
              tenDM =
                  (cat['data']['attributes'] ?? cat['data'])['Name'] ?? 'Khác';
            }
          }

          // Lấy Tiền và Ghi chú
          double tien = (attrs['amount'] ?? 0).toDouble();
          String note = attrs['note'] ?? '';

          // Ghi vào dòng mới
          sheetObject.appendRow([
            TextCellValue(ngay),
            TextCellValue(tenDM),
            DoubleCellValue(tien),
            TextCellValue(note),
          ]);
        }

        // 4. Lưu file vào bộ nhớ tạm của điện thoại
        var fileBytes = excel.save();
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/BaoCaoChiTieu_SmartBudget.xlsx');
        await file.writeAsBytes(fileBytes!);

        if (mounted) Navigator.pop(context); // Tắt loading

        // 5. Bật bảng Share để người dùng tự chọn nơi lưu/gửi
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Báo cáo chi tiêu của tôi từ Smart AI Budget!');
      } else {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Không thể tải dữ liệu từ server.")),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Lỗi xuất Excel: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Lỗi xuất file: $e")));
    }
  }

  // --- HÀM HỦY DIỆT: RESET ỨNG DỤNG ---
  Future<void> _xoaToanBoDuLieu() async {
    // 1. Cảnh báo đỏ
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 10),
                Text("CẢNH BÁO ĐỎ", style: TextStyle(color: Colors.red)),
              ],
            ),
            content: const Text(
              "Hành động này sẽ xóa sạch toàn bộ lịch sử chi tiêu và cài đặt ngân sách. Bạn có chắc chắn muốn reset ứng dụng không?",
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Hủy"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Xóa sạch",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return; // Nếu user chọn Hủy thì quay xe

    // 2. Hiện vòng xoay Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      ),
    );

    try {
      // 3. Quét sạch Két sắt nội bộ (Xóa hạn mức ngân sách)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 4. Lên Strapi lấy danh sách tất cả Giao dịch (Transactions)
      final url = Uri.parse('http://10.57.162.167:1337/api/transactions');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];

        // 5. Bắn bỏ từng giao dịch một (Vì Strapi mặc định không cho xóa Bulk Delete 1 lần)
        for (var item in data) {
          var id = item['documentId'] ?? item['id'];
          await http.delete(
            Uri.parse('http://10.57.162.167:1337/api/transactions/$id'),
          );
        }
      }

      // Tắt Loading và báo tin mừng
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✨ Đã Reset ứng dụng như mới!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Lỗi reset dữ liệu: $e");
    }
  }

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
            // --- 1.5 NHÓM TÀI KHOẢN  ---
            // --- 1.5 NHÓM TÀI KHOẢN ---
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 10),
              child: Text(
                "TÀI KHOẢN",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),

            // Dùng cảm biến để thay đổi giao diện động!
            ValueListenableBuilder<String?>(
              valueListenable: userTokenGlobal,
              builder: (context, token, child) {
                // NẾU CHƯA CÓ TOKEN -> HIỆN NÚT ĐĂNG NHẬP
                if (token == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: _buildMenuRow(
                      Icons.cloud_sync_rounded,
                      Colors.blue,
                      "Đăng nhập / Đăng ký",
                      "Lưu trữ và đồng bộ dữ liệu lên mây",
                    ),
                  );
                }
                // NẾU ĐÃ CÓ TOKEN -> HIỆN PROFILE VÀ NÚT ĐĂNG XUẤT
                else {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        // Hiện tên User lấy từ cảm biến
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            userNameGlobal.value ?? "Người dùng",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            "Đã đồng bộ dữ liệu",
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ),
                        const Divider(height: 1, indent: 60),
                        // NÚT ĐĂNG XUẤT
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            "Đăng xuất",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            // HÀNH ĐỘNG ĐĂNG XUẤT: Xóa két sắt, tắt cảm biến
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('jwt_token');
                            await prefs.remove('username');
                            userTokenGlobal.value = null;
                            userNameGlobal.value = null;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Đã đăng xuất an toàn!"),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
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
        // KIỂM TRA: NẾU BẤM VÀO "QUẢN LÝ DANH MỤC"
        if (title == "Quản lý Danh mục") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CategoryManagementScreen(),
            ),
          );
        }
        // KIỂM TRA: NẾU BẤM VÀO NÚT XUẤT EXCEL THÌ CHẠY HÀM (MỚI THÊM)
        else if (title == "Xuất báo cáo Excel") {
          _xuatBaoCaoExcel(); // Kích hoạt nhà máy!
        }
        // KIỂM TRA: NẾU BẤM VÀO NÚT XÓA THÌ GỌI HÀM HỦY DIỆT
        else if (title == "Xóa toàn bộ dữ liệu") {
          _xoaToanBoDuLieu();
        }
        //Kiểm tra đăng nhập
        else if (title == "Đăng nhập / Đăng ký") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      },
    );
  }
}
