import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // 📌 Bổ sung thư viện này để Format tiền tệ!
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'home_screen.dart';
import 'chat_ai_screen.dart';
import 'transactions_screen.dart';
import 'budget_screen.dart';
import 'settings_screen.dart';
import '../main.dart'; // Lấy biến toàn cục

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 🤖 Biến cho AI Expandable Form
  late TextEditingController _aiController;
  String _ketQuaAI = "Nói chi tiêu của bạn\nVí dụ: 'Ăn phở 45k'";
  Map<String, dynamic> _tuDienDanhMucAI = {};
  final stt.SpeechToText _speechAI = stt.SpeechToText();
  bool _isListeningAI = false;

  late List<Widget> _pages = [
    HomeScreen(key: UniqueKey()),
    const TransactionsScreen(),
    const BudgetScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _aiController = TextEditingController();
    _speechAI.initialize();
  }

  @override
  void dispose() {
    _aiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _pages[_currentIndex],

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: _hienThiMenuNhapLieu,
        child: const Icon(Icons.add, color: Colors.white, size: 35),
      ),

      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 15,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.pie_chart_rounded, "Tổng quan", 0),
                    _buildNavItem(Icons.receipt_long_rounded, "Thu chi", 1),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      Icons.account_balance_wallet_rounded,
                      "Ngân sách",
                      2,
                    ),
                    _buildNavItem(Icons.settings_rounded, "Cài đặt", 3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hienThiMenuNhapLieu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Thêm giao dịch",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.mic_rounded, color: Colors.white),
                ),
                title: const Text(
                  "Nhập bằng giọng nói",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Nói chi tiêu, hệ thống sẽ ghi lại"),
                onTap: () {
                  Navigator.pop(ctx);
                  _goiAI(context);
                },
              ),
              const Divider(indent: 70),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.edit_document, color: Colors.white),
                ),
                title: const Text(
                  "Nhập thủ công",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Tự điền thông tin truyền thống"),
                onTap: () {
                  Navigator.pop(ctx);
                  _moFormNhapTay();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _goiAI(BuildContext context) {
    _ketQuaAI = "Nói chi tiêu của bạn\nVí dụ: 'Ăn phở 45k'";
    _aiController.clear();
    _taiDanhSachDanhMucAI();
    _moFormAI(context);
  }

  // 🤖 HÀM TẢI DANH MỤC CHO AI
  Future<void> _taiDanhSachDanhMucAI() async {
    String? token = userTokenGlobal.value;
    final url = Uri.parse('http://139.59.242.7:1337/api/categories');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List danhSach = data['data'];

        setState(() {
          for (var item in danhSach) {
            String tenDM = item['attributes']?['Name'] ?? item['Name']?.toString() ?? 'Khác';
            var idDM = item['id'] ?? item['documentId'];
            if (idDM != null) {
              _tuDienDanhMucAI[tenDM.trim().toLowerCase()] = idDM;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải danh mục AI: $e");
    }
  }

  // 🎙️ HÀM GHI ÂM CHO AI
  void _langNgheGiongNoiAI() async {
    if (!_isListeningAI) {
      bool available = await _speechAI.initialize(
        onStatus: (val) => debugPrint('Trạng thái Mic: $val'),
        onError: (val) => debugPrint('Lỗi Mic: $val'),
      );
      if (available) {
        setState(() => _isListeningAI = true);
        _speechAI.listen(
          onResult: (val) => setState(() {
            _aiController.text = val.recognizedWords;
          }),
          localeId: 'vi_VN',
        );
      }
    } else {
      setState(() => _isListeningAI = false);
      _speechAI.stop();
    }
  }

  // 🚀 HÀM GỬI TIN NHẮN AI
  void _guiTinNhanAI() async {
    String text = _aiController.text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập hoặc nói gì đó!")),
      );
      return;
    }

    setState(() => _ketQuaAI = "Đang xử lý...");
    _aiController.clear();
    String cacDanhMucHienCo = _tuDienDanhMucAI.keys.join(", ");
    if (cacDanhMucHienCo.isEmpty) cacDanhMucHienCo = "Khác";

    final prompt = '''
      Bạn là một trợ lý ảo quản lý chi tiêu. Người dùng vừa nhập câu sau: "$text".
      Hãy trích xuất thông tin và CHỈ TRẢ VỀ ĐÚNG 1 CỤC JSON, tuyệt đối không giải thích gì thêm.
      Định dạng bắt buộc:
      {
        "amount": (số tiền bằng số nguyên, ví dụ 45000),
        "note": "(ghi chú ngắn gọn món đồ)",
        "category": "(chọn 1 TRONG CÁC TỪ SAU ĐÂY: $cacDanhMucHienCo)"
      }
    ''';

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      String aiReply = response.text ?? "{}";

      aiReply = aiReply.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = json.decode(aiReply);
      int soTienChuan = int.tryParse(data['amount'].toString()) ?? 0;

      await _luuGiaoDichAILenStrapi(soTienChuan, data['note'], data['category']);

      setState(() {
        _ketQuaAI = "Bóc tách thành công!\n\n"
            "Số tiền: ${data['amount']} VNĐ\n"
            "Ghi chú: ${data['note']}\n"
            "Danh mục: ${data['category']}";
      });
    } catch (e) {
      setState(() => _ketQuaAI = "Lỗi xử lý: $e");
    }
  }

  // 💾 HÀM LƯU GIAO DỊCH AI LÊN STRAPI
  Future<void> _luuGiaoDichAILenStrapi(int amount, String note, String categoryName) async {
    final url = Uri.parse('http://139.59.242.7:1337/api/transactions');
    String tenChuan = categoryName.trim().toLowerCase();
    dynamic categoryId = _tuDienDanhMucAI[tenChuan];

    if (categoryId == null && _tuDienDanhMucAI.isNotEmpty) {
      categoryId = _tuDienDanhMucAI.values.first;
    }

    String? token = userTokenGlobal.value;
    int? myId = userIdGlobal.value;

    debugPrint("🔍 [AI] Token: ${token?.substring(0, 20)}...");
    debugPrint("🔍 [AI] Category ID: $categoryId");

    try {
      final body = {
        "data": {
          "amount": amount,
          "note": note,
          "date": DateTime.now().toUtc().toIso8601String(),
          "category": categoryId,
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu vào sổ'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
        refreshDataGlobal.value = true;
        setState(() {
          _currentIndex = 0;
          _pages[0] = HomeScreen(key: UniqueKey());
        });
      } else {
        debugPrint("❌ [AI] Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ [AI] Network error: $e");
    }
  }

  // 📱 EXPANDABLE MODAL FORM AI
  void _moFormAI(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.35,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setStateAI) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: Column(
                    children: [
                      // 🔝 HANDLE BAR
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // ✨ HEADER
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            const Text(
                              "Ghi chép giọng nói",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // 📝 AI RESPONSE AREA
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                              ),
                              child: Text(
                                _ketQuaAI,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.blueAccent,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ⌨️ INPUT AREA
                      Container(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _aiController,
                                decoration: InputDecoration(
                                  hintText: 'Ăn phở 45k...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () => _aiController.clear(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 🎙️ MIC BUTTON
                            GestureDetector(
                              onTapDown: (details) => _langNgheGiongNoiAI(),
                              onTapUp: (details) {
                                setState(() => _isListeningAI = false);
                                _speechAI.stop();
                              },
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: _isListeningAI ? Colors.orange : Colors.blueAccent,
                                child: Icon(
                                  _isListeningAI ? Icons.mic : Icons.mic_none,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 🚀 SEND BUTTON
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.blueAccent,
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                                onPressed: () => _guiTinNhanAI(),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _moFormNhapTay() async {
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
          final attrs = item['attributes'] ?? item;
          String tenDM = attrs['Name'] ?? 'Khác';
          String tenKey = tenDM.toLowerCase().trim();

          // 🎨 ĐỌC ICON VÀ MÀU TỪ STRAPI ĐỂ LÀM GIAO DIỆN
          int? codePoint = int.tryParse(attrs['Icon'] ?? '');
          IconData iconData = codePoint != null
              ? IconData(codePoint, fontFamily: 'MaterialIcons')
              : Icons.category_rounded;

          Color colorData = Colors.blueGrey;
          String colorStr = attrs['Color'] ?? '';
          if (colorStr.isNotEmpty) {
            try {
              colorData = Color(int.parse(colorStr, radix: 16));
            } catch (e) {}
          }

          // Cứu cánh cho danh mục cũ chưa cài màu
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

          danhMucList.add({
            'id': item['documentId'] ?? item['id'].toString(),
            'name': tenDM,
            'icon': iconData, // Nhét thêm icon vào danh sách
            'color': colorData, // Nhét thêm màu vào danh sách
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải danh mục form: $e");
    }

    if (mounted) Navigator.pop(context);

    if (danhMucList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Không tải được danh mục, kiểm tra mạng!"),
        ),
      );
      return;
    }

    final tienController = TextEditingController();
    final ghiChuController = TextEditingController();
    String? selectedCategoryId =
        danhMucList[0]['id']; // Mặc định chọn cái đầu tiên

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
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
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                            Icons.account_balance_wallet_rounded,
                            color: Colors.blue,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Ghi chép nhanh",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // 📌 UI MỚI: THANH CUỘN CHỌN DANH MỤC
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Danh mục chi tiêu",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90, // Đủ cao để chứa Icon + Text
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal, // Cuộn ngang
                          itemCount: danhMucList.length,
                          itemBuilder: (context, index) {
                            final dm = danhMucList[index];
                            final isSelected =
                                selectedCategoryId ==
                                dm['id']; // Kiểm tra xem có đang được chọn không

                            return GestureDetector(
                              onTap: () {
                                setStateSheet(() {
                                  selectedCategoryId =
                                      dm['id']; // Cập nhật id khi bấm
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 85,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  // Đổi màu nền và viền nếu được chọn
                                  color: isSelected
                                      ? dm['color'].withOpacity(0.15)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? dm['color']
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      dm['icon'],
                                      color: isSelected
                                          ? dm['color']
                                          : Colors.grey.shade400,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dm['name'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? dm['color']
                                            : Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow
                                          .ellipsis, // Chữ dài quá thì hiện ...
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 25),

                      TextField(
                        controller: tienController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
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

                          String chuoiSoSanh = tienController.text.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          int soTienChuan = int.tryParse(chuoiSoSanh) ?? 0;

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
                                  "amount": soTienChuan,
                                  "note": ghiChuController.text,
                                  "date": DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                  "category": selectedCategoryId,
                                  // ⚠️ BỎ "user" - để Strapi tự set từ JWT token
                                },
                              }),
                            );

                            debugPrint(
                              "📤 POST BODY: ${json.encode({
                                "data": {"amount": soTienChuan, "note": ghiChuController.text, "category": selectedCategoryId},
                              })}",
                            );
                            debugPrint(
                              "📥 RESPONSE: ${response.statusCode} - ${response.body}",
                            );

                            if (response.statusCode == 201 ||
                                response.statusCode == 200) {
                              if (!mounted) return;

                              Navigator.pop(ctx);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Đã lưu vào sổ"),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              refreshDataGlobal.value = true;
                              setState(() {
                                _currentIndex = 0;
                                _pages[0] = HomeScreen(key: UniqueKey());
                              });
                            } else {
                              debugPrint("❌ Lỗi Strapi: ${response.body}");
                            }
                          } catch (e) {
                            debugPrint("❌ Lỗi gửi: $e");
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
              size: isSelected ? 28 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.grey.shade500,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 📌 CLASS XỬ LÝ ĐỊNH DẠNG DẤU CHẤM NGÀN (2.000.000)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    // Lọc bỏ mọi thứ không phải là số
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    // Ép kiểu về int và format lại theo chuẩn Việt Nam
    final int value = int.parse(digitsOnly);
    final String formatted = NumberFormat(
      '#,###',
      'vi_VN',
    ).format(value).replaceAll(',', '.'); // Đổi phẩy thành chấm cho hợp nhãn VN

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
