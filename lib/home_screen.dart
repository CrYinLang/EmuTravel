// home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'journey.dart';
import 'journey_provider.dart';
import 'journey_model.dart';
import 'linemap.dart';

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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已按日期排序')));
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
                  Icon(Icons.train_outlined, size: 80, color: Colors.grey[400]),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AddJourneyPage())),
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

  const JourneyCard({super.key, required this.journey, required this.onDelete});

  @override
  State<JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<JourneyCard>
    with SingleTickerProviderStateMixin {
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

  // 检测行程状态
  String _getJourneyStatus() {
    final journey = widget.journey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final travelDay = DateTime(
      journey.travelDate.year,
      journey.travelDate.month,
      journey.travelDate.day,
    );

    // 检查是否已过期（旅行日期在今天之前）
    if (travelDay.isBefore(today)) {
      return '已过期';
    }

    // 检查是否是今天
    if (travelDay == today) {
      // 解析上车时间
      final departureTime = _parseTime(journey.departureTime);
      if (departureTime == null) return '今天';

      // 计算实际上车时间（考虑跨天）
      final actualDeparture = DateTime(
        journey.travelDate.year,
        journey.travelDate.month,
        journey.travelDate.day,
        departureTime.hour,
        departureTime.minute,
      );

      // 解析下车时间
      final arrivalTime = _parseTime(journey.arrivalTime);
      if (arrivalTime == null) return '今天';

      // 计算实际下车时间（考虑跨天）
      int dayOffset = 0;
      final totalDuration = journey.getTotalDuration();
      if (totalDuration.contains('跨')) {
        // 从时长中提取跨天天数
        final match = RegExp(r'跨(\d+)天').firstMatch(totalDuration);
        if (match != null) {
          dayOffset = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }

      final actualArrival = DateTime(
        journey.travelDate.year,
        journey.travelDate.month,
        journey.travelDate.day + dayOffset,
        arrivalTime.hour,
        arrivalTime.minute,
      );

      // 检查状态
      if (now.isAfter(actualArrival)) {
        return '已到达';
      } else if (now.isAfter(actualDeparture)) {
        return '已上车';
      } else {
        return '今天';
      }
    }

    // 未来行程
    final difference = travelDay.difference(today).inDays;
    if (difference == 1) {
      return '明天';
    } else if (difference == 2) {
      return '后天';
    } else if (difference > 0) {
      return '$difference天后';
    } else {
      return '今天';
    }
  }

  DateTime? _parseTime(String timeStr) {
    if (timeStr.isEmpty || timeStr == '--:--') return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(2000, 1, 1, hour, minute);
  }

  // 获取状态颜色
  Color _getStatusColor(String status) {
    switch (status) {
      case '已过期':
      case '已到达':
        return Colors.red;
      case '已上车':
        return Colors.green;
      case '今天':
        return Colors.orange;
      case '明天':
      case '后天':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // 检测站点状态
  String _getStationStatus(
    StationDetail station,
    Journey journey,
    bool isFrom,
    bool isTo,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final travelDay = DateTime(
      journey.travelDate.year,
      journey.travelDate.month,
      journey.travelDate.day,
    );

    // 检查是否已过期
    if (travelDay.isBefore(today)) {
      return '已过';
    }

    // 检查是否是今天
    if (travelDay == today) {
      // 解析站点到达时间
      final arrivalTime = _parseTime(station.arrivalTime);
      final departureTime = _parseTime(station.departureTime);

      if (arrivalTime != null && departureTime != null) {
        // 计算实际时间（考虑跨天）
        int dayOffset = station.dayDifference;
        final actualArrival = DateTime(
          journey.travelDate.year,
          journey.travelDate.month,
          journey.travelDate.day + dayOffset,
          arrivalTime.hour,
          arrivalTime.minute,
        );

        final actualDeparture = DateTime(
          journey.travelDate.year,
          journey.travelDate.month,
          journey.travelDate.day + dayOffset,
          departureTime.hour,
          departureTime.minute,
        );

        // 检查状态
        if (now.isAfter(actualDeparture)) {
          return '已过';
        } else if (now.isAfter(actualArrival)) {
          return station.stayTime > 0 ? '停站中' : '已到';
        } else {
          return '未到';
        }
      }
    }

    return '';
  }

  // 获取站点状态颜色
  Color _getStationStatusColor(String status) {
    switch (status) {
      case '已过':
        return Colors.red;
      case '已到':
      case '停站中':
        return Colors.green;
      case '未到':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _getJourneyStatus();
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  // 头部：车次和状态
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
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
                                  content: Text(
                                    '确定要删除 ${journey.trainCode} 次列车吗？',
                                  ),
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
                              '${journey.fromStation}站',
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
                              '${journey.toStation}站',
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
                          // 修改这里：计算区间站点数量
                          Consumer<JourneyProvider>(
                            builder: (context, provider, child) {
                              // 获取起始终到区间的站点索引
                              final fromIndex = journey.stations.indexWhere((station) =>
                              _normalizeStationName(station.stationName) == _normalizeStationName(journey.fromStation));
                              final toIndex = journey.stations.indexWhere((station) =>
                              _normalizeStationName(station.stationName) == _normalizeStationName(journey.toStation));

                              // 确保索引有效且起始站索引小于终点站索引
                              final startIndex = fromIndex >= 0 ? fromIndex : 0;
                              final endIndex = toIndex >= 0 && toIndex >= startIndex ? toIndex : journey.stations.length - 1;

                              // 计算区间站点数量
                              final intervalCount = endIndex - startIndex + 1;

                              return Text(
                                '$intervalCount 个站点',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).hintColor,
                                ),
                              );
                            },
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
    final status = _getJourneyStatus();

    // 获取起始终到区间的站点索引
    final fromIndex = journey.stations.indexWhere(
      (station) =>
          _normalizeStationName(station.stationName) ==
          _normalizeStationName(journey.fromStation),
    );
    final toIndex = journey.stations.indexWhere(
      (station) =>
          _normalizeStationName(station.stationName) ==
          _normalizeStationName(journey.toStation),
    );

    // 确保索引有效且起始站索引小于终点站索引
    final startIndex = fromIndex >= 0 ? fromIndex : 0;
    final endIndex = toIndex >= 0 && toIndex >= startIndex
        ? toIndex
        : journey.stations.length - 1;

    // 获取区间内的站点列表
    final intervalStations = journey.stations.sublist(startIndex, endIndex + 1);

    // 计算起始站的绝对天数差（作为基准）
    final baseDayDiff = startIndex >= 0 && startIndex < journey.stations.length
        ? journey.stations[startIndex].dayDifference
        : 0;




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
          // 行程状态信息
          _buildInfoSection('行程状态', Icons.access_time, [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor(status), width: 1),
              ),
              child: Center(
                child: Text(
                  '当前状态: $status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // 行程基本信息
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
                      '${journey.fromStation}站->${journey.toStation}站',
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

          // 站点详情
          _buildInfoSection('站点详情', Icons.train, [
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: intervalStations.length,
                itemBuilder: (context, index) {
                  final station = intervalStations[index];
                  final isFrom = station.stationName == journey.fromStation;
                  final isTo = station.stationName == journey.toStation;

                  // 计算相对跨天天数（相对于起始站）
                  final relativeDayDiff = station.dayDifference - baseDayDiff;

                  // 检查站点状态
                  final stationStatus = _getStationStatus(
                    station,
                    journey,
                    isFrom,
                    isTo,
                  );
                  final stationStatusColor = _getStationStatusColor(
                    stationStatus,
                  );

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
                        // 站点序号和状态
                        Column(
                          children: [
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
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (stationStatus.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: stationStatusColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  stationStatus,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: stationStatusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                                    '${station.stationName}站',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isFrom || isTo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isFrom || isTo
                                          ? Colors.blue.shade700
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
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
                                          color: Colors.black,
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
                                          color: Colors.black,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              if (relativeDayDiff > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '跨天: +$relativeDayDiff天',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
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
                    _showRouteMapDialog(context);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('线路图'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRouteMapDialog(BuildContext context) {
    final journey = widget.journey;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: LineMapDialog(journey: journey),
        ),
      ),
    );
  }
  // 添加站点名称标准化方法
  String _normalizeStationName(String name) {
    return name.replaceAll('站', '').trim();
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  int _getIntervalStationCount() {
    final journey = widget.journey;

    // 获取起始终到区间的站点索引
    final fromIndex = journey.stations.indexWhere((station) =>
    _normalizeStationName(station.stationName) == _normalizeStationName(journey.fromStation));
    final toIndex = journey.stations.indexWhere((station) =>
    _normalizeStationName(station.stationName) == _normalizeStationName(journey.toStation));

    // 确保索引有效且起始站索引小于终点站索引
    final startIndex = fromIndex >= 0 ? fromIndex : 0;
    final endIndex = toIndex >= 0 && toIndex >= startIndex ? toIndex : journey.stations.length - 1;

    return endIndex - startIndex + 1;
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
                _buildDialogInfoRow('车次', journey.trainCode),
                _buildDialogInfoRow(
                  '时长',
                  journey.getTotalDuration().replaceAll('\n', ' '),
                ),
                _buildDialogInfoRow(
                  '始终站',
                  '${journey.fromStation}站->${journey.toStation}站',
                ),
                _buildDialogInfoRow(
                  '乘车日期',
                  '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                  isBoldRed: true,
                ),
                _buildDialogInfoRow(
                  '列车时间',
                  '${journey.departureTime}->${journey.arrivalTime}',
                ),
                // 修改这里：显示区间站点数量而不是全程
                _buildDialogInfoRow(
                    '站点数量',
                    '区间${_getIntervalStationCount()}个 / 全程${journey.stations.length}个'
                ),
                _buildDialogInfoRow(
                  '添加方式',
                  journey.isStation ? '车站查询' : '车次查询',
                ),
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

  Widget _buildDialogInfoRow(
    String label,
    String value, {
    bool isBoldRed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
