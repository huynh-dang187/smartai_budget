import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart'; // Thư viện Chart
import 'dart:math'; // Random màu
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
    layDuLieuTuStrapi();
  }

  Future<void> layDuLieuTuStrapi() async {
    final url = Uri.parse(
      'http://172.25.91.167:1337/api/transactions?populate=*',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          danhSachGiaoDich = data['data'];
          dangTaiDuLieu = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi mạng: $e");
      setState(() => dangTaiDuLieu = false);
    }
  }

  // --- HÀM TÍNH TOÁN DỮ LIỆU BIỂU ĐỒ ---
  // --- HÀM TÍNH TOÁN DỮ LIỆU BIỂU ĐỒ (V2 - FIX LỖI ĐÈ CHỮ) ---
  List<PieChartSectionData> _taoDuLieuBieuDo() {
    Map<String, double> tongTienTheoDanhMuc = {};
    double tongTatCa = 0; // Thêm biến tính tổng tiền

    // 1. Chạy vòng lặp cộng dồn tiền
    for (var gd in danhSachGiaoDich) {
      double tien = (gd['amount'] ?? 0).toDouble();
      String tenDM = gd['category']?['Name'] ?? 'Khác';

      tongTienTheoDanhMuc[tenDM] = (tongTienTheoDanhMuc[tenDM] ?? 0) + tien;
      tongTatCa += tien; // Cộng vào tổng dùng để tính %
    }

    // 2. Biến nó thành các mảng màu của PieChart
    List<PieChartSectionData> cacMangMau = [];
    final List<Color> bangMau = [
      Colors.teal,
      Colors.orange,
      Colors.blue,
      Colors.redAccent,
      Colors.purple,
    ];
    int indexMau = 0;

    tongTienTheoDanhMuc.forEach((ten, tongTien) {
      // Tính xem mảng này chiếm bao nhiêu % trong tổng chi
      double phanTram = (tongTatCa == 0) ? 0 : (tongTien / tongTatCa);
      bool laMangNho = phanTram < 0.15; // Nhỏ hơn 15% coi như là mảng bé

      cacMangMau.add(
        PieChartSectionData(
          color: bangMau[indexMau % bangMau.length],
          value: tongTien,
          title: '$ten\n${(tongTien / 1000).toStringAsFixed(0)}k',

          // --- KỸ THUẬT TRÁNH ĐÈ CHỮ NẰM Ở ĐÂY ---
          // Nếu mảng nhỏ: Bơm bán kính to ra tí (90) để nó lồi ra ngoài tạo điểm nhấn
          radius: laMangNho ? 90 : 80,
          // Nếu mảng nhỏ: Đẩy text ra sát mép ngoài (0.75), ngược lại để ở giữa (0.5)
          titlePositionPercentageOffset: laMangNho ? 0.75 : 0.5,

          titleStyle: TextStyle(
            fontSize: laMangNho
                ? 10
                : 12, // Mảng bé thì chữ cũng phải thon thả lại
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      indexMau++;
    });

    return cacMangMau;
  }
  // -------------------------------------

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
          ? const Center(child: CircularProgressIndicator())
          : danhSachGiaoDich.isEmpty
          ? const Center(
              child: Text("Chưa có chi tiêu nào. Quá biết tiết kiệm!"),
            )
          : Column(
              children: [
                // --- KHU VỰC 1: BIỂU ĐỒ TRÒN ---
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: _taoDuLieuBieuDo(),
                          centerSpaceRadius:
                              40, // Lỗ hổng ở giữa (Tạo thành Donut Chart)
                          sectionsSpace: 2, // Khe hở giữa các mảng màu
                        ),
                        swapAnimationDuration: const Duration(
                          milliseconds: 800,
                        ), // Hiệu ứng xoay mượt mà
                      ),
                      const Text(
                        "Tổng chi",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 2), // Đường kẻ ngang phân cách
                // --- KHU VỰC 2: DANH SÁCH CHI TIÊU ---
                Expanded(
                  child: ListView.builder(
                    itemCount: danhSachGiaoDich.length,
                    itemBuilder: (context, index) {
                      final giaoDich = danhSachGiaoDich[index];
                      final soTien = giaoDich['amount'] ?? 0;
                      final ghiChu = giaoDich['note'] ?? 'Chưa có ghi chú';
                      // Lấy tên danh mục để in ra phụ đề
                      final tenDanhMuc =
                          giaoDich['category']?['Name'] ?? 'Khác';

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
                              Icons.monetization_on,
                              color: Colors.teal,
                            ), // Đổi icon chung chung
                          ),
                          title: Text(
                            ghiChu,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'Danh mục: $tenDanhMuc',
                          ), // Hiện rành mạch danh mục
                          trailing: Text(
                            '-$soTien đ',
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
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatAIScreen()),
          );
          layDuLieuTuStrapi(); // Chat xong tự động vẽ lại biểu đồ
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Trợ lý AI'),
      ),
    );
  }
}
