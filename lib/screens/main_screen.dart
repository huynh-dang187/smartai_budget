import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'chat_ai_screen.dart';
import 'transactions_screen.dart'; // Nạp Tab Sổ thu chi
import 'budget_screen.dart'; // Nạp Tab Ngân sách

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  // Phải có cái này để chạy Animation
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // --- BỘ ĐIỀU KHIỂN HÀO QUANG VIÊN THUỐC ---
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final List<Widget> _pages = [
    const HomeScreen(),
    const TransactionsScreen(),
    const BudgetScreen(),
    const Center(
      child: Text("⚙️ Cài đặt Cá nhân", style: TextStyle(fontSize: 18)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 1. Nhịp thở chậm rãi (2 giây) lặp vô tận
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 2. Phình to ra khoảng 1.5 lần
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    // 3. Mờ dần từ 0.4 xuống 0
    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _pages[_currentIndex],

      // --- CỤM NÚT VIÊN THUỐC TỎA SÁNG ---
      floatingActionButton: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. LỚP HÀO QUANG (Chỉ hiện ở Tab Trang chủ)
          if (_currentIndex == 0)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    // Dùng một cái nút giả để tạo hình dáng hào quang y hệt nút thật
                    child: FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: null,
                      backgroundColor: Colors.blueAccent,
                      elevation: 0,
                      // Nội dung trong suốt để chỉ lấy cái vỏ
                      label: const Text(
                        "Nhập AI",
                        style: TextStyle(color: Colors.transparent),
                      ),
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                );
              },
            ),

          // 2. NÚT BẤM THẬT (Nhỏ gọn hơn)
          _currentIndex == 0
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.blueAccent,
                  elevation: 4,
                  onPressed: () => _goiAI(context),
                  // Tinh chỉnh cho nhỏ lại:
                  extendedPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ), // Bóp gọn 2 bên
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ), // Icon nhỏ đi (chuẩn là 24)
                  label: const Text(
                    "Nhập bằng AI",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ), // Chữ nhỏ lại (chuẩn là 14-15)
                  ),
                )
              : FloatingActionButton(
                  // Nút tròn khi sang tab khác
                  backgroundColor: Colors.blueAccent,
                  elevation: 4,
                  onPressed: () => _goiAI(context),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // --- THANH ĐIỀU HƯỚNG ---
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 15,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.pie_chart_rounded, "Tổng quan", 0),
              _buildNavItem(Icons.receipt_long_rounded, "Thu chi", 1),
              _buildNavItem(
                Icons.account_balance_wallet_rounded,
                "Ngân sách",
                2,
              ),
              _buildNavItem(Icons.settings_rounded, "Cài đặt", 3),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Giữ nguyên 2 hàm _goiAI và _buildNavItem ở dưới)
  void _goiAI(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatAIScreen()),
    ).then((value) {
      setState(() => _currentIndex = 0);
    });
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: isSelected ? 2 : 0),
              child: Icon(
                icon,
                color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
                size: isSelected ? 28 : 24,
              ),
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
