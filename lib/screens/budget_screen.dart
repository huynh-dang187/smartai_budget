import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _dangTai = true;

  // Tổng hạn mức (Giả sử tháng này ông quyết tâm chỉ tiêu tối đa 5 củ)
  final double tongNganSach = 5000000;
  double tongDaTieu = 0.0; // Sẽ được tính toán tự động từ API

  // Khai báo sẵn các Hạn mức (Chưa có tiền đã tiêu)
  List<Map<String, dynamic>> danhSachNganSach = [
    {
      "ten": "Ăn uống", // Từ khóa để map với API
      "daTieu": 0.0,
      "hanMuc": 2500000.0,
      "icon": Icons.fastfood_rounded,
      "mauIcon": Colors.orange,
    },
    {
      "ten": "Giải Trí",
      "daTieu": 0.0,
      "hanMuc": 1000000.0, // Cho game, xem phim...
      "icon": Icons.sports_esports_rounded,
      "mauIcon": Colors.purple,
    },
    {
      "ten": "Học Phí",
      "daTieu": 0.0,
      "hanMuc": 1000000.0, // Quỹ học hành
      "icon": Icons.menu_book_rounded,
      "mauIcon": Colors.blue,
    },
    {
      "ten": "Khác",
      "daTieu": 0.0,
      "hanMuc": 500000.0,
      "icon": Icons.category_rounded,
      "mauIcon": Colors.grey,
    },
  ];

  @override
  void initState() {
    super.initState();
    _dongBoDuLieuTuStrapi();
  }

  // --- HÀM MA THUẬT: ĐỌC CHI TIÊU & BƠM VÀO NGÂN SÁCH ---
  Future<void> _dongBoDuLieuTuStrapi() async {
    final url = Uri.parse(
      'http://10.185.83.167:1337/api/transactions?populate=*',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List giaoDich = data['data'];

        DateTime now = DateTime.now();
        double tongTienThangNay = 0;

        // Tạo một bộ đếm tạm thời cho các danh mục
        Map<String, double> tienTheoDanhMuc = {
          "Ăn uống": 0,
          "Giải Trí": 0,
          "Học Phí": 0,
          "Khác": 0,
        };

        // 1. Lọc giao dịch trong tháng hiện tại và cộng dồn tiền
        for (var gd in giaoDich) {
          if (gd['date'] == null) continue;
          DateTime dt = DateTime.parse(gd['date']).toLocal();

          if (dt.month == now.month && dt.year == now.year) {
            double tien = (gd['amount'] ?? 0).toDouble();
            tongTienThangNay += tien; // Cộng vào tổng

            String tenDM = gd['category']?['Name'] ?? 'Khác';
            // Nếu danh mục có trong danh sách ngân sách thì cộng vào, không thì vứt vào "Khác"
            if (tienTheoDanhMuc.containsKey(tenDM)) {
              tienTheoDanhMuc[tenDM] = tienTheoDanhMuc[tenDM]! + tien;
            } else {
              tienTheoDanhMuc["Khác"] = tienTheoDanhMuc["Khác"]! + tien;
            }
          }
        }

        // 2. Bơm tiền vào UI để các thanh Progress Bar chạy
        setState(() {
          tongDaTieu = tongTienThangNay;
          for (var nganSach in danhSachNganSach) {
            String ten = nganSach['ten'];
            nganSach['daTieu'] = tienTheoDanhMuc[ten] ?? 0.0;
          }
          _dangTai = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ: $e");
      setState(() => _dangTai = false);
    }
  }

  String _formatTien(num tien) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(tien);
  }

  // Hàm vẽ THANH TIẾN TRÌNH BIẾT ĐỔI MÀU (Giữ nguyên đồ xịn)
  Widget _veThanhTienTrinh(double daTieu, double hanMuc) {
    double phanTram = hanMuc <= 0 ? 0.0 : daTieu / hanMuc;
    if (phanTram > 1.0) phanTram = 1.0;
    if (phanTram.isNaN || phanTram.isInfinite) phanTram = 0.0;

    Color mauThanh = Colors.green.shade400;
    if (phanTram >= 0.85)
      mauThanh = Colors.redAccent;
    else if (phanTram >= 0.5)
      mauThanh = Colors.orange.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: phanTram,
            heightFactor: 1.0,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 1000,
              ), // Hiệu ứng chạy từ từ cực phê
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: mauThanh,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đã dùng ${(phanTram * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: phanTram >= 0.85 ? Colors.redAccent : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: phanTram >= 0.85 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double phanTramTong = tongNganSach <= 0 ? 0.0 : tongDaTieu / tongNganSach;
    if (phanTramTong > 1.0) phanTramTong = 1.0;
    if (phanTramTong.isNaN || phanTramTong.isInfinite) phanTramTong = 0.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Quản lý Ngân sách',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.sync,
              color: Colors.blueAccent,
              size: 28,
            ), // Đổi thành icon Sync (Đồng bộ)
            onPressed: () {
              setState(() => _dangTai = true);
              _dongBoDuLieuTuStrapi(); // Bấm nút này để ép app tính toán lại tiền ngay lập tức
            },
          ),
        ],
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // --- 1. THẺ TỔNG QUAN ---
                  Container(
                    margin: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng ngân sách tháng này',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatTien(tongNganSach),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: phanTramTong,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đã tiêu: ${_formatTien(tongDaTieu)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Còn lại: ${_formatTien(tongNganSach - tongDaTieu)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- 2. DANH SÁCH NGÂN SÁCH THỰC TẾ ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Chi tiết hạng mục',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Chỉnh sửa'),
                        ),
                      ],
                    ),
                  ),

                  ...danhSachNganSach.map((nganSach) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: nganSach['mauIcon']
                                    .withOpacity(0.1),
                                child: Icon(
                                  nganSach['icon'],
                                  color: nganSach['mauIcon'],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nganSach['ten'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatTien(nganSach['daTieu'])} / ${_formatTien(nganSach['hanMuc'])}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _veThanhTienTrinh(
                            nganSach['daTieu'].toDouble(),
                            nganSach['hanMuc'].toDouble(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
