import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List _toanBoGiaoDich = [];
  List _giaoDichHienThi = []; // Danh sách dùng để lọc khi tìm kiếm
  bool _dangTai = true;
  final TextEditingController _timKiemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _layDuLieuTuStrapi();
  }

  Future<void> _layDuLieuTuStrapi() async {
    int? myId = userIdGlobal.value;
    final url = Uri.parse(
      'http://10.57.162.167:1337/api/transactions?populate=*&filters[user][id][\$eq]=$myId',
    );
    try {
      // 1. Lấy Token từ bộ nhớ ra (Ông nhớ check lại tên key 'token' xem đúng với tên lúc ông lưu ở màn hình Login không nhé)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(
        'jwt_token',
      ); // Có thể là 'jwt' hoặc 'jwt_token'

      // 2. Gắn Token vào Header
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _toanBoGiaoDich = data['data']
            ..sort((a, b) {
              DateTime dateA = DateTime.parse(
                a['date'] ?? DateTime.now().toIso8601String(),
              );
              DateTime dateB = DateTime.parse(
                b['date'] ?? DateTime.now().toIso8601String(),
              );
              return dateB.compareTo(dateA);
            });
          _giaoDichHienThi = _toanBoGiaoDich;
          _dangTai = false; // Tắt vòng xoay
        });
      } else {
        // 3. THÊM ELSE ĐỂ BẮT LỖI SILENT
        debugPrint(
          "Lỗi Strapi từ chối: ${response.statusCode} - ${response.body}",
        );
        setState(() => _dangTai = false); // Bị lỗi cũng phải tắt vòng xoay
      }
    } catch (e) {
      debugPrint("Lỗi mạng: $e");
      setState(() => _dangTai = false);
    }
  }

  // Lọc danh sách khi gõ vào thanh tìm kiếm
  void _locGiaoDich(String tuKhoa) {
    setState(() {
      if (tuKhoa.isEmpty) {
        _giaoDichHienThi = _toanBoGiaoDich;
      } else {
        _giaoDichHienThi = _toanBoGiaoDich.where((gd) {
          final ghiChu = (gd['note'] ?? '').toLowerCase();
          final danhMuc = (gd['category']?['Name'] ?? '').toLowerCase();
          return ghiChu.contains(tuKhoa.toLowerCase()) ||
              danhMuc.contains(tuKhoa.toLowerCase());
        }).toList();
      }
    });
  }

  // THUẬT TOÁN GOM NHÓM THEO NGÀY
  Map<String, List<dynamic>> _gomNhomTheoNgay(List data) {
    Map<String, List<dynamic>> danhSachDaGom = {};
    for (var gd in data) {
      if (gd['date'] == null) continue;
      DateTime dt = DateTime.parse(gd['date']).toLocal();
      // Format ngày làm chìa khóa (Key) ví dụ: "14/03/2026"
      String ngayKey = DateFormat('dd/MM/yyyy').format(dt);

      if (!danhSachDaGom.containsKey(ngayKey)) {
        danhSachDaGom[ngayKey] = [];
      }
      danhSachDaGom[ngayKey]!.add(gd);
    }
    return danhSachDaGom;
  }

  @override
  Widget build(BuildContext context) {
    // Gọi hàm gom nhóm dữ liệu trước khi vẽ
    final duLieuDaGom = _gomNhomTheoNgay(_giaoDichHienThi);
    final danhSachNgay = duLieuDaGom.keys.toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Sổ thu chi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- THANH TÌM KIẾM ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: TextField(
              controller: _timKiemController,
              onChanged: _locGiaoDich, // Vừa gõ vừa lọc luôn cho nóng
              decoration: InputDecoration(
                hintText: 'Tìm kiếm chi tiêu...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // --- DANH SÁCH GIAO DỊCH ĐÃ GOM NHÓM ---
          Expanded(
            child: _dangTai
                ? const Center(child: CircularProgressIndicator())
                : duLieuDaGom.isEmpty
                ? const Center(
                    child: Text(
                      "Không tìm thấy giao dịch nào!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 100,
                    ), // Độn đáy tránh nút AI
                    itemCount: danhSachNgay.length,
                    itemBuilder: (context, index) {
                      String ngay = danhSachNgay[index];
                      List giaoDichTrongNgay = duLieuDaGom[ngay]!;

                      // Tính tổng tiền của ngày đó
                      double tongTienNgay = giaoDichTrongNgay.fold(
                        0.0,
                        (tong, gd) => tong + (gd['amount'] ?? 0).toDouble(),
                      );
                      String formatTongTien = NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: 'đ',
                      ).format(tongTienNgay);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER CỦA NGÀY (Theme xanh chủ đạo rực rỡ)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors
                                    .blue
                                    .shade50, // Đổ nền xanh pastel nhẹ nhàng
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Cụm bên trái: Icon + Ngày tháng (Màu xanh đậm)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        size: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        ngay,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Colors
                                              .blue
                                              .shade900, // Chữ xanh đồng bộ với app
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Cụm bên phải: Tổng tiền (Đóng vào một cái Badge bo tròn)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .red
                                          .shade50, // Nền đỏ nhạt cảnh báo chi tiền
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '- $formatTongTien',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors
                                            .red
                                            .shade700, // Chữ đỏ đậm rực rỡ
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              color: Colors.transparent,
                            ), // Cho thanh kẻ ngang tàng hình luôn cho mượt
                            // DANH SÁCH CÁC MÓN TIÊU TRONG NGÀY
                            ...giaoDichTrongNgay.map((gd) {
                              final soTien = gd['amount'] ?? 0;
                              final ghiChu = gd['note'] ?? 'Chưa có ghi chú';
                              final tenDanhMuc =
                                  gd['category']?['Name'] ?? 'Khác';
                              final formatTien = NumberFormat.currency(
                                locale: 'vi_VN',
                                symbol: '',
                              ).format(soTien); // Bỏ chữ đ đi cho gọn

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.teal.shade50,
                                  child: const Icon(
                                    Icons.monetization_on,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  ghiChu,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  tenDanhMuc,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Text(
                                  formatTien,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
