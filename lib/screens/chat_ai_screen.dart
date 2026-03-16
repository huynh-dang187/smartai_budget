import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert'; // Để xử lý cục JSON
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final TextEditingController _controller = TextEditingController();
  String _ketQua =
      "Hãy gõ chi tiêu của bạn vào đây.\nVí dụ: 'Trưa nay ăn phở hết 45k'";
  // Khai báo Từ điển: Chìa khóa là Tên danh mục (String), Giá trị là ID (int)
  Map<String, dynamic> _tuDienDanhMuc = {};

  @override
  void initState() {
    super.initState();
    _taiDanhSachDanhMuc(); // Vừa mở Chat là đi lấy danh mục liền
  }

  Future<void> _taiDanhSachDanhMuc() async {
    final url = Uri.parse('http://10.185.83.167:1337/api/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List danhSach = data['data'];

        setState(() {
          for (var item in danhSach) {
            // --- THÊM DÒNG NÀY ĐỂ SOI DATA GỐC ---
            debugPrint("🔍 SOI RAW DATA: $item");
            // -------------------------------------

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

    _controller.clear(); // Xóa khung nhập
    // Lấy tất cả tên danh mục ghép thành 1 chuỗi: "Ăn uống, Mua sắm, Tiền trọ..."
    String cacDanhMucHienCo = _tuDienDanhMuc.keys.join(", ");

    // Nếu chưa có danh mục nào thì cho mặc định
    if (cacDanhMucHienCo.isEmpty) cacDanhMucHienCo = "Khác";

    // 1. Tạo câu lệnh Prompt (CHỈ TẠO 1 LẦN Ở ĐÂY THÔI)
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

      // 3. Gửi cho AI và chờ kết quả
      final response = await model.generateContent([Content.text(prompt)]);
      String aiReply =
          response.text ?? "{}"; // Đổi final thành String để dễ chỉnh sửa

      // --- BÙA CHỐNG LÚ CHO AI ---
      // Lột sạch mấy cái râu ria (```json và ```) nếu AI lỡ chèn vào
      aiReply = aiReply.replaceAll('```json', '').replaceAll('```', '').trim();
      // ---------------------------

      // 4. Dịch cục text của AI thành dạng Map (JSON) trong Flutter
      final data = json.decode(aiReply);
      // Gọi lệnh gửi lên Strapi
      // Gọi lệnh gửi lên Strapi (truyền đủ 3 món: tiền, ghi chú, danh mục)
      int soTienChuan = int.tryParse(data['amount'].toString()) ?? 0;
      await _luuGiaoDichLenStrapi(
        soTienChuan, // <--- Đã an toàn tuyệt đối
        data['note'],
        data['category'],
      ); // 5. Hiển thị kết quả bóc tách ra màn hình để test
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

  Future<void> _luuGiaoDichLenStrapi(
    int amount,
    String note,
    String categoryName,
  ) async {
    final url = Uri.parse('http://10.185.83.167:1337/api/transactions');

    // 1. CHỐNG AI LÚ & CHỐNG SAI HOA/THƯỜNG: Cắt khoảng trắng và ép về chữ thường
    String tenChuan = categoryName.trim().toLowerCase();

    // 2. TRA TỪ ĐIỂN
    dynamic categoryId = _tuDienDanhMuc[tenChuan];

    // 3. PHAO CỨU SINH: Nếu AI trả về từ tào lao không có trong từ điển
    // thì mình bắt nó lấy cái Danh mục ĐẦU TIÊN trong từ điển thay vì để null
    if (categoryId == null && _tuDienDanhMuc.isNotEmpty) {
      categoryId = _tuDienDanhMuc.values.first;
      debugPrint(
        "⚠️ Cảnh báo: AI trả về '$tenChuan' không có trong từ điển. Đã lấy ID mặc định!",
      );
    }

    debugPrint(
      "🚀 ĐANG GỬI LÊN STRAPI - Món: $note | Tiền: $amount | ID Danh mục: $categoryId",
    );

    final goiHang = json.encode({
      "data": {
        "amount": amount,
        "note": note,
        "date": DateTime.now().toIso8601String(),
        "category": categoryId, // Bắn ID xịn này lên!
      },
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: goiHang,
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
        foregroundColor: Colors.white, // Chữ màu trắng cho nổi
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Khu vực hiển thị tin nhắn / Kết quả của AI
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

            // Khu vực ô nhập text và nút Gửi
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
