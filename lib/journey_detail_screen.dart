// journey_detail_screen.dart

import 'package:flutter/material.dart';
import 'journey_model.dart';
// import 'linemap.dart'; // 暂时注释掉，直到修复 LineMapWidget

class JourneyDetailScreen extends StatefulWidget {
  final Journey journey;

  const JourneyDetailScreen({super.key, required this.journey});

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  String? _selectedDepartureCode;
  String? _selectedArrivalCode;

  @override
  void initState() {
    super.initState();
    // 初始化逻辑需要根据实际的 Journey 类结构调整
    // 暂时注释掉不存在的属性
    // _selectedDepartureCode = widget.journey.boardingStationCode;
    // _selectedArrivalCode = widget.journey.alightingStationCode;
  }

  // 解析时间字符串
  DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return DateTime(0, 0, 0, int.parse(parts[0]), int.parse(parts[1]));
      }
    } catch (e) {
      // 忽略解析错误
    }
    return null;
  }

  // 获取区间站点数量
  int _getIntervalStationCount() {
    if (_selectedDepartureCode == null || _selectedArrivalCode == null) {
      return 0;
    }

    int startIdx = -1;
    int endIdx = -1;

    for (int i = 0; i < widget.journey.stations.length; i++) {
      // 修复：使用正确的属性访问方式
      final station = widget.journey.stations[i];
      if (_getStationCode(station) == _selectedDepartureCode) {
        startIdx = i;
      }
      if (_getStationCode(station) == _selectedArrivalCode) {
        endIdx = i;
      }
    }

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return endIdx - startIdx + 1;
    }

    return 0;
  }

  // 获取区间时长
  String _getIntervalDuration() {
    if (_selectedDepartureCode == null || _selectedArrivalCode == null) {
      return '--';
    }

    dynamic depStation;
    dynamic arrStation;

    for (var station in widget.journey.stations) {
      if (_getStationCode(station) == _selectedDepartureCode) {
        depStation = station;
      }
      if (_getStationCode(station) == _selectedArrivalCode) {
        arrStation = station;
      }
    }

    if (depStation == null || arrStation == null) {
      return '--';
    }

    final depTimeStr = _getStationDepartureTime(depStation) ?? _getStationArrivalTime(depStation);
    final arrTimeStr = _getStationArrivalTime(arrStation) ?? _getStationDepartureTime(arrStation);

    if (depTimeStr == null || arrTimeStr == null) {
      return '--';
    }

    final depTime = _parseTime(depTimeStr);
    final arrTime = _parseTime(arrTimeStr);

    if (depTime == null || arrTime == null) {
      return '--';
    }

    Duration duration;
    int dayOffset = 0;

    if (arrTime.hour < depTime.hour ||
        (arrTime.hour == depTime.hour && arrTime.minute < depTime.minute)) {
      duration = Duration(
        hours: (24 - depTime.hour) + arrTime.hour,
        minutes: arrTime.minute - depTime.minute,
      );
      dayOffset = 1;
    } else {
      duration = arrTime.difference(depTime);
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (dayOffset > 0) {
      return '跨${dayOffset}天 ${hours}h${minutes}m';
    }
    return '${hours}h${minutes}m';
  }

  // 辅助方法：安全获取站点属性
  String? _getStationCode(dynamic station) {
    if (station is Map<String, dynamic>) {
      return station['code']?.toString();
    }
    // 如果是 StationDetail 对象，使用点号访问
    return null; // 需要根据实际 StationDetail 类结构实现
  }

  String? _getStationName(dynamic station) {
    if (station is Map<String, dynamic>) {
      return station['name']?.toString();
    }
    return null;
  }

  String? _getStationDepartureTime(dynamic station) {
    if (station is Map<String, dynamic>) {
      return station['departure_time']?.toString();
    }
    return null;
  }

  String? _getStationArrivalTime(dynamic station) {
    if (station is Map<String, dynamic>) {
      return station['arrival_time']?.toString();
    }
    return null;
  }

  // 获取上车站点信息
  Map<String, dynamic>? _getDepartureStation() {
    if (_selectedDepartureCode == null) return null;

    for (var station in widget.journey.stations) {
      if (_getStationCode(station) == _selectedDepartureCode) {
        // 返回 Map 格式的数据
        return {
          'code': _getStationCode(station),
          'name': _getStationName(station),
          'departure_time': _getStationDepartureTime(station),
          'arrival_time': _getStationArrivalTime(station),
        };
      }
    }
    return null;
  }

  // 获取下车站点信息
  Map<String, dynamic>? _getArrivalStation() {
    if (_selectedArrivalCode == null) return null;

    for (var station in widget.journey.stations) {
      if (_getStationCode(station) == _selectedArrivalCode) {
        return {
          'code': _getStationCode(station),
          'name': _getStationName(station),
          'departure_time': _getStationDepartureTime(station),
          'arrival_time': _getStationArrivalTime(station),
        };
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;

    return Scaffold(
      appBar: AppBar(
        title: Text(journey.trainCode), // 修复：trainNumber → trainCode
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 列车信息卡片
            _buildTrainInfoCard(),
            const SizedBox(height: 16),

            // 站点选择区域
            _buildStationSelectionCard(),
            const SizedBox(height: 16),

            // 线路图
            _buildLineMapCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainInfoCard() {
    final journey = widget.journey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  journey.trainCode, // 修复：trainNumber → trainCode
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 移除 trainType 相关代码，因为 Journey 类没有这个属性
                /*
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    journey.trainType,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                */
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journey.fromStation, // 修复：startStation → fromStation
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        journey.departureTime,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        journey.toStation, // 修复：endStation → toStation
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        journey.arrivalTime,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '全程: ${journey.getTotalDuration()}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '全程${journey.stations.length}站',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Text(
                    '乘车日期: ${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelectionCard() {
    final depStation = _getDepartureStation();
    final arrStation = _getArrivalStation();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '上下车站点',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 上车站
            InkWell(
              onTap: () => _showStationSelector(context, true),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.login, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '上车站',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            depStation?['name'] ?? '请选择',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (depStation != null)
                            Text(
                              '发车: ${depStation['departure_time'] ?? depStation['arrival_time']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 下车站
            InkWell(
              onTap: () => _showStationSelector(context, false),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '下车站',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            arrStation?['name'] ?? '请选择',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (arrStation != null)
                            Text(
                              '到达: ${arrStation['arrival_time'] ?? arrStation['departure_time']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

            // 区间信息
            if (_selectedDepartureCode != null && _selectedArrivalCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '区间时长',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getIntervalDuration(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      Column(
                        children: [
                          Text(
                            '区间站点',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_getIntervalStationCount()}站', // 修复字符串插值
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineMapCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '线路图',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              // 暂时注释掉 LineMapWidget，先修复其他错误
              child: Container(
                alignment: Alignment.center,
                child: const Text('线路图功能暂不可用'),
              ),
              /*
              child: LineMapWidget(
                stations: widget.journey.stations,
                selectedDepartureCode: _selectedDepartureCode,
                selectedArrivalCode: _selectedArrivalCode,
                onStationTap: (code, isDeparture) {
                  setState(() {
                    if (isDeparture) {
                      _selectedDepartureCode = code;
                    } else {
                      _selectedArrivalCode = code;
                    }
                  });
                },
              ),
              */
            ),
          ],
        ),
      ),
    );
  }

  void _showStationSelector(BuildContext context, bool isDeparture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StationSelectorModal(
          stations: widget.journey.stations,
          selectedCode: isDeparture ? _selectedDepartureCode : _selectedArrivalCode,
          title: isDeparture ? '选择上车站' : '选择下车站',
        ),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          if (isDeparture) {
            _selectedDepartureCode = result['code'];
          } else {
            _selectedArrivalCode = result['code'];
          }
        });
      }
    });
  }

  void _showInfoDialog(BuildContext context) {
    final journey = widget.journey;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('行程详细信息'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogInfoRow('车次', journey.trainCode), // 修复：trainNumber → trainCode
                // _buildDialogInfoRow('类型', journey.trainType), // 注释掉，trainType 未定义
                _buildDialogInfoRow('始发站', journey.fromStation), // 修复：startStation → fromStation
                _buildDialogInfoRow('终点站', journey.toStation), // 修复：endStation → toStation
                _buildDialogInfoRow('全程时长', journey.getTotalDuration()),
                _buildDialogInfoRow(
                  '乘车日期',
                  '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                  isBoldRed: true,
                ),
                _buildDialogInfoRow('列车时间', '${journey.departureTime}->${journey.arrivalTime}'),
                _buildDialogInfoRow('站点数量', '区间${_getIntervalStationCount()}个 / 全程${journey.stations.length}个'),
                // 移除未定义的属性引用
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

// 站点选择器模态框组件
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
            final name = _getStationName(s)?.toLowerCase() ?? '';
            // 暂时注释掉其他搜索条件，先确保基本功能
            return name.contains(query);
          }).toList(),
        );
      }
    });
  }

  String? _getStationName(dynamic station) {
    if (station is Map<String, dynamic>) {
      return station['name']?.toString();
    }
    return null;
  }

  String? _getStationCode(dynamic station) {
    if (station is Map<String, dynamic>) {
      return station['code']?.toString();
    }
    return null;
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
              hintText: '搜索车站名称',
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
                final station = _filtered[index];
                final code = _getStationCode(station) ?? '';
                final name = _getStationName(station) ?? '';
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
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.of(context).pop({
                    'code': code,
                    'name': name,
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