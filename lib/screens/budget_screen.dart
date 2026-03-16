import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _dangTai = true;
  late SharedPreferences _prefs;

  double tongNganSach = 0.0;
  double tongDaTieu = 0.0;

  // Xóa sạch Hard-code! Giờ nó là một mảng rỗng đợi Strapi rót data vào
  List<Map<String, dynamic>> danhSachNganSach = [];

  @override
  void initState() {
    super.initState();
    _khoiTaoDuLieu();
  }

  // --- COMBO 3 BƯỚC KHỞI TẠO ĐỘNG ---
  Future<void> _khoiTaoDuLieu() async {
    _prefs = await SharedPreferences.getInstance();
    await _taiDanhSachDanhMucTuStrapi(); // Bước 1: Kéo danh mục từ mây về
    _taiHanMucDaLuu(); // Bước 2: Gắn hạn mức từ két sắt
    await _dongBoDuLieuTuStrapi(); // Bước 3: Kéo thu chi về để tính toán
  }

  // BƯỚC 1: LẤY DANH MỤC (MỚI)
  Future<void> _taiDanhSachDanhMucTuStrapi() async {
    final url = Uri.parse('http://10.185.83.167:1337/api/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List categories = data['data'];

        List<Map<String, dynamic>> dmTam = [];
        for (var item in categories) {
          final attrs = item['attributes'] ?? item;
          String tenDM = attrs['Name'] ?? 'Khác';

          IconData icon = Icons.category_rounded;
          Color mau = Colors.blueGrey;

          // 1. ƯU TIÊN LẤY TỪ STRAPI VỀ (Cho mấy danh mục ông mới tạo như Wifi)
          bool hasCustomIcon =
              attrs['Icon'] != null && attrs['Icon'].toString().isNotEmpty;
          bool hasCustomColor =
              attrs['Color'] != null && attrs['Color'].toString().isNotEmpty;

          if (hasCustomIcon) {
            icon = IconData(
              int.parse(attrs['Icon'].toString()),
              fontFamily: 'MaterialIcons',
            );
          }
          if (hasCustomColor) {
            mau = Color(int.parse(attrs['Color'].toString(), radix: 16));
          }

          // 2. PHAO CỨU SINH CHO DANH MỤC CŨ (Ăn uống, Giải trí, Học phí...)
          if (!hasCustomIcon || !hasCustomColor) {
            String tenToLowerCase = tenDM.toLowerCase();
            if (tenToLowerCase.contains('ăn')) {
              if (!hasCustomIcon) icon = Icons.fastfood_rounded;
              if (!hasCustomColor) mau = Colors.orange;
            } else if (tenToLowerCase.contains('giải') ||
                tenToLowerCase.contains('chơi')) {
              if (!hasCustomIcon) icon = Icons.sports_esports_rounded;
              if (!hasCustomColor) mau = Colors.purple;
            } else if (tenToLowerCase.contains('học')) {
              if (!hasCustomIcon) icon = Icons.school_rounded;
              if (!hasCustomColor) mau = Colors.blue;
            } else if (tenToLowerCase.contains('nhà') ||
                tenToLowerCase.contains('trọ')) {
              if (!hasCustomIcon) icon = Icons.home_rounded;
              if (!hasCustomColor) mau = Colors.teal;
            }
          }

          dmTam.add({
            "ten": tenDM,
            "daTieu": 0.0,
            "hanMuc": 1000000.0,
            "icon": icon,
            "mauIcon": mau,
          });
        }

        setState(() {
          danhSachNganSach = dmTam;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải danh mục: $e");
    }
  }

  // BƯỚC 2: GẮN HẠN MỨC
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

  // BƯỚC 3: LẤY GIAO DỊCH TÍNH TIỀN (ĐÃ FIX LỖI 0 ĐỒNG)
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

        Map<String, double> tienTheoDanhMuc = {};

        for (var gd in giaoDich) {
          final attrs = gd['attributes'] ?? gd;
          if (attrs['date'] == null) continue;
          DateTime dt = DateTime.parse(attrs['date']).toLocal();

          if (dt.month == now.month && dt.year == now.year) {
            double tien = (attrs['amount'] ?? 0).toDouble();
            tongTienThangNay += tien;

            // --- ĐOẠN FIX LỖI Ở ĐÂY: Dùng lại logic đọc JSON chuẩn xác của ông ---
            String tenDM = 'Khác';
            if (attrs['category'] != null) {
              var cat = attrs['category'];
              // Thử đọc kiểu cũ của ông (Không có data/attributes)
              if (cat['Name'] != null) {
                tenDM = cat['Name'];
              }
              // Thử đọc kiểu Strapi v4 gốc (nếu có)
              else if (cat['data'] != null) {
                tenDM =
                    (cat['data']['attributes'] ?? cat['data'])['Name'] ??
                    'Khác';
              }
            }
            // ----------------------------------------------------------------------

            tienTheoDanhMuc[tenDM] = (tienTheoDanhMuc[tenDM] ?? 0) + tien;
          }
        }

        setState(() {
          tongDaTieu = tongTienThangNay;
          // Áp tiền đã tiêu vào đúng danh mục động
          for (var nganSach in danhSachNganSach) {
            nganSach['daTieu'] = tienTheoDanhMuc[nganSach['ten']] ?? 0.0;
          }
          _dangTai = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ giao dịch: $e");
      setState(() => _dangTai = false);
    }
  }

  // --- BẢNG TÙY CHỈNH HẠN MỨC (TỰ ĐỘNG THÍCH ỨNG VỚI DANH MỤC MỚI) ---
  void _hienThiBangSuaHanMuc() {
    Map<String, TextEditingController> controllers = {};
    for (var ns in danhSachNganSach) {
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: "Hạn mức ${ns['ten']}",
                        prefixIcon: Icon(ns['icon'], color: ns['mauIcon']),
                        suffixText: "VNĐ",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.grey),
                          onPressed: () => controllers[ns['ten']]!.clear(),
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
                          content: Text("✨ Đã lưu cấu hình ngân sách!"),
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

  String _formatTien(num tien) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(tien);

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
              _khoiTaoDuLieu(); // Load lại toàn bộ Combo
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
                          onPressed: danhSachNganSach.isEmpty
                              ? null
                              : _hienThiBangSuaHanMuc,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text(
                            'Chỉnh sửa',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (danhSachNganSach.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        "Chưa có danh mục nào. Hãy vào Cài đặt để thêm!",
                        style: TextStyle(color: Colors.grey),
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

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');
    final int value = int.parse(digitsOnly);
    final String formatted = NumberFormat(
      '#,###',
      'vi_VN',
    ).format(value).replaceAll(',', '.');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
