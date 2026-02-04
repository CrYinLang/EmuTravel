// lib/settings.dart
import 'package:flutter/material.dart';
import 'tool.dart';
import 'theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeManager themeManager;

  const SettingsScreen({super.key, required this.themeManager});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.themeManager.isDarkMode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                // 直接切换主题，会有平滑的渐变效果
                widget.themeManager.toggleTheme(newValue);
              },
            ),
          ],
        ),
      ],
    );
  }
}