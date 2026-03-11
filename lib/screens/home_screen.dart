import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Thư viện gọi mạng
import 'dart:convert'; // Thư viện dịch cục JSON
import 'chat_ai_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List danhSachGiaoDich = [];
  bool dangTaiDuLieu = true;

  @override
  void initState() {
    super.initState();
    layDuLieuTuStrapi(); // Vừa mở app lên là gọi Strapi luôn
  }

  Future<void> layDuLieuTuStrapi() async {
    // THAY IP CỦA ÔNG VÀO ĐÂY (Giữ nguyên cổng :1337)
    final url = Uri.parse(
      'http://172.25.91.167:1337/api/transactions?populate=*',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Dịch JSON
        setState(() {
          danhSachGiaoDich = data['data']; // Bỏ data vào danh sách
          dangTaiDuLieu = false; // Tắt vòng xoay loading
        });
      }
    } catch (e) {
      debugPrint("Lỗi mạng gòi: $e");
      setState(() => dangTaiDuLieu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart AI Budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: dangTaiDuLieu
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Đang tải thì xoay xoay
          : danhSachGiaoDich.isEmpty
          ? const Center(
              child: Text("Chưa có chi tiêu nào. Quá biết tiết kiệm!"),
            )
          : ListView.builder(
              itemCount: danhSachGiaoDich.length,
              itemBuilder: (context, index) {
                // Strapi v4 giấu data trong cái vỏ bọc tên là 'attributes'
                // Lấy thẳng dữ liệu luôn, bỏ luôn chữ attributes
                final giaoDich = danhSachGiaoDich[index];

                // Tiện tay thêm cái dấu ?? để lỡ API nó thiếu chữ thì app cũng không bị crash
                final soTien = giaoDich['amount'] ?? 0;
                final ghiChu = giaoDich['note'] ?? 'Chưa có ghi chú';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(
                        Icons.fastfood,
                        color: Colors.teal,
                      ), // Tạm để icon đồ ăn
                    ),
                    title: Text(
                      ghiChu,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      'Hôm nay',
                    ), // Mốt mình sẽ format ngày giờ sau
                    trailing: Text(
                      '-$soTien đ', // Hiển thị số tiền màu đỏ
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatAIScreen()),
          );
        },
        icon: const Icon(Icons.auto_awesome), // Đổi icon nhìn cho có vẻ AI xíu
        label: const Text('Trợ lý AI'),
      ),
    );
  }
}
