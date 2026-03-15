import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _danhSachDanhMuc = [];

  // Các Icon và Màu sắc mẫu để người dùng chọn khi tạo danh mục mới
  final List<IconData> _danhSachIcon = [
    Icons.fastfood_rounded,
    Icons.local_cafe_rounded,
    Icons.sports_esports_rounded,
    Icons.shopping_bag_rounded,
    Icons.fitness_center_rounded,
    Icons.menu_book_rounded,
    Icons.local_gas_station_rounded,
    Icons.home_rounded,
    Icons.medical_services_rounded,
  ];

  final List<Color> _danhSachMau = [
    Colors.orange,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _taiDanhSachTuStrapi();
  }

  // --- GỌI API LẤY DANH MỤC TỪ STRAPI ---
  Future<void> _taiDanhSachTuStrapi() async {
    final url = Uri.parse('http://10.185.83.167:1337/api/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _danhSachDanhMuc = data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải danh mục: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- BẢNG THÊM DANH MỤC MỚI ---
  void _hienThiBangThemDanhMuc() {
    final TextEditingController tenController = TextEditingController();
    IconData iconDuocChon = _danhSachIcon[0];
    Color mauDuocChon = _danhSachMau[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Tạo Danh Mục Mới",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 1. Nhập tên danh mục
                    TextField(
                      controller: tenController,
                      decoration: InputDecoration(
                        labelText: "Tên danh mục (VD: Trà sữa, Tiền trọ)",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Chọn Icon
                    const Text(
                      "Chọn Biểu tượng",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      children: _danhSachIcon.map((icon) {
                        bool isSelected = icon == iconDuocChon;
                        return GestureDetector(
                          onTap: () => setModalState(() => iconDuocChon = icon),
                          child: CircleAvatar(
                            backgroundColor: isSelected
                                ? mauDuocChon.withOpacity(0.2)
                                : Colors.grey.shade100,
                            child: Icon(
                              icon,
                              color: isSelected ? mauDuocChon : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 3. Chọn Màu sắc
                    const Text(
                      "Chọn Màu sắc",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: _danhSachMau.map((mau) {
                        bool isSelected = mau == mauDuocChon;
                        return GestureDetector(
                          onTap: () => setModalState(() => mauDuocChon = mau),
                          child: Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: mau,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black87, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),

                    // 4. Nút Lưu
                    // 4. NÚT LƯU (ĐÃ GẮN API REAL)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: mauDuocChon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        String tenDM = tenController.text.trim();
                        if (tenDM.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "⚠️ Vui lòng nhập tên danh mục!",
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        // Gọi API bắn dữ liệu lên Strapi
                        try {
                          final url = Uri.parse(
                            'http://10.185.83.167:1337/api/categories',
                          );
                          final response = await http.post(
                            url,
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              "data": {
                                "Name": tenDM,
                                // Nếu Strapi của ông có tạo sẵn field Icon và Color thì mở comment 2 dòng dưới ra nhé:
                                // "Icon": iconDuocChon.codePoint.toString(),
                                // "Color": mauDuocChon.value.toRadixString(16),
                              },
                            }),
                          );

                          if (response.statusCode == 200 ||
                              response.statusCode == 201) {
                            if (context.mounted) {
                              Navigator.pop(context); // Đóng bảng
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("✨ Đã tạo thành công: $tenDM"),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Ép danh sách bên ngoài tải lại cục data mới nhất!
                              setState(() => _isLoading = true);
                              _taiDanhSachTuStrapi();
                            }
                          } else {
                            debugPrint("Lỗi từ server: ${response.body}");
                          }
                        } catch (e) {
                          debugPrint("Lỗi mạng: $e");
                        }
                      },
                      child: const Text(
                        "Lưu Danh Mục",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }, // Đóng StatefulBuilder
        ); // Đóng return
      }, // Đóng builder của BottomSheet
    ); // Đóng showModalBottomSheet
  }

  // --- HÀM BUILD VẼ GIAO DIỆN CHÍNH (Lúc nãy bị mất tiêu) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Quản lý Danh mục",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ), // Mũi tên back màu đen
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _danhSachDanhMuc.length,
              itemBuilder: (context, index) {
                final dm =
                    _danhSachDanhMuc[index]['attributes'] ??
                    _danhSachDanhMuc[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: Colors.blueAccent,
                      ),
                    ),
                    title: Text(
                      dm['Name'] ?? 'Chưa có tên',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        // TODO: Gắn API Xóa danh mục
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        onPressed: _hienThiBangThemDanhMuc,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Thêm mới",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
