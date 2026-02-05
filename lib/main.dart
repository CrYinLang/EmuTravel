// lib/main.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'about_page.dart';
import 'settings.dart';
import 'theme_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Vars {
  static const String lastUpdate = '26-02-04-20-50';
  static const String version = '1.0.0.0';
  static const String build = '1000';
  static const Map<String, String> normalHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
    'Accept': 'application/json',
    'Accept-Language': 'zh-CN,zh-Hans;q=0.9',
  };

  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse('https://gitee.com/CrYinLang/EmuTravel/raw/master/version.json'),
        headers: normalHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('获取版本信息失败: $e');
    }
    return null;
  }
}

void main() {
  runApp(const EmuTravel());
}

class EmuTravel extends StatefulWidget {
  const EmuTravel({super.key});

  @override
  State<EmuTravel> createState() => _EmuTravelState();
}

class _EmuTravelState extends State<EmuTravel> {
  final ThemeManager _themeManager = ThemeManager();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(_onThemeChanged);
    _isDarkMode = _themeManager.isDarkMode;
  }

  void _onThemeChanged() {
    setState(() {
      _isDarkMode = _themeManager.isDarkMode;
    });
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedTheme(
      data: _isDarkMode  // 修复：添加 data: 参数
          ? ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      )
          : ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      duration: const Duration(milliseconds: 300), // 渐变动画
      child: MaterialApp(
        title: 'EmuTravel',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: HomePage(themeManager: _themeManager),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeManager themeManager;

  const HomePage({super.key, required this.themeManager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // 定义每个页面的昵称
  String get _currentPageNickname {
    switch (_currentIndex) {
      case 0:
        return '旅行规划中心';
      case 1:
        return '关于页面';
      case 2:
        return '个性化设置';
      default:
        return 'EmuTravel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPageNickname), // 动态显示页面昵称
        centerTitle: true,
      ),
      body: _getCurrentPage(),
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
            icon: Icon(Icons.info),
            label: '关于',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  // 根据索引返回对应的页面
  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const AboutPage();  // 修复：移除 themeManager 参数
      case 2:
        return SettingsScreen(themeManager: widget.themeManager);
      default:
        return const HomeScreen();
    }
  }
}