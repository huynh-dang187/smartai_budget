import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // <--- Thêm thư viện này để bắt sự kiện gõ phím

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _dangTai = true;
  late SharedPreferences _prefs;

  double tongNganSach = 5000000;
  double tongDaTieu = 0.0;

  List<Map<String, dynamic>> danhSachNganSach = [
    {
      "ten": "Ăn uống",
      "daTieu": 0.0,
      "hanMuc": 2500000.0,
      "icon": Icons.fastfood_rounded,
      "mauIcon": Colors.orange,
    },
    {
      "ten": "Giải Trí",
      "daTieu": 0.0,
      "hanMuc": 1000000.0,
      "icon": Icons.sports_esports_rounded,
      "mauIcon": Colors.purple,
    },
    {
      "ten": "Học Phí",
      "daTieu": 0.0,
      "hanMuc": 1000000.0,
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
    _khoiTaoDuLieu();
  }

  Future<void> _khoiTaoDuLieu() async {
    _prefs = await SharedPreferences.getInstance();
    _taiHanMucDaLuu();
    await _dongBoDuLieuTuStrapi();
  }

  void _taiHanMucDaLuu() {
    double tongMoi = 0;
    for (var nganSach in danhSachNganSach) {
      String key = 'hanMuc_${nganSach['ten']}';
      double savedHanMuc = _prefs.getDouble(key) ?? nganSach['hanMuc'];
      nganSach['hanMuc'] = savedHanMuc;
      tongMoi += savedHanMuc;
    }
    setState(() {
      tongNganSach = tongMoi;
    });
  }

  // --- BẢNG TÙY CHỈNH HẠN MỨC (ĐÃ NÂNG CẤP AUTO FORMAT) ---
  void _hienThiBangSuaHanMuc() {
    Map<String, TextEditingController> controllers = {};
    for (var ns in danhSachNganSach) {
      // Ép dữ liệu cũ hiển thị sẵn dấu chấm (VD: 2.500.000)
      String soTienCu = NumberFormat(
        '#,###',
        'vi_VN',
      ).format(ns['hanMuc']).replaceAll(',', '.');
      controllers[ns['ten']] = TextEditingController(text: soTienCu);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Tùy chỉnh Hạn mức",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Thiết lập ngân sách cho tháng này",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),

                ...danhSachNganSach.map((ns) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: TextField(
                      controller: controllers[ns['ten']],
                      keyboardType: TextInputType.number,
                      // NHÚNG BỘ LỌC VÀO ĐÂY: Chỉ cho nhập số và tự động phẩy
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // Chặn nhập chữ
                        CurrencyInputFormatter(), // Tự động thêm dấu chấm
                      ],
                      decoration: InputDecoration(
                        labelText: "Hạn mức ${ns['ten']}",
                        prefixIcon: Icon(ns['icon'], color: ns['mauIcon']),
                        suffixText: "VNĐ",
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color.fromARGB(255, 82, 80, 76),
                          ),
                          onPressed: () {
                            controllers[ns['ten']]!
                                .clear(); // Xóa trắng ô nhập trong 1 nốt nhạc
                          },
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () async {
                    double tongTienMoi = 0;

                    for (var ns in danhSachNganSach) {
                      // TRƯỚC KHI LƯU: Phải lột sạch dấu chấm đi mới ép kiểu về double được
                      String chuoiSoSanh = controllers[ns['ten']]!.text
                          .replaceAll(RegExp(r'[^0-9]'), '');
                      double val = double.tryParse(chuoiSoSanh) ?? 0.0;

                      ns['hanMuc'] = val;
                      tongTienMoi += val;
                      await _prefs.setDouble('hanMuc_${ns['ten']}', val);
                    }

                    setState(() {
                      tongNganSach = tongTienMoi;
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✨ Đã lưu cấu hình ngân sách mới!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "Lưu Thiết Lập",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HÀM ĐỒNG BỘ STRAPI ---
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

        Map<String, double> tienTheoDanhMuc = {
          "Ăn uống": 0,
          "Giải Trí": 0,
          "Học Phí": 0,
          "Khác": 0,
        };

        for (var gd in giaoDich) {
          if (gd['date'] == null) continue;
          DateTime dt = DateTime.parse(gd['date']).toLocal();

          if (dt.month == now.month && dt.year == now.year) {
            double tien = (gd['amount'] ?? 0).toDouble();
            tongTienThangNay += tien;

            String tenDM = gd['category']?['Name'] ?? 'Khác';
            if (tienTheoDanhMuc.containsKey(tenDM)) {
              tienTheoDanhMuc[tenDM] = tienTheoDanhMuc[tenDM]! + tien;
            } else {
              tienTheoDanhMuc["Khác"] = tienTheoDanhMuc["Khác"]! + tien;
            }
          }
        }

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
              duration: const Duration(milliseconds: 1000),
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
            icon: const Icon(Icons.sync, color: Colors.blueAccent, size: 28),
            onPressed: () {
              setState(() => _dangTai = true);
              _dongBoDuLieuTuStrapi();
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
                        TextButton.icon(
                          onPressed: _hienThiBangSuaHanMuc,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text(
                            'Chỉnh sửa',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

// ==========================================
// CLASS CHUYÊN DỤNG ĐỂ AUTO FORMAT TIỀN TỆ
// ==========================================
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Lột sạch mọi thứ, chỉ giữ lại số
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    // Dùng thư viện intl để nhét dấu chấm vào giữa các số
    final int value = int.parse(digitsOnly);
    final String formatted = NumberFormat(
      '#,###',
      'vi_VN',
    ).format(value).replaceAll(',', '.');

    // Trả lại text đã format và đẩy con trỏ chuột về cuối dòng
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
