import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToolScreen extends StatelessWidget {
  const ToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 车站大屏卡片放在最上面
            Card(
              child: ListTile(
                leading: const Icon(Icons.tv, size: 32),
                title: const Text('车站大屏'),
                subtitle: const Text('查看车站实时信息'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StationScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20), // 添加间距
          ],
        ),
      ),
    );
  }
}

// 车站大屏页面
class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  String? _selectedStationCode;
  String _selectedStationName = '选择车站';
  bool _loading = false;

  void _showStationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StationSelector(
        title: '选择车站',
        selectedCode: _selectedStationCode,
        onSelected: (station) {
          setState(() {
            _selectedStationCode = station['code'];
            _selectedStationName = station['name'] ?? '选择车站';
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('车站大屏')),
      body: Column(
        children: [
          // 单个车站选择器
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _showStationSelector,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedStationCode != null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: _selectedStationCode != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedStationName,
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedStationCode != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 显示按钮（可选）
          if (_selectedStationCode != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          // 这里可以添加显示车站大屏的逻辑
                          setState(() {
                            _loading = true;
                          });
                          Future.delayed(const Duration(seconds: 1), () {
                            setState(() {
                              _loading = false;
                            });
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '显示车站大屏',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

          // 提示信息
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tv, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '车站大屏功能',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请先选择车站',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 车站选择器组件
class StationSelector extends StatefulWidget {
  final String title;
  final String? selectedCode;
  final Function(Map<String, String?>) onSelected;

  const StationSelector({
    super.key,
    required this.title,
    this.selectedCode,
    required this.onSelected,
  });

  @override
  State<StationSelector> createState() => _StationSelectorState();
}

class _StationSelectorState extends State<StationSelector> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<dynamic> _allStations = [];
  Map<String, String> _stationNameMap = {};
  List<dynamic> _filtered = [];
  bool _loadingStations = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final jsonString = await rootBundle.loadString('assets/stations.json');
      final List<dynamic> stationsList = json.decode(jsonString);

      final Map<String, String> nameMap = {};
      for (var station in stationsList) {
        final telecode = station['telecode'];
        final name = station['name'];
        if (telecode != null && name != null) {
          nameMap[telecode] = name;
        }
      }

      setState(() {
        _allStations = stationsList;
        _stationNameMap = nameMap;
        _filtered = stationsList;
      });
    } catch (e) {
      _showSnack('加载站点数据失败: $e');
    } finally {
      setState(() => _loadingStations = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allStations;
      } else {
        _filtered = _allStations.where((station) {
          final name = (station['name'] ?? '').toLowerCase();
          final telecode = (station['telecode'] ?? '').toLowerCase();
          final city = (station['city'] ?? '').toLowerCase();
          return name.contains(query) ||
              telecode.contains(query) ||
              city.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: '搜索车站名称、拼音、电报码',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            autofocus: false,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${_filtered.length} 个车站',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                    },
                    child: const Text('清空搜索'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingStations
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.train, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          '未找到相关车站',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final station = _filtered[index];
                      final code = station['code'] ?? station['telecode'] ?? '';
                      final name = station['name'] ?? '';
                      final telecode = station['telecode'] ?? '';
                      final city = station['city'] ?? '';
                      final selected = code == widget.selectedCode;
                      return ListTile(
                        leading: Icon(
                          Icons.train,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).hintColor,
                        ),
                        title: Text(
                          '$name站',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '$city市 电报码($telecode)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelected({
                            'code': code,
                            'name': name,
                            'telecode': telecode,
                            'city': city,
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
