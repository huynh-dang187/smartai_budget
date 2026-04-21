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

  // Lấy icon danh mục dựa trên tên
  IconData _layIconDanhMuc(String tenDanhMuc) {
    final ten = tenDanhMuc.toLowerCase();
    if (ten.contains('ăn') || ten.contains('uống'))
      return Icons.fastfood_rounded;
    if (ten.contains('đi')) return Icons.directions_car_rounded;
    if (ten.contains('học')) return Icons.school_rounded;
    if (ten.contains('giải trí')) return Icons.sports_esports_rounded;
    if (ten.contains('nhà') || ten.contains('trọ')) return Icons.home_rounded;
    if (ten.contains('sức khỏe') || ten.contains('y tế'))
      return Icons.health_and_safety_rounded;
    if (ten.contains('quần áo')) return Icons.shopping_bag_rounded;
    return Icons.receipt_long_rounded;
  }

  // Lấy màu danh mục
  Color _layMauDanhMuc(String tenDanhMuc) {
    final ten = tenDanhMuc.toLowerCase();
    if (ten.contains('ăn') || ten.contains('uống')) return Colors.orange;
    if (ten.contains('đi')) return Colors.blue;
    if (ten.contains('học')) return Colors.purple;
    if (ten.contains('giải trí')) return Colors.pink;
    if (ten.contains('nhà') || ten.contains('trọ')) return Colors.teal;
    if (ten.contains('sức khỏe') || ten.contains('y tế')) return Colors.green;
    if (ten.contains('quần áo')) return Colors.indigo;
    return Colors.grey;
  }

  Future<void> _layDuLieuTuStrapi() async {
    int? myId = userIdGlobal.value;
    // 🔒 MIDDLEWARE will filter by user on backend
    final url = Uri.parse(
      'http://139.59.242.7:1337/api/transactions?populate=category&populate=user',
    );
    try {
      // 1. Lấy Token từ bộ nhớ ra
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
        List allTransactions = data['data'] ?? [];

        debugPrint(
          '\n🔍 [TX_SCREEN] Got ${allTransactions.length} transactions',
        );
        if (allTransactions.isNotEmpty) {
          var first = allTransactions[0];
          debugPrint('First TX keys: ${first.keys.toList()}');
          debugPrint('First TX user: ${first['user']}');
        }

        // 🔒 BACKEND NOW FILTERS - Keep this as double-check only
        // Try multiple paths to find user ID
        final List giaoDichLocRoi = allTransactions.where((t) {
          int? userId;

          // Path 1: Direct user.id (from POST response format)
          if (t['user'] is Map && t['user']['id'] != null) {
            userId = t['user']['id'];
            debugPrint('TX ${t['id']}: Path 1 (user.id) -> $userId');
          }
          // Path 2: Nested user.data.id
          else if (t['user'] is Map &&
              t['user']['data'] is Map &&
              t['user']['data']['id'] != null) {
            userId = t['user']['data']['id'];
            debugPrint('TX ${t['id']}: Path 2 (user.data.id) -> $userId');
          }
          // Path 3: Via attributes
          else if (t['attributes'] is Map && t['attributes']['user'] is Map) {
            var userObj = t['attributes']['user'];
            userId = userObj['data']?['id'] ?? userObj['id'];
            debugPrint('TX ${t['id']}: Path 3 (attributes.user) -> $userId');
          }

          if (userId == null) {
            debugPrint('TX ${t['id']}: ❌ NO USER FOUND');
            return false;
          }

          bool match = userId == myId;
          debugPrint('TX ${t['id']}: $userId == $myId ? $match');
          return match;
        }).toList();

        debugPrint(
          "📊 After filter: ${giaoDichLocRoi.length}/${allTransactions.length} for user $myId\n",
        );

        setState(() {
          _toanBoGiaoDich = giaoDichLocRoi
            ..sort((a, b) {
              try {
                final attrsA = a['attributes'] ?? a;
                final attrsB = b['attributes'] ?? b;
                DateTime dateA = DateTime.parse(
                  attrsA['date'] ??
                      attrsA['createdAt'] ??
                      DateTime.now().toIso8601String(),
                );
                DateTime dateB = DateTime.parse(
                  attrsB['date'] ??
                      attrsB['createdAt'] ??
                      DateTime.now().toIso8601String(),
                );
                return dateB.compareTo(dateA); // Mới nhất lên trên
              } catch (e) {
                debugPrint('❌ Lỗi sort: $e');
                return 0;
              }
            });
          _giaoDichHienThi = _toanBoGiaoDich;
          _dangTai = false; // Tắt vòng xoay
        });
      } else {
        debugPrint(
          "Lỗi Strapi từ chối: ${response.statusCode} - ${response.body}",
        );
        setState(() => _dangTai = false);
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
          final attrs = gd['attributes'] ?? gd;
          final ghiChu = (attrs['note'] ?? '').toLowerCase();
          // Lấy tên danh mục từ nested object
          var catObj = attrs['category']?['data'];
          String danhMuc = 'Khác';
          if (catObj != null) {
            danhMuc =
                (catObj['attributes']?['Name'] ?? catObj['Name'] ?? 'Khác')
                    .toLowerCase();
          }
          return ghiChu.contains(tuKhoa.toLowerCase()) ||
              danhMuc.contains(tuKhoa.toLowerCase());
        }).toList();
      }
    });
  }

  // HELPER: Lấy giá trị từ nested Strapi object
  String _layNgayTuGiaoDich(dynamic gd) {
    final attrs = gd['attributes'] ?? gd;
    final dateStr = attrs['date'] ?? attrs['createdAt'];
    if (dateStr == null) return '';
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      debugPrint('❌ Lỗi parse date: $dateStr - $e');
      return '';
    }
  }

  // THUẬT TOÁN GOM NHÓM THEO NGÀY
  Map<String, List<dynamic>> _gomNhomTheoNgay(List data) {
    Map<String, List<dynamic>> danhSachDaGom = {};
    for (var gd in data) {
      String ngayKey = _layNgayTuGiaoDich(gd);
      if (ngayKey.isEmpty) {
        debugPrint('⚠️ Bỏ qua giao dịch không có ngày: ${gd['id']}');
        continue;
      }

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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Chưa có giao dịch nào",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Hãy thêm chi tiêu của bạn",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _layDuLieuTuStrapi,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Tải lại"),
                        ),
                      ],
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
                      double tongTienNgay = giaoDichTrongNgay.fold(0.0, (
                        tong,
                        gd,
                      ) {
                        final attrs = gd['attributes'] ?? gd;
                        return tong +
                            ((attrs['amount'] ?? 0) as num).toDouble();
                      });
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
                              final attrs = gd['attributes'] ?? gd;
                              final soTien = (attrs['amount'] ?? 0).toDouble();
                              final ghiChu = attrs['note'] ?? 'Chưa có ghi chú';

                              // Lấy tên danh mục từ nested object (Strapi v5 format)
                              String tenDanhMuc = 'Khác';
                              var catObj = attrs['category']?['data'];
                              if (catObj != null) {
                                tenDanhMuc =
                                    catObj['attributes']?['Name'] ??
                                    catObj['Name'] ??
                                    'Khác';
                              }

                              final formatTien = NumberFormat.currency(
                                locale: 'vi_VN',
                                symbol: '',
                              ).format(soTien); // Bỏ chữ đ đi cho gọn

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _layMauDanhMuc(
                                    tenDanhMuc,
                                  ).withValues(alpha: 0.15),
                                  child: Icon(
                                    _layIconDanhMuc(tenDanhMuc),
                                    color: _layMauDanhMuc(tenDanhMuc),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  ghiChu,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  tenDanhMuc,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Text(
                                  '${formatTien} đ',
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
