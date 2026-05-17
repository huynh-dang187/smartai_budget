import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';

/// 🎯 ViewModel cho ChatAI Screen
/// Chứa tất cả logic liên quan đến gọi API Gemini và Strapi
class ChatAIViewModel extends ChangeNotifier {
  // --- STATE VARIABLES ---
  String _ketQua = "Hãy gõ hoặc nói chi tiêu của bạn.\nVí dụ: 'Trưa nay ăn phở hết 45k'";
  Map<String, dynamic> _tuDienDanhMuc = {};
  bool _isListening = false;

  // --- GETTERS (để View lắng nghe) ---
  String get ketQua => _ketQua;
  Map<String, dynamic> get tuDienDanhMuc => _tuDienDanhMuc;
  bool get isListening => _isListening;

  // --- SETTERS (để update state) ---
  void _setKetQua(String value) {
    _ketQua = value;
    notifyListeners();
  }

  void _setIsListening(bool value) {
    _isListening = value;
    notifyListeners();
  }

  void _setTuDienDanhMuc(Map<String, dynamic> value) {
    _tuDienDanhMuc = value;
    notifyListeners();
  }

  // --- INITIALIZATION ---
  Future<void> init() async {
    await _taiDanhSachDanhMuc();
  }

  // --- API: Tải danh sách danh mục ---
  Future<void> _taiDanhSachDanhMuc() async {
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

        Map<String, dynamic> tuDien = {};
        for (var item in danhSach) {
          String tenDM =
              item['attributes']?['Name'] ??
              item['Name']?.toString() ??
              'Khác';
          var idDM = item['id'] ?? item['documentId'];

          if (idDM != null) {
            tuDien[tenDM.trim().toLowerCase()] = idDM;
          }
        }
        _setTuDienDanhMuc(tuDien);
        debugPrint("📚 TỨ ĐIỂN ĐÃ TẢI: ${tuDien.length} categories");
      } else {
        debugPrint("❌ Category fetch failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải danh mục: $e");
    }
  }

  // --- API: Gửi tin nhắn đến Gemini ---
  Future<void> guiTinNhan(String text) async {
    if (text.isEmpty) return;

    _setKetQua("Đang nhờ AI phân tích câu:\n\n'$text'...");

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

      await _luuGiaoDichLenStrapi(soTienChuan, data['note'], data['category']);

      _setKetQua(
        "🎉 AI đã bóc tách thành công!\n\n"
        "💰 Số tiền: ${data['amount']} VNĐ\n"
        "📝 Ghi chú: ${data['note']}\n"
        "🏷️ Danh mục: ${data['category']}\n\n"
        "(Cục JSON gốc: $aiReply)",
      );
    } catch (e) {
      _setKetQua("❌ Úi, AI bị lú hoặc mạng có vấn đề rồi: $e");
    }
  }

  // --- API: Lưu giao dịch lên Strapi ---
  Future<void> _luuGiaoDichLenStrapi(
    int amount,
    String note,
    String categoryName,
  ) async {
    final url = Uri.parse('http://139.59.242.7:1337/api/transactions');
    String tenChuan = categoryName.trim().toLowerCase();
    dynamic categoryId = _tuDienDanhMuc[tenChuan];

    if (categoryId == null && _tuDienDanhMuc.isNotEmpty) {
      categoryId = _tuDienDanhMuc.values.first;
    }

    String? token = userTokenGlobal.value;
    int? myId = userIdGlobal.value;

    debugPrint("🔍 [ChatAI] Token: ${token?.substring(0, 20)}...");
    debugPrint("🔍 [ChatAI] User ID: $myId");
    debugPrint("🔍 [ChatAI] Category ID: $categoryId");

    try {
      final body = {
        "data": {
          "amount": amount,
          "note": note,
          "date": DateTime.now().toUtc().toIso8601String(),
          "category": categoryId,
        },
      };

      debugPrint("📤 [ChatAI] Sending POST: ${json.encode(body)}");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      debugPrint(
        "📥 [ChatAI] Response ${response.statusCode}: ${response.body.substring(0, 200)}",
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("✅ [ChatAI] Success: Giao dịch đã lưu");
        // Báo HomeScreen reload
        refreshDataGlobal.value = true;
      } else {
        debugPrint("❌ [ChatAI] Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ [ChatAI] Network error: $e");
    }
  }

  // --- Setters cho UI callback ---
  void setIsListening(bool value) {
    _setIsListening(value);
  }
}
