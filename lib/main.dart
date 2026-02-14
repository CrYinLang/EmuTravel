// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'home_screen.dart';
import 'about_page.dart';
import 'settings.dart';
import 'update.dart';
import 'tool_screen.dart';

import 'journey_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:io';

bool _isDarkMode = true;

class Vars {
  static const String lastUpdate = '26-02-14-19-00';
  static const String version = '1.1.2.0';
  static const String build = '1120';
  static const String urlServer ='https://gitee.com/CrYinLang/EmuTravel/raw/master/version.json';
  static const String commandServer ='https://gitee.com/CrYinLang/EmuTravel/raw/master/remote.json';

  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    final response = await http.get(Uri.parse(urlServer)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchCommand() async {
    final response = await http.get(Uri.parse(commandServer)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        return data;
      }
    }
    return null;
  }
}

void main() {
  runApp(const EmuTravel());
}

class ThemeManager with ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';

  bool get isDarkMode => _isDarkMode;

  ThemeManager() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? _isDarkMode;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }
}

class EmuTravel extends StatefulWidget {
  const EmuTravel({super.key});

  @override
  State<EmuTravel> createState() => _EmuTravelState();
}

class _EmuTravelState extends State<EmuTravel> {
  final ThemeManager _themeManager = ThemeManager();
  bool _isDarkMode = true;
  String? _commandMessage;
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _handleUpdate();
    _themeManager.addListener(_onThemeChanged);
    _isDarkMode = _themeManager.isDarkMode;
    _initializeApp();
  }

  void _onThemeChanged() {
    setState(() {
      _isDarkMode = _themeManager.isDarkMode;
    });
  }

  Future<void> _initializeApp() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRemoteCommand();
    });
  }

  Future<void> _checkRemoteCommand() async {
    final command = await Vars.fetchCommand();

    if (command == null) {
      return;
    }

    final message = command['message']?.toString();
    if (message != null && message.isNotEmpty) {
      if (mounted) {
        setState(() {
          _commandMessage = message;
        });
      }
    }

    final operation = command['operation']?.toString() ?? '';
    if (operation.isNotEmpty) {
      _handleOperation(operation);
    }
  }

  Future<bool> _getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  void _handleOperation(String operation) {
    switch (operation) {
      case 'exit':
        Future.delayed(const Duration(milliseconds: 100), () {
          exit(0);
        });
        break;
    }
  }

  // 直接处理更新操作
  Future<void> _handleUpdate() async {
    bool update = await _getSetting('show_auto_update');
    if (update) {
      final versionInfo = await Vars.fetchVersionInfo();
      if (versionInfo != null) {
        final remoteBuild = versionInfo['Build']?.toString() ?? '';
        final currentBuild = Vars.build;

        if (remoteBuild.isNotEmpty &&
            int.tryParse(remoteBuild) != null &&
            int.tryParse(currentBuild) != null) {
          final remoteBuildNum = int.parse(remoteBuild);
          final currentBuildNum = int.parse(currentBuild);

          if (remoteBuildNum > currentBuildNum && mounted &&
              navigatorKey.currentContext != null) {
            UpdateUI.showUpdateFlow(navigatorKey.currentContext!);
          }
        }
      }
    }
  }

  void _showCommandMessageDialog() {
    if (_commandMessage != null && navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('系统消息'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(_commandMessage!),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _commandMessage = null;
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_commandMessage != null && mounted) {
        _showCommandMessageDialog();
      }
    });

    return ChangeNotifierProvider(
      create: (_) => JourneyProvider(),
      child: MaterialApp(
        title: 'EmuTravel',
        navigatorKey: navigatorKey,
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
        home: AnimatedTheme(
          data: _isDarkMode
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
          duration: const Duration(milliseconds: 300),
          child: HomePage(themeManager: _themeManager),
        ),
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

  String get _currentPageNickname {
    switch (_currentIndex) {
      case 0:
        return '行程中心';
      case 1:
        return '工具';
      case 2:
        return '关于页面';
      case 3:
        return '个性化设置';
      default:
        return 'EmuTravel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentPageNickname), centerTitle: true),
      body: _getCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: '工具'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: '关于'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ToolScreen();
      case 2:
        return const AboutPage();
      case 3:
        return SettingsScreen(themeManager: widget.themeManager);
      default:
        return const HomeScreen();
    }
  }
}