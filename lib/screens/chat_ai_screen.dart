import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert'; // Để xử lý cục JSON
class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final TextEditingController _controller = TextEditingController();
  String _ketQua =
      "Hãy gõ chi tiêu của bạn vào đây.\nVí dụ: 'Trưa nay ăn phở hết 45k'";

  void _guiTinNhan() {
    final text = _controller.text;
    if (text.isEmpty) return;

    setState(() {
      _ketQua = "Đang nhờ AI suy nghĩ phân tích câu:\n\n'$text'...";
    });

    // Tí nữa mình sẽ viết code gọi API Gemini ở ngay chỗ này!

    _controller.clear(); // Gửi xong thì xóa trắng ô nhập liệu
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
