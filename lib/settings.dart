// lib/settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool.dart';
import 'update.dart';
import 'main.dart';

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

  // 构建列表项的方法
  Widget _buildTile({
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    IconData? trailingIcon,
    VoidCallback? onTap
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.colorScheme.primary, size: 24)
          : null,
      title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500)
      ),
      subtitle: subtitle != null
          ? Text(
          subtitle,
          style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)
          )
      )
          : null,
      trailing: trailing ?? (trailingIcon != null
          ? Icon(trailingIcon, size: 16, color: theme.colorScheme.onSurfaceVariant)
          : null),
      onTap: onTap,
    );
  }

  // 构建设置区块的方法
  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)
            ),
          ),
          ...children,
        ],
      ),
    );
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

        const SizedBox(height: 16),

        _buildSection(
          icon: Icons.info,
          title: '应用信息',
          children: [
            _buildTile(
              title: '版本',
              subtitle: '${Vars.version} | ${Vars.build} | ${Vars.lastUpdate}',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => UpdateUI.showUpdateFlow(context),
            ),
            _buildTile(
              title: '开发者',
              subtitle: 'Cr.YinLang',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => Tool.showDeveloperDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}