import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart AI Budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Biểu đồ chi tiêu sẽ nằm ở đây!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
      // Cái nút tròn góc phải dưới cùng để thêm giao dịch
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print("Chuẩn bị làm tính năng AI Chat ở đây");
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm chi tiêu'),
      ),
    );
  }
}
