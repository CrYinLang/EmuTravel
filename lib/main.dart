// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'about_page.dart';
import 'settings.dart';

import 'journey_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'dart:convert';
import 'dart:math';
import 'dart:io';

bool _isDarkMode = true;

Future<String> deviceID() async {
  final prefs = await SharedPreferences.getInstance();
  String? storedDeviceID = prefs.getString('deviceID');

  // 如果 SharedPreferences 中有值，直接返回
  if (storedDeviceID != null && storedDeviceID.isNotEmpty) {
    return storedDeviceID;
  }

  // 如果都读取不到，生成新的设备ID
  String newDeviceID = _generateDigitID();

  await prefs.setString('deviceID', newDeviceID);

  return newDeviceID;
}

String _generateDigitID() {
  final random = Random();
  StringBuffer buffer = StringBuffer();
  for (int i = 0; i < 12; i++) {
    buffer.write(random.nextInt(10));
  }
  return buffer.toString();
}

String calculateMD5(String input) {
  return md5.convert(utf8.encode(input)).toString();
}

class Vars {
  static const String lastUpdate = '26-02-09-16-00';
  static const String version = '1.1.1.0';
  static const String build = '1110';
  static const String urlServer = 'https://gitee.com/CrYinLang/EmuTravel/raw/master/version.json';
  static const String commandServer = 'https://gitee.com/CrYinLang/EmuTravel/raw/master/remote.json';

  static const Map<String, String> normalHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
    'Accept': 'application/json',
    'Accept-Language': 'zh-CN,zh-Hans;q=0.9',
  };

  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse(urlServer),
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

  static Future<List<dynamic>?> fetchCommands() async {
    try {
      final response = await http.get(
        Uri.parse(commandServer),
        headers: normalHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('获取命令失败: $e');
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

//水印
class WatermarkPainter extends CustomPainter {
  final String deviceID;

  const WatermarkPainter({required this.deviceID});

  @override
  void paint(Canvas canvas, Size size) {
    const alpha = 0.025;
    final textStyle = TextStyle(
      color: _isDarkMode
          ? const Color.fromRGBO(255, 255, 255, 1).withValues(alpha: alpha)
          : const Color.fromRGBO(0, 0, 0, 1).withValues(alpha: alpha),
      fontSize: 16,
      fontWeight: FontWeight.w300,
    );

    final textSpan = TextSpan(text: deviceID, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    const horizontalSpacing = 00.0;
    const verticalSpacing = 10.0;

    final horizontalCount = (size.width / (textWidth + horizontalSpacing)).ceil() + 1;
    final verticalCount = (size.height / (textHeight + verticalSpacing)).ceil() + 1;

    for (int i = 0; i < horizontalCount; i++) {
      for (int j = 0; j < verticalCount; j++) {
        final x = i * (textWidth + horizontalSpacing) - textWidth / 2;
        final y = j * (textHeight + verticalSpacing) - textHeight / 2;

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-30 * pi / 180);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WatermarkWidget extends StatelessWidget {
  final Widget child;
  final String deviceID;

  const WatermarkWidget({
    super.key,
    required this.child,
    required this.deviceID,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        IgnorePointer(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: CustomPaint(
              painter: WatermarkPainter(deviceID: deviceID),
            ),
          ),
        ),
      ],
    );
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
      _checkRemoteCommands();
    });
  }

  Future<void> _checkRemoteCommands() async {
    try {
      final commands = await Vars.fetchCommands();
      final myDeviceID = await deviceID();
      bool deviceFound = false;

      if (commands != null) {
        for (var command in commands) {
          if (command is Map<String, dynamic> && command['id'] == myDeviceID) {
            deviceFound = true;

            bool isTrue(String? value) {
              if (value == null) return false;
              final normalizedValue = value.trim().toLowerCase();
              final trueValues = {'True', 'true', 'Y', 'y', '1'};
              return trueValues.contains(normalizedValue);
            }

            // 检查内测资格
            final isInternal = isTrue(command['isInternal']?.toString());
            final user = command['user']?.toString() ?? '';
            final qq = command['qq']?.toString() ?? '';

            if (!isInternal) {
              _showInternalTestQualificationDialog(myDeviceID);
              return;
            } else {
              // 重试成功，先关闭内测资格弹窗，再显示欢迎弹窗
              _closeQualificationDialog();
              _showWelcomeDialog(user, qq, myDeviceID);
            }

            // 处理远程命令（只有有内测资格的用户才会执行到这里）
            final operation = command['operation']?.toString() ?? '';
            final message = command['message']?.toString();

            if (operation == 'exit') {
              Future.delayed(const Duration(milliseconds: 500), () {
                exit(0);
              });
              return;
            }

            if (message != null && message.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _commandMessage = message;
                });
              }
            }
            break;
          }
        }
      }

      // 如果没有找到对应的设备ID，显示提示
      if (!deviceFound) {
        _showInternalTestQualificationDialog(myDeviceID);
      }
    } catch (e) {
      debugPrint('检查远程命令失败: $e');
    }
  }

  void _closeQualificationDialog() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showInternalTestQualificationDialog(String deviceID) {
    _closeQualificationDialog();
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('内测资格缺失!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你的设备ID: $deviceID',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '您并未获取内测资格，无法使用本应用',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              actions: [
                // 复制ID按钮
                TextButton.icon(
                  onPressed: () {
                    _copyToClipboard(deviceID);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('设备ID已复制到剪贴板'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('复制ID'),
                ),
                const SizedBox(width: 8),
                // 重试按钮 - 添加加载状态
                StatefulBuilder(
                  builder: (context, setState) {
                    return OutlinedButton(
                      onPressed: () async {
                        // 显示加载状态
                        setState(() {});

                        // 重新检查命令
                        await _checkRemoteCommands();
                      },
                      child: const Text('重试'),
                    );
                  },
                ),
                // 退出按钮
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    exit(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('退出'),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _copyToClipboard(String text) async {
       await Clipboard.setData(ClipboardData(text: text));
  }

  void _showWelcomeDialog(String user, String qq, String deviceID) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false, // 禁用返回键
            child: AlertDialog(
              title: const Text('欢迎参加内测!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('用户名: $user'),
                  Text('QQ: $qq'),
                  Text('设备ID: $deviceID'),
                  const SizedBox(height: 8),
                  const Text('感谢您参与EmuTravel内测！'),
                  const Text('${Vars.version} ${Vars.lastUpdate}'),
                  const Text('禁止外传!'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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

  void _showCommandMessageDialog() {
    if (_commandMessage != null && navigatorKey.currentContext != null) {
      final message = _commandMessage!;
      final myDeviceID = deviceID();

      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return FutureBuilder<String>(
            future: myDeviceID,
            builder: (context, snapshot) {
              return PopScope(
                canPop: false, // 禁用返回键
                child: AlertDialog(
                  title: const Text('系统消息'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(message),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
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

    return FutureBuilder<String>(
      future: deviceID(),
      builder: (context, snapshot) {
        final watermarkText = '${snapshot.data} ${Vars.build}';

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
              child: WatermarkWidget(
                deviceID: watermarkText,
                child: HomePage(themeManager: _themeManager),
              ),
            ),
            builder: (context, child) {
              return WatermarkWidget(
                deviceID: watermarkText,
                child: child!,
              );
            },
          ),
        );
      },
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
        title: Text(_currentPageNickname),
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
        return const AboutPage();
      case 2:
        return SettingsScreen(themeManager: widget.themeManager);
      default:
        return const HomeScreen();
    }
  }
}