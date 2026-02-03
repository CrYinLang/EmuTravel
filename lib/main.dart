import 'package:flutter/material.dart';

void main() {
  runApp(EmuTravel());
}

class EmuTravel extends StatelessWidget {
  const EmuTravel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmuTravel',
      home: HomePage(), // 改为使用包含底部导航栏的主页
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // 当前选中的导航项索引[1,3](@ref)

  // 定义各个页面（后续可以替换为您的实际页面）
  final List<Widget> _pages = [
    Center(child: Text('首页内容')), // 页面1
    Center(child: Text('设置内容')), // 页面2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EmuTravel'),
        centerTitle: true,
      ),
      body: _pages[_currentIndex], // 显示当前选中的页面[1,3](@ref)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // 当前选中的索引[3,6](@ref)
        onTap: (int index) {
          setState(() {
            _currentIndex = index; // 点击时更新索引[1,3](@ref)
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        type: BottomNavigationBarType.fixed, // 防止超过3个项时的样式问题[3](@ref)
        fixedColor: Colors.blue, // 选中项的颜色[3,6](@ref)
      ),
    );
  }
}