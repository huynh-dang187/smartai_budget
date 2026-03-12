import 'package:flutter/material.dart';
import 'home_screen.dart'; // Nạp Tab Trang chủ
import 'chat_ai_screen.dart'; // Nạp màn hình AI

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // Biến nhớ xem đang ở Tab nào

  // Danh sách các màn hình (Tab)
  final List<Widget> _pages = [
    const HomeScreen(), // Tab 0: Trang chủ hôm nay anh em mình làm
    const Center(
      child: Text(
        "📊 Tính năng Ngân sách (Sắp ra mắt)",
        style: TextStyle(fontSize: 20),
      ),
    ), // Tab 1
    const Center(
      child: Text(
        "👤 Màn hình Cá nhân (Sắp ra mắt)",
        style: TextStyle(fontSize: 20),
      ),
    ), // Tab 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hiển thị Tab tương ứng với _currentIndex
      body: _pages[_currentIndex],

      // 1. NÚT AI NỔI BẬT Ở GIỮA
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(), // Bo tròn vo
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        onPressed: () {
          // Chuyển sang màn hình Chat AI
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatAIScreen()),
          ).then((value) {
            // Khi chat xong quay về, ép màn hình load lại Tab 0
            setState(() {
              _currentIndex = 0;
            });
          });
        },
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
      ),

      // Ghim nút nổi vào chính giữa cạnh dưới
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 2. THANH ĐIỀU HƯỚNG BÊN DƯỚI (Khoét lỗ cho nút AI)
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Hiệu ứng khoét lỗ siêu ngầu
        notchMargin: 8.0, // Khoảng cách từ viền lỗ đến nút AI
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Cụm bên trái
              _buildNavItem(Icons.pie_chart, "Tổng quan", 0),

              const SizedBox(width: 40), // Chừa khoảng trống ở giữa cho nút AI
              // Cụm bên phải
              _buildNavItem(Icons.account_balance_wallet, "Ngân sách", 1),
            ],
          ),
        ),
      ),
    );
  }

  // Hàm vẽ từng nút bấm trên thanh Nav Bar
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.grey,
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
