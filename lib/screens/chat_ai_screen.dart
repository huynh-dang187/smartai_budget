import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../viewmodels/chat_ai_viewmodel.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; // Nạp thư viện

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // --- VIEWMODEL (thay thế state variables) ---
  late ChatAIViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    
    // Tạo ViewModel instance
    _viewModel = ChatAIViewModel();
    
    // Lắng nghe khi ViewModel thay đổi → rebuild UI
    _viewModel.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // Khởi động ViewModel (tải danh mục)
    _viewModel.init();
    
    // Khởi động Micro
    _speech.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(() {});
    _viewModel.dispose();
    super.dispose();
  }

  // --- HÀM THU ÂM (dùng state mic) ---
  void _langNgheGiongNoi() async {
    if (!_viewModel.isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('Trạng thái Mic: $val'),
        onError: (val) => debugPrint('Lỗi Mic: $val'),
      );
      if (available) {
        _viewModel.setIsListening(true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
          localeId: 'vi_VN', // Ép nghe chuẩn tiếng Việt
        );
      }
    } else {
      _viewModel.setIsListening(false);
      _speech.stop();
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
                    _viewModel.ketQua,
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

            // --- KHU VỰC NHẬP LIỆU BÊN DƯỚI ---
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

                      // 🧹 THÊM NÚT "XÓA SẠCH" (DẤU X) VÀO GÓC PHẢI Ô CHỮ
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: () {
                          _controller
                              .clear(); // Xóa sạch sành sanh text trong ô
                        },
                      ),

                      // --------------------------------------------------
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 🎙️ NÚT MICRO ĐÃ ĐƯỢC DỌN VÀO ĐÚNG CHỖ NÀY
                GestureDetector(
                  onTapDown: (details) => _langNgheGiongNoi(),
                  onTapUp: (details) {
                    _viewModel.setIsListening(false);
                    _speech.stop();
                  },
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: _viewModel.isListening
                        ? Colors.redAccent
                        : Colors.blueAccent,
                    child: Icon(
                      _viewModel.isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 🚀 NÚT GỬI
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  radius: 25,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      final text = _controller.text;
                      _controller.clear();
                      _viewModel.guiTinNhan(text);
                    },
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
