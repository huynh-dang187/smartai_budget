import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Format tiền và ngày tháng
import 'package:google_generative_ai/google_generative_ai.dart'; // Não AI
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Lấy key bí mật
import '../main.dart'; // Nạp cái này để lấy biến userTokenGlobal
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List danhSachGiaoDich = [];
  bool dangTaiDuLieu = true;

  // 1. Biến lưu giữ Tháng/Năm hiện tại
  DateTime _thangHienTai = DateTime.now();

  // --- TỪ ĐIỂN GIAO DIỆN (LƯU ICON VÀ MÀU TỪ STRAPI) ---
  final Map<String, Map<String, dynamic>> _tuDienGiaoDien = {};

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

    // DỌNG NGHE LÉN CHUÔNG BÁO ĐỘNG TỪ FILE MAIN
    refreshDataGlobal.addListener(() {
      if (refreshDataGlobal.value == true && mounted) {
        // Nếu chuông kêu -> Tự động gọi lại hàm lấy dữ liệu để vẽ lại biểu đồ
        layDuLieuTuStrapi();
        // Tắt chuông đi
        refreshDataGlobal.value = false;
      }
    });
  }

  // --- BƯỚC 1: LẤY BỘ NHẬN DIỆN THƯƠNG HIỆU TỪ STRAPI ---
  Future<void> _taiDanhMucDeLayMauVaIcon() async {
    try {
      final response = await http.get(
        Uri.parse('http://139.59.242.7:1337/api/categories'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        for (var item in data) {
          final attrs = item['attributes'] ?? item;
          String tenDM = attrs['Name'] ?? 'Khác';
          String tenKey = tenDM.toLowerCase().trim();

          int? codePoint = int.tryParse(attrs['Icon'] ?? '');
          IconData iconData = codePoint != null
              ? IconData(codePoint, fontFamily: 'MaterialIcons')
              : Icons.category_rounded;

          String colorStr = attrs['Color'] ?? '';
          Color colorData = Colors.blueGrey;
          if (colorStr.isNotEmpty) {
            try {
              colorData = Color(int.parse(colorStr, radix: 16));
            } catch (e) {}
          }

          if (codePoint == null || colorStr.isEmpty) {
            if (tenKey.contains('ăn')) {
              iconData = Icons.fastfood_rounded;
              colorData = Colors.orange;
            } else if (tenKey.contains('giải') || tenKey.contains('chơi')) {
              iconData = Icons.sports_esports_rounded;
              colorData = Colors.purple;
            } else if (tenKey.contains('học')) {
              iconData = Icons.school_rounded;
              colorData = Colors.blue;
            } else if (tenKey.contains('nhà') ||
                tenKey.contains('trọ') ||
                tenKey.contains('wifi')) {
              iconData = Icons.home_rounded;
              colorData = Colors.teal;
            }
          }
          _tuDienGiaoDien[tenKey] = {'icon': iconData, 'color': colorData};
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải danh mục: $e");
    }
  }

  // --- BƯỚC 2: KÉO GIAO DỊCH VỀ (ĐÃ LẮP VÉ VIP) ---
  Future<void> layDuLieuTuStrapi() async {
    await _taiDanhMucDeLayMauVaIcon();

    // Lấy ID của mình ra
    int? myId = userIdGlobal.value;

    // � EXPLICIT FILTER: Add query parameter to force backend filtering
    final url = Uri.parse(
      'http://139.59.242.7:1337/api/transactions?populate=category&populate=user',
    );

    String? token = userTokenGlobal.value;

    try {
      final response = await http.get(
        url,
        headers: token != null
            ? {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              }
            : null,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // � FILTER TO USER'S OWN DATA ONLY
        final List allTransactions = data['data'] ?? [];
        debugPrint('\n📋 [HOME] Got ${allTransactions.length} from API, myId=$myId');
        
        if (allTransactions.isNotEmpty) {
          var first = allTransactions[0];
          debugPrint('First TX: id=${first['id']}, user=${first['user']}');
        }
        
        final List giaoDich = allTransactions.where((t) {
          int? userId;
          
          // Path 1: Direct user.id 
          if (t['user'] is Map && t['user']['id'] != null) {
            userId = t['user']['id'];
          } 
          // Path 2: Nested user.data.id
          else if (t['user'] is Map && t['user']['data'] is Map && t['user']['data']['id'] != null) {
            userId = t['user']['data']['id'];
          }
          // Path 3: Via attributes
          else if (t['attributes'] is Map && t['attributes']['user'] is Map) {
            userId = t['attributes']['user']['data']?['id'] ?? t['attributes']['user']['id'];
          }
          
          bool match = userId == myId;
          if (match) debugPrint('  ✓ TX ${t['id']}: $userId == $myId');
          return match;
        }).toList();

        debugPrint("📊 Filtered: ${giaoDich.length}/${allTransactions.length}\n");

        if (mounted) {
          setState(() {
            danhSachGiaoDich = giaoDich;
            dangTaiDuLieu = false;
          });
        }
      } else {
        debugPrint("Lỗi từ server: ${response.body}");
        if (mounted) setState(() => dangTaiDuLieu = false);
      }
    } catch (e) {
      debugPrint("Lỗi mạng: $e");
      if (mounted) setState(() => dangTaiDuLieu = false);
    }
  }

  // --- HÀM TÍNH TOÁN DỮ LIỆU BIỂU ĐỒ (ĐÃ ĐỒNG BỘ MÀU) ---
  List<PieChartSectionData> _taoDuLieuBieuDo() {
    Map<String, double> tongTienTheoDanhMuc = {};
    double tongTatCa = 0;

    for (var gd in _giaoDichTrongThang) {
      double tien = (gd['amount'] ?? 0).toDouble();
      String tenDM = 'Khác';
      if (gd['category'] != null) {
        var cat = gd['category'];
        if (cat['Name'] != null) {
          tenDM = cat['Name'];
        } else if (cat['data'] != null) {
          tenDM = (cat['data']['attributes'] ?? cat['data'])['Name'] ?? 'Khác';
        }
      }

      tongTienTheoDanhMuc[tenDM] = (tongTienTheoDanhMuc[tenDM] ?? 0) + tien;
      tongTatCa += tien;
    }

    List<PieChartSectionData> cacMangMau = [];
    final List<Color> bangMauBackup = [
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

      // Tra từ điển lấy màu
      String tenKey = ten.toLowerCase().trim();
      Color mauChuan =
          _tuDienGiaoDien[tenKey]?['color'] ??
          bangMauBackup[indexMau % bangMauBackup.length];

      cacMangMau.add(
        PieChartSectionData(
          color: mauChuan,
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
          .map((gd) {
            String tenDM = gd['category'] != null
                ? (gd['category']['Name'] ??
                      (gd['category']['data'] != null
                          ? gd['category']['data']['attributes']['Name']
                          : 'Khác'))
                : 'Khác';
            return "- ${gd['note']}: ${(gd['amount'] ?? 0)} VNĐ (Mục: $tenDM)";
          })
          .join('\n');

      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

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
    String tenDanhMuc = 'Khác';
    if (giaoDich['category'] != null) {
      var cat = giaoDich['category'];
      if (cat['Name'] != null) {
        tenDanhMuc = cat['Name'];
      } else if (cat['data'] != null) {
        tenDanhMuc =
            (cat['data']['attributes'] ?? cat['data'])['Name'] ?? 'Khác';
      }
    }

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
                        Navigator.pop(context);
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
                        final deleteUrl = Uri.parse(
                          'http://139.59.242.7:1337/api/transactions/$idGiaoDich',
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
  void _hienThiDialogSua(dynamic giaoDich, String idGiaoDich) {
    final TextEditingController tienController = TextEditingController(
      text: giaoDich['amount'].toString(),
    );
    final TextEditingController ghiChuController = TextEditingController(
      text: giaoDich['note'] ?? '',
    );

    DateTime thoiGianDuKien = DateTime.parse(giaoDich['date']).toLocal();

    showDialog(
      context: context,
      builder: (context) {
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
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      DateTime? ngayMoi = await showDatePicker(
                        context: context,
                        initialDate: thoiGianDuKien,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (ngayMoi != null) {
                        TimeOfDay? gioMoi = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(thoiGianDuKien),
                        );

                        if (gioMoi != null) {
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
                    Navigator.pop(context);
                    final putUrl = Uri.parse(
                      'http://139.59.242.7:1337/api/transactions/$idGiaoDich',
                    );
                    try {
                      final response = await http.put(
                        putUrl,
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          "data": {
                            "amount": int.tryParse(tienController.text) ?? 0,
                            "note": ghiChuController.text,
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
                        layDuLieuTuStrapi();
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

  // --- HÀM XÂY CỬA THOÁT HIỂM: FORM NHẬP TAY ---
  Future<void> _moFormNhapTay() async {
    // 1. Hiện loading đi lấy danh mục
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> danhMucList = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token =
          userTokenGlobal.value ??
          prefs.getString('jwt') ??
          prefs.getString('token');

      // Lấy danh mục từ Strapi
      final response = await http.get(
        Uri.parse('http://139.59.242.7:1337/api/categories'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        for (var item in data) {
          danhMucList.add({
            'id': item['documentId'] ?? item['id'].toString(),
            'name': (item['attributes'] ?? item)['Name'] ?? 'Khác',
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải danh mục form: $e");
    }

    if (mounted) Navigator.pop(context); // Tắt loading

    if (danhMucList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Không tải được danh mục, kiểm tra mạng!"),
        ),
      );
      return;
    }

    // 2. Khởi tạo Controller cho Form
    final tienController = TextEditingController();
    final ghiChuController = TextEditingController();
    String? selectedCategoryId = danhMucList[0]['id'];

    // 3. Bật Form lên (Dùng BottomSheet)
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Cho phép đẩy form lên khi hiện bàn phím
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setStateSheet) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      20, // Nâng lên tránh bàn phím đè
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: Colors.blue,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Nhập chi tiêu",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Chọn danh mục
                      DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: "Chọn danh mục",
                          prefixIcon: const Icon(
                            Icons.category,
                            color: Colors.teal,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        items: danhMucList.map((dm) {
                          return DropdownMenuItem<String>(
                            value: dm['id'],
                            child: Text(dm['name']),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setStateSheet(() => selectedCategoryId = val),
                      ),
                      const SizedBox(height: 15),

                      // Nhập tiền (Cấm nhập chữ)
                      TextField(
                        controller: tienController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: "Số tiền (VNĐ)",
                          prefixIcon: const Icon(
                            Icons.monetization_on,
                            color: Colors.orange,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Nhập ghi chú
                      TextField(
                        controller: ghiChuController,
                        decoration: InputDecoration(
                          labelText: "Ghi chú (Ví dụ: Ăn phở)",
                          prefixIcon: const Icon(
                            Icons.edit,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Nút Lưu
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          if (tienController.text.isEmpty ||
                              ghiChuController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "⚠️ Vui lòng nhập đủ tiền và ghi chú!",
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx); // Đóng form

                          // GỌI API LƯU LÊN STRAPI
                          final url = Uri.parse(
                            'http://139.59.242.7:1337/api/transactions',
                          );
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            String? token =
                                userTokenGlobal.value ??
                                prefs.getString('jwt') ??
                                prefs.getString('token');
                            int? myId = userIdGlobal.value;

                            final response = await http.post(
                              url,
                              headers: {
                                'Content-Type': 'application/json',
                                if (token != null)
                                  'Authorization': 'Bearer $token',
                              },
                              body: json.encode({
                                "data": {
                                  "amount":
                                      int.tryParse(tienController.text) ?? 0,
                                  "note": ghiChuController.text,
                                  "date": DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                  "category": selectedCategoryId,
                                  // ⚠️ Bỏ "user" - để Strapi tự set từ JWT token
                                },
                              }),
                            );

                            debugPrint(
                              "\ud83d\udcc4 HOME SCREEN POST: ${response.statusCode} - ${response.body}",
                            );

                            if (response.statusCode == 201 ||
                                response.statusCode == 200) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("🎉 Đã lưu vào sổ!"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Wait for backend to process
                              await Future.delayed(Duration(milliseconds: 800));
                              layDuLieuTuStrapi(); // Load lại màn hình Tổng quan
                              refreshDataGlobal.value =
                                  true; // Rung chuông báo cho màn Thu chi & Ngân sách
                            } else {
                              debugPrint("Lỗi Strapi: ${response.body}");
                            }
                          } catch (e) {
                            debugPrint("Lỗi gửi tay: $e");
                          }
                        },
                        child: const Text(
                          "Lưu Giao Dịch",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
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
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: _taoDuLieuBieuDo(),
                          centerSpaceRadius: 35,
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

                // ---------------------------
                // --- KHU VỰC 3: DANH SÁCH CHI TIÊU ĐÃ ĐỒNG BỘ ---
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _giaoDichTrongThang.length,
                    itemBuilder: (context, index) {
                      final giaoDich = _giaoDichTrongThang[index];
                      final idGiaoDich =
                          giaoDich['documentId']?.toString() ??
                          giaoDich['id'].toString();
                      final soTien = giaoDich['amount'] ?? 0;
                      final ghiChu = giaoDich['note'] ?? 'Chưa có ghi chú';

                      String tenDanhMuc = 'Khác';
                      if (giaoDich['category'] != null) {
                        var cat = giaoDich['category'];
                        if (cat['Name'] != null) {
                          tenDanhMuc = cat['Name'];
                        } else if (cat['data'] != null) {
                          tenDanhMuc =
                              (cat['data']['attributes'] ??
                                  cat['data'])['Name'] ??
                              'Khác';
                        }
                      }

                      final formatTien = NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: 'đ',
                      ).format(soTien);

                      // --- TRA TỪ ĐIỂN LẤY ICON VÀ MÀU ---
                      final tenKey = tenDanhMuc.toLowerCase().trim();
                      final iconChuan =
                          _tuDienGiaoDien[tenKey]?['icon'] ??
                          Icons.receipt_long;
                      final mauChuan =
                          _tuDienGiaoDien[tenKey]?['color'] ?? Colors.teal;

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
                              backgroundColor: mauChuan.withOpacity(
                                0.2,
                              ), // Màu từ Strapi
                              child: Icon(
                                iconChuan, // Icon từ Strapi
                                color: mauChuan,
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
    );
  }
}
