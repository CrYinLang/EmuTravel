// lib/settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tool.dart';
import 'theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeManager themeManager;

  const SettingsScreen({super.key, required this.themeManager});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 新增的开关状态
  bool _showTrainImageSystem = true;
  bool _showTrainImagePersonal = true;
  bool _showTrainBureauIcon = true;

  // SharedPreferences 键名
  static const String _trainImageSystemKey = 'show_train_image_system';
  static const String _trainImagePersonalKey = 'show_train_image_personal';
  static const String _trainBureauIconKey = 'show_train_bureau_icon';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 从 SharedPreferences 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _showTrainImageSystem = prefs.getBool(_trainImageSystemKey) ?? true;
      _showTrainImagePersonal = prefs.getBool(_trainImagePersonalKey) ?? true;
      _showTrainBureauIcon = prefs.getBool(_trainBureauIconKey) ?? true;
    });
  }

  // 保存设置到 SharedPreferences
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.themeManager.isDarkMode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 原有的主题设置
        Tool.buildSection(
          context: context,
          icon: Icons.color_lens,
          title: '主题设置',
          children: [
            Tool.buildSwitch(
              context: context,
              title: '深色主题',
              subtitle: '启用深色模式',
              icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
              value: isDarkMode,
              onChanged: (bool newValue) {
                widget.themeManager.toggleTheme(newValue);
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 新增的列车显示设置
        Tool.buildSection(
          context: context,
          icon: Icons.train,
          title: '列车显示设置',
          children: [
            Tool.buildSwitch(
              context: context,
              title: '显示列车图片(系统)',
              subtitle: '显示系统提供的列车图片',
              icon: Icons.photo_library,
              value: _showTrainImageSystem,
              onChanged: (bool newValue) async {
                setState(() {
                  _showTrainImageSystem = newValue;
                });
                await _saveSetting(_trainImageSystemKey, newValue);
              },
            ),

            const Divider(height: 1),

            Tool.buildSwitch(
              context: context,
              title: '显示列车图片(个人)',
              subtitle: '显示个人上传的列车图片',
              icon: Icons.photo_camera,
              value: _showTrainImagePersonal,
              onChanged: (bool newValue) async {
                setState(() {
                  _showTrainImagePersonal = newValue;
                });
                await _saveSetting(_trainImagePersonalKey, newValue);
              },
            ),

            const Divider(height: 1),

            Tool.buildSwitch(
              context: context,
              title: '显示列车路局图标',
              subtitle: '显示列车所属路局的图标',
              icon: Icons.account_balance,
              value: _showTrainBureauIcon,
              onChanged: (bool newValue) async {
                setState(() {
                  _showTrainBureauIcon = newValue;
                });
                await _saveSetting(_trainBureauIconKey, newValue);
              },
            ),
          ],
        ),
      ],
    );
  }
}