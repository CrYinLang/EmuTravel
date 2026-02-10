// home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'journey.dart';
import 'journey_provider.dart';
import 'journey_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的行程'),
        actions: [
          Consumer<JourneyProvider>(
            builder: (context, provider, child) {
              if (provider.journeys.isEmpty) return const SizedBox();
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'sort') {
                    provider.sortByDate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已按日期排序')),
                    );
                  } else if (value == 'clear') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认清空'),
                        content: const Text('确定要清空所有行程吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              provider.clearAll();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[300],
                            ),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'sort',
                    child: Row(
                      children: [
                        Icon(Icons.sort),
                        SizedBox(width: 8),
                        Text('按日期排序'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('清空所有', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<JourneyProvider>(
        builder: (context, provider, child) {
          if (provider.journeys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.train_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有添加行程',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.journeys.length,
            itemBuilder: (context, index) {
              final journey = provider.journeys[index];
              return JourneyCard(
                journey: journey,
                onDelete: () => provider.removeJourney(journey.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddJourneyPage()),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// 行程卡片组件
class JourneyCard extends StatefulWidget {
  final Journey journey;
  final VoidCallback onDelete;

  const JourneyCard({
    super.key,
    required this.journey,
    required this.onDelete,
  });

  @override
  State<JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<JourneyCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isPast = journey.travelDate.isBefore(DateTime(now.year, now.month, now.day));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 卡片头部（可点击区域）
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部：车次和日期
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue.shade900
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              journey.trainCode,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                          if (isPast)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '已过期',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          AnimatedIcon(
                            icon: AnimatedIcons.arrow_menu,
                            progress: _animation,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: Text('确定要删除 ${journey.trainCode} 次列车吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('取消'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        widget.onDelete();
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[300],
                                      ),
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 中间：站点和时间
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              journey.departureTime,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              journey.fromStation,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              color: Theme.of(context).hintColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              journey.getTotalDuration(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              journey.arrivalTime,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              journey.toStation,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).hintColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 底部：日期和站点数
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}上车',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${journey.stations.length} 个站点',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 展开的详细信息
          SizeTransition(
            sizeFactor: _animation,
            child: _buildExpandedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final journey = widget.journey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 获取起始终到区间的站点索引
    String normalizeStationName(String name) {
      // 移除 站 字进行标准化处理
      return name.replaceAll('站', '').trim();
    }
    
    final fromIndex = journey.stations.indexWhere((station) =>
    normalizeStationName(station.stationName) == normalizeStationName(journey.fromStation));
    final toIndex = journey.stations.indexWhere((station) =>
    normalizeStationName(station.stationName) == normalizeStationName(journey.toStation));


    // 确保索引有效且起始站索引小于终点站索引
    final startIndex = fromIndex >= 0 ? fromIndex : 0;
    final endIndex = toIndex >= 0 && toIndex >= startIndex ? toIndex : journey.stations.length - 1;

    // 获取区间内的站点列表
    final intervalStations = journey.stations.sublist(startIndex, endIndex + 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 行程基本信息 - 新格式
          _buildInfoSection('行程信息', Icons.info_outline, [
            // 第一行：车次和时长
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    '车次${journey.trainCode}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '时长${journey.getTotalDuration().replaceAll('\n', ' ')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),

            // 第二行：始终站
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '始终站',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${journey.fromStation}->${journey.toStation}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 第三行：乘车日期
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '乘车日期:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            // 第四行：列车时间
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    '列车时间',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${journey.departureTime}->${journey.arrivalTime}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // 站点详情 - 延长高度并只显示起始终到区间
          _buildInfoSection('站点详情', Icons.train, [
            Container(
              height: 400, // 延长到400px高度
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: intervalStations.length,
                itemBuilder: (context, index) {
                  final station = intervalStations[index];
                  final isFrom = station.stationName == journey.fromStation;
                  final isTo = station.stationName == journey.toStation;
                  final globalIndex = startIndex + index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFrom || isTo
                            ? Colors.blue.shade300
                            : Colors.grey.shade300,
                        width: isFrom || isTo ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 站点序号
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isFrom || isTo
                                ? Colors.blue
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${globalIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 站点信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    station.stationName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isFrom || isTo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isFrom || isTo
                                          ? Colors.blue.shade700
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (isFrom) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '上车站',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isTo) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '下车站',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '到达: ${station.arrivalTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                  if (station.stayTime > 0)
                                    Text(
                                      '停站: ${station.stayTime}分',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  Text(
                                    '发车: ${station.departureTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (station.dayDifference > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '跨天: +${station.dayDifference}天',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.purple.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showDetailDialog(context);
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('查看详情'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showSnack('分享功能开发中');
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('分享行程'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  void _showDetailDialog(BuildContext context) {
    final journey = widget.journey;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${journey.trainCode} 次列车详情'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 新格式的详情信息
                _buildDialogInfoRow('车次', journey.trainCode),
                _buildDialogInfoRow('时长', journey.getTotalDuration().replaceAll('\n', ' ')),
                _buildDialogInfoRow('始终站', '${journey.fromStation}->${journey.toStation}'),
                _buildDialogInfoRow('乘车日期',
                    '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                    isBoldRed: true
                ),
                _buildDialogInfoRow('列车时间', '${journey.departureTime}->${journey.arrivalTime}'),
                _buildDialogInfoRow('站点数量', '${journey.stations.length} 个'),
                _buildDialogInfoRow('添加方式', journey.isStation ? '车站查询' : '车次查询'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value, {bool isBoldRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isBoldRed
                  ? const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// 站点选择器模态框组件（保持不变）
class StationSelectorModal extends StatefulWidget {
  final List<dynamic> stations;
  final String? selectedCode;
  final String title;

  const StationSelectorModal({
    super.key,
    required this.stations,
    this.selectedCode,
    required this.title,
  });

  @override
  State<StationSelectorModal> createState() => _StationSelectorModalState();
}

class _StationSelectorModalState extends State<StationSelectorModal> {
  List<dynamic> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _filtered = widget.stations;
    _searchCtrl.addListener(() {
      final query = _searchCtrl.text.trim().toLowerCase();
      if (query.isEmpty) {
        setState(() => _filtered = widget.stations);
      } else {
        setState(
              () => _filtered = widget.stations.where((s) {
            final n = s['name']?.toString().toLowerCase() ?? '';
            final p = s['pinyin']?.toString().toLowerCase() ?? '';
            final sc = s['short_code']?.toString().toLowerCase() ?? '';
            final t = s['telecode']?.toString().toLowerCase() ?? '';
            final c = s['city']?.toString().toLowerCase() ?? '';
            return n.contains(query) ||
                p.contains(query) ||
                sc.contains(query) ||
                t.contains(query) ||
                c.contains(query);
          }).toList(),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
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
            child: _filtered.isEmpty
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
                final s = _filtered[index];
                final code = s['code']?.toString() ?? '';
                final name = s['name']?.toString() ?? '';
                final telecode = s['telecode']?.toString() ?? '';
                final city = s['city']?.toString() ?? '';
                final selected = code == widget.selectedCode;
                return ListTile(
                  leading: Icon(
                    Icons.train,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).hintColor,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '$city ($telecode)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.of(context).pop({
                    'code': code,
                    'name': name,
                    'telecode': telecode,
                    'city': city,
                  }),
                );
              },
            ),
        ),
          ],
        ),
    );
  }
}