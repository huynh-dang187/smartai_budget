import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final TextEditingController _controller = TextEditingController();
  String _ketQua =
      "Hãy gõ chi tiêu của bạn vào đây.\nVí dụ: 'Trưa nay ăn phở hết 45k'";
  Map<String, dynamic> _tuDienDanhMuc = {};

  @override
  void initState() {
    super.initState();
    _taiDanhSachDanhMuc();
  }

  Future<void> _taiDanhSachDanhMuc() async {
    final url = Uri.parse('http://10.57.162.167:1337/api/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List danhSach = data['data'];

        setState(() {
          for (var item in danhSach) {
            String tenDM = item['Name']?.toString() ?? 'Khác';
            var idDM = item['documentId'] ?? item['id'];

            if (idDM != null) {
              _tuDienDanhMuc[tenDM.trim().toLowerCase()] = idDM;
            }
          }
        });
        debugPrint("📚 TỪ ĐIỂN ĐÃ TẢI THÀNH CÔNG: $_tuDienDanhMuc");
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải danh mục (sập hàm): $e");
    }
  }

  Future<void> _guiTinNhan() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    setState(() {
      _ketQua = "Đang nhờ AI phân tích câu:\n\n'$text'...";
    });

    _controller.clear();
    String cacDanhMucHienCo = _tuDienDanhMuc.keys.join(", ");
    if (cacDanhMucHienCo.isEmpty) cacDanhMucHienCo = "Khác";

    final prompt =
        '''
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

      // Gọi lệnh gửi lên Strapi
      await _luuGiaoDichLenStrapi(soTienChuan, data['note'], data['category']);

      setState(() {
        _ketQua =
            "🎉 AI đã bóc tách thành công!\n\n"
            "💰 Số tiền: ${data['amount']} VNĐ\n"
            "📝 Ghi chú: ${data['note']}\n"
            "🏷️ Danh mục: ${data['category']}\n\n"
            "(Cục JSON gốc: $aiReply)";
      });
    } catch (e) {
      setState(() {
        _ketQua = "❌ Úi, AI bị lú hoặc mạng có vấn đề rồi: $e";
      });
    }
  }

  // --- HÀM GỬI LÊN STRAPI ĐÃ ĐƯỢC CHUẨN HÓA LẠI ---
  Future<void> _luuGiaoDichLenStrapi(
    int amount,
    String note,
    String categoryName,
  ) async {
    final url = Uri.parse('http://10.57.162.167:1337/api/transactions');

    String tenChuan = categoryName.trim().toLowerCase();
    dynamic categoryId = _tuDienDanhMuc[tenChuan];

    if (categoryId == null && _tuDienDanhMuc.isNotEmpty) {
      categoryId = _tuDienDanhMuc.values.first;
      debugPrint("⚠️ Cảnh báo: Lấy ID mặc định do AI trả về từ lạ!");
    }

    // 1. Móc thẻ VIP và ID từ két sắt ra
    String? token = userTokenGlobal.value;
    int? myId = userIdGlobal.value;

    debugPrint(
      "🚀 ĐANG GỬI LÊN STRAPI - Món: $note | Tiền: $amount | UserID: $myId",
    );

    try {
      // 2. Gọi API POST với Headers và Body đã được bảo vệ
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "data": {
            "amount": amount,
            "note": note,
            "date": DateTime.now().toUtc().toIso8601String(),
            "category": [categoryId.toString()],
            if (myId != null)
              "user": [myId.toString()], // BỌC [ ] VÀ .toString()
          },
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Đã lưu vào sổ!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        debugPrint("❌ Lỗi Strapi từ chối: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Lỗi mạng không gửi được: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '✨ Trợ lý AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _ketQua,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.blueGrey,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Nhập khoản chi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  radius: 25,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _guiTinNhan,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
