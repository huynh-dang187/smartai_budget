import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Format tiền và ngày tháng
import 'package:google_generative_ai/google_generative_ai.dart'; // Não AI
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Lấy key bí mật

import 'chat_ai_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List danhSachGiaoDich = [];
  bool dangTaiDuLieu = true;

  // 1. Biến lưu giữ Tháng/Năm hiện tại
  DateTime _thangHienTai = DateTime.now();

  // 2. BỘ LỌC THÔNG MINH: Chỉ lấy giao dịch của đúng tháng đang chọn
  List get _giaoDichTrongThang {
    return danhSachGiaoDich.where((gd) {
      if (gd['date'] == null) return false;
      DateTime ngayGD = DateTime.parse(gd['date']);
      return ngayGD.month == _thangHienTai.month &&
          ngayGD.year == _thangHienTai.year;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    layDuLieuTuStrapi();
  }

  Future<void> layDuLieuTuStrapi() async {
    final url = Uri.parse(
      'http://10.185.83.167:1337/api/transactions?populate=*', // Nhớ check lại IP mỗi ngày
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

  // --- HÀM TÍNH TOÁN DỮ LIỆU BIỂU ĐỒ (Chống đè chữ) ---
  List<PieChartSectionData> _taoDuLieuBieuDo() {
    Map<String, double> tongTienTheoDanhMuc = {};
    double tongTatCa = 0;

    for (var gd in _giaoDichTrongThang) {
      double tien = (gd['amount'] ?? 0).toDouble();
      String tenDM = gd['category']?['Name'] ?? 'Khác';

      tongTienTheoDanhMuc[tenDM] = (tongTienTheoDanhMuc[tenDM] ?? 0) + tien;
      tongTatCa += tien;
    }

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
      double phanTram = (tongTatCa == 0) ? 0 : (tongTien / tongTatCa);
      bool laMangNho = phanTram < 0.15;

      cacMangMau.add(
        PieChartSectionData(
          color: bangMau[indexMau % bangMau.length],
          value: tongTien,
          title: '$ten\n${(tongTien / 1000).toStringAsFixed(0)}k',
          radius: laMangNho ? 90 : 80,
          titlePositionPercentageOffset: laMangNho ? 0.75 : 0.5,
          titleStyle: TextStyle(
            fontSize: laMangNho ? 10 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      indexMau++;
    });

    return cacMangMau;
  }

  // --- HÀM GỌI AI PHÂN TÍCH TÀI CHÍNH ---
  Future<void> _hoiCoVanAI() async {
    if (_giaoDichTrongThang.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tháng này chưa tiêu đồng nào, không cần cố vấn đâu!'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String dataChiTieu = _giaoDichTrongThang
          .map(
            (gd) =>
                "- ${gd['note']}: ${(gd['amount'] ?? 0)} VNĐ (Mục: ${gd['category']?['Name'] ?? 'Khác'})",
          )
          .join('\n');

      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      final prompt =
          '''
        Bạn là một chuyên gia tài chính cá nhân vui tính.
        Dưới đây là chi tiêu tháng ${_thangHienTai.month}/${_thangHienTai.year} của tôi:
        $dataChiTieu
        
        Phân tích ngắn gọn:
        1. Nhận xét tổng quan.
        2. Khoản nào đang lãng phí nhất?
        3. Lời khuyên tiết kiệm.
        Trình bày rõ ràng, không dùng markdown quá phức tạp, thân thiện.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final loiKhuyen = response.text ?? "AI đang bận, bạn hỏi lại sau nhé!";

      if (mounted) Navigator.pop(context); // Đóng loading

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.6,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.blue, size: 35),
                        SizedBox(width: 10),
                        Text(
                          "Cố Vấn AI Phân Tích",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(thickness: 2, height: 30),
                    Text(
                      loiKhuyen,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Lỗi AI Cố vấn: $e");
    }
  }

  // --- HÀM HIỂN THỊ UI CHI TIẾT GIAO DỊCH ---
  void _hienThiChiTietGiaoDich(
    dynamic giaoDich,
    String formatTien,
    String idGiaoDich,
  ) {
    final ghiChu = giaoDich['note'] ?? 'Chưa có ghi chú';
    final tenDanhMuc = giaoDich['category']?['Name'] ?? 'Khác';
    DateTime dt = DateTime.parse(giaoDich['date']).toLocal();
    String ngayGio = DateFormat('dd/MM/yyyy - HH:mm').format(dt);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          // height: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.orange.shade100,
                child: const Icon(
                  Icons.receipt_long,
                  size: 35,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '- $formatTien',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Danh mục",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        Text(
                          tenDanhMuc,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Thời gian",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        Text(
                          ngayGio,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      label: const Text(
                        "Chỉnh sửa",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        // 1. Đóng cái bảng Bottom Sheet hiện tại lại
                        Navigator.pop(context);

                        // 2. Mở cái bảng Edit (Dialog) lên
                        _hienThiDialogSua(giaoDich, idGiaoDich);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        "Xóa ngay",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context); // Đóng bảng
                        // GỌI API XÓA
                        final deleteUrl = Uri.parse(
                          'http://10.185.83.167:1337/api/transactions/$idGiaoDich',
                        );
                        try {
                          await http.delete(deleteUrl);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🗑️ Đã xóa thành công!'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                          layDuLieuTuStrapi(); // Load lại data
                        } catch (e) {
                          debugPrint("Lỗi xóa: $e");
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HÀM 4: BẢNG CHỈNH SỬA GIAO DỊCH ---
  // --- HÀM 4: BẢNG CHỈNH SỬA GIAO DỊCH (Có sửa thời gian) ---
  void _hienThiDialogSua(dynamic giaoDich, String idGiaoDich) {
    // 1. Lấy dữ liệu cũ
    final TextEditingController tienController = TextEditingController(
      text: giaoDich['amount'].toString(),
    );
    final TextEditingController ghiChuController = TextEditingController(
      text: giaoDich['note'] ?? '',
    );

    // Ép kiểu thời gian từ Strapi thành giờ địa phương để chuẩn bị sửa
    DateTime thoiGianDuKien = DateTime.parse(giaoDich['date']).toLocal();

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder giúp Dialog tự động cập nhật UI khi ông đổi ngày giờ
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.blue),
                  SizedBox(width: 10),
                  Text(
                    "Sửa giao dịch",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min, // Chống tràn viền vàng đen
                children: [
                  // --- Ô NHẬP TIỀN ---
                  TextField(
                    controller: tienController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Số tiền",
                      prefixIcon: const Icon(
                        Icons.monetization_on,
                        color: Colors.orange,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- Ô NHẬP GHI CHÚ ---
                  TextField(
                    controller: ghiChuController,
                    decoration: InputDecoration(
                      labelText: "Ghi chú",
                      prefixIcon: const Icon(
                        Icons.description,
                        color: Colors.teal,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- NÚT CHỌN THỜI GIAN CỰC XỊN ---
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      // BƯỚC 1: Hiện lịch chọn Ngày
                      DateTime? ngayMoi = await showDatePicker(
                        context: context,
                        initialDate: thoiGianDuKien,
                        firstDate: DateTime(2000), // Cho lùi về năm 2000
                        lastDate: DateTime(2100), // Cho tiến tới năm 2100
                      );

                      if (ngayMoi != null) {
                        // BƯỚC 2: Hiện đồng hồ chọn Giờ
                        TimeOfDay? gioMoi = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(thoiGianDuKien),
                        );

                        if (gioMoi != null) {
                          // BƯỚC 3: Cập nhật lại thời gian dự kiến
                          setStateDialog(() {
                            thoiGianDuKien = DateTime(
                              ngayMoi.year,
                              ngayMoi.month,
                              ngayMoi.day,
                              gioMoi.hour,
                              gioMoi.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Thời gian",
                        prefixIcon: const Icon(
                          Icons.calendar_month,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy - HH:mm').format(thoiGianDuKien),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Hủy",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context); // Đóng popup

                    // 2. GỌI API CẬP NHẬT LÊN STRAPI (Kẹp thêm cái 'date' vào body)
                    final putUrl = Uri.parse(
                      'http://10.185.83.167:1337/api/transactions/$idGiaoDich',
                    );
                    try {
                      final response = await http.put(
                        putUrl,
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          "data": {
                            "amount": int.tryParse(tienController.text) ?? 0,
                            "note": ghiChuController.text,
                            // Convert giờ địa phương về chuẩn ISO (UTC) để Strapi dễ hiểu
                            "date": thoiGianDuKien.toUtc().toIso8601String(),
                          },
                        }),
                      );

                      if (response.statusCode == 200) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✨ Đã cập nhật thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        layDuLieuTuStrapi(); // Vẽ lại giao diện
                      }
                    } catch (e) {
                      debugPrint("Lỗi cập nhật: $e");
                    }
                  },
                  child: const Text(
                    "Lưu lại",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
        // NÚT BẤM GỌI CỐ VẤN AI
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology, size: 28),
            tooltip: 'Hỏi Cố vấn AI',
            onPressed: _hoiCoVanAI,
          ),
        ],
      ),
      body: dangTaiDuLieu
          ? const Center(child: CircularProgressIndicator())
          : danhSachGiaoDich.isEmpty
          ? const Center(
              child: Text("Chưa có chi tiêu nào. Quá biết tiết kiệm!"),
            )
          : Column(
              children: [
                // --- KHU VỰC 1: HEADER THỜI GIAN & TỔNG QUAN ---
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _thangHienTai = DateTime(
                                  _thangHienTai.year,
                                  _thangHienTai.month - 1,
                                );
                              });
                            },
                          ),
                          Text(
                            'Tháng ${_thangHienTai.month} năm ${_thangHienTai.year}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _thangHienTai = DateTime(
                                  _thangHienTai.year,
                                  _thangHienTai.month + 1,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Tổng chi tiêu",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: 'đ',
                        ).format(
                          _giaoDichTrongThang.fold(
                            0.0,
                            (tong, gd) => tong + (gd['amount'] ?? 0).toDouble(),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // --- KHU VỰC 2: BIỂU ĐỒ TRÒN ---
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: _taoDuLieuBieuDo(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                        swapAnimationDuration: const Duration(
                          milliseconds: 800,
                        ),
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
                const Divider(thickness: 2),
                // --- KHU VỰC 3: DANH SÁCH CHI TIÊU ---
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _giaoDichTrongThang.length,
                    itemBuilder: (context, index) {
                      final giaoDich = _giaoDichTrongThang[index];
                      final idGiaoDich = giaoDich['documentId'].toString();
                      final soTien = giaoDich['amount'] ?? 0;
                      final ghiChu = giaoDich['note'] ?? 'Chưa có ghi chú';
                      final tenDanhMuc =
                          giaoDich['category']?['Name'] ?? 'Khác';

                      final formatTien = NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: 'đ',
                      ).format(soTien);

                      // DÙNG INKWELL ĐỂ TẠO HIỆU ỨNG CHẠM GỌI BOTTOM SHEET
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _hienThiChiTietGiaoDich(
                            giaoDich,
                            formatTien,
                            idGiaoDich,
                          );
                        },
                        child: Card(
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
                              ),
                            ),
                            title: Text(
                              ghiChu,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text('Danh mục: $tenDanhMuc'),
                            trailing: Text(
                              '-$formatTien',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () async {
      //     await Navigator.push(
      //       context,
      //       MaterialPageRoute(builder: (context) => const ChatAIScreen()),
      //     );
      //     layDuLieuTuStrapi();
      //   },
      //   icon: const Icon(Icons.auto_awesome),
      //   label: const Text('Trợ lý AI'),
      // ),
    );
  }
}
