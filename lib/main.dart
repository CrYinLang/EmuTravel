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
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

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
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
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
        type: BottomNavigationBarType.fixed,
        fixedColor: Colors.blue,
      ),
    );
  }
}