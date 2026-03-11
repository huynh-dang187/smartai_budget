import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert'; // Để xử lý cục JSON
import 'package:http/http.dart' as http;

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final TextEditingController _controller = TextEditingController();
  String _ketQua =
      "Hãy gõ chi tiêu của bạn vào đây.\nVí dụ: 'Trưa nay ăn phở hết 45k'";

  Future<void> _guiTinNhan() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    setState(() {
      _ketQua = "Đang nhờ AI phân tích câu:\n\n'$text'...";
    });

    _controller.clear(); // Xóa khung nhập

    try {
      // 1. Khai báo chìa khóa và bộ não (Dán API Key của ông vào đây)
      const apiKey = 'AIzaSyCTPn7ETrCYinik-gdXKVpMuEWraNcMumA';
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      // 2. KỸ THUẬT ÉP KHUÔN AI (Prompt Engineering)
      final prompt =
          '''
        Bạn là một trợ lý ảo quản lý chi tiêu. Người dùng vừa nhập câu sau: "$text".
        Hãy trích xuất thông tin và CHỈ TRẢ VỀ ĐÚNG 1 CỤC JSON, tuyệt đối không giải thích gì thêm, không dùng markdown (```json).
        Định dạng bắt buộc:
        {
          "amount": (số tiền bằng số nguyên, ví dụ 45000),
          "note": "(ghi chú ngắn gọn món đồ)",
          "category": "(chọn 1 trong các từ sau: Ăn uống, Mua sắm, Di chuyển, Hóa đơn, Khác)"
        }
      ''';

      // 3. Gửi cho AI và chờ kết quả
      final response = await model.generateContent([Content.text(prompt)]);
      final aiReply = response.text ?? "{}";

      // 4. Dịch cục text của AI thành dạng Map (JSON) trong Flutter
      final data = json.decode(aiReply);
      // Gọi lệnh gửi lên Strapi
      await _luuGiaoDichLenStrapi(data['amount'], data['note']);
      // 5. Hiển thị kết quả bóc tách ra màn hình để test
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

  Future<void> _luuGiaoDichLenStrapi(int amount, String note) async {
    // ⚠️ NHỚ THAY IP CỦA ÔNG VÀO NHÉ
    final url = Uri.parse('http://172.25.91.167:1337/api/transactions');

    // Gói hàng theo đúng chuẩn của Strapi
    final goiHang = json.encode({
      "data": {
        "amount": amount,
        "note": note,
        "date": DateTime.now().toIso8601String(), // Tự động lấy giờ hiện tại
        // (Tạm thời mình chưa gắn Category ID để test cho lẹ nhé)
      },
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type":
              "application/json", // Báo cho Server biết mình gửi file JSON
        },
        body: goiHang,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 201 là mã HTTP báo hiệu "Created" (Đã tạo thành công)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Đã lưu vào sổ chi tiêu!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
          ); // Tự động đóng màn hình Chat, quay về Màn hình chính
        }
      } else {
        debugPrint("Lỗi Strapi từ chối: ${response.body}");
      }
    } catch (e) {
      debugPrint("Lỗi mạng không gửi được: $e");
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
