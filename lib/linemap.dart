// linemap.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import 'journey_model.dart';

class LineMapDialog extends StatelessWidget {
  final Journey journey;

  const LineMapDialog({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${journey.trainCode}次列车线路图'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRouteSummary(context, journey),
            Expanded(
              child: LineMapContent(journey: journey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSummary(BuildContext context, Journey journey) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.train, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${journey.trainCode}次 • ${journey.fromStation} → ${journey.toStation}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '全程${journey.getTotalDuration()} • ${journey.stations.length}个站点',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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
}

class LineMapContent extends StatefulWidget {
  final Journey journey;

  const LineMapContent({super.key, required this.journey});

  @override
  State<LineMapContent> createState() => _LineMapContentState();
}

class _LineMapContentState extends State<LineMapContent> {
  List<Map<String, dynamic>> _allPositionedStations = []; // 完整路线
  List<Map<String, dynamic>> _stopPositionedStations = []; // 经停站
  bool _isLoading = true;
  String _errorMessage = '';
  int? _selectedStationIndex;
  final Map<int, bool> _stationLabelsVisible = {};

  @override
  void initState() {
    super.initState();
    _loadRouteMapData();
  }

  Future<void> _loadRouteMapData() async {
    try {
      List<Map<String, dynamic>> allStations = []; // 完整路线数据
      List<Map<String, dynamic>> stopStations = []; // 经停站数据

      try {
        // 1. 从API获取完整车站数据
        final stationsFromApi = await _fetchStationsFromApi(widget.journey.trainCode)
            .timeout(const Duration(seconds: 10));

        allStations = stationsFromApi;

        // 2. 获取经停站数据（从journey.stations转换而来）
        stopStations = _convertJourneyStationsToApiFormat(widget.journey.stations);

      } catch (e) {
        // 如果API失败，使用journey.stations作为完整数据
        allStations = _convertJourneyStationsToApiFormat(widget.journey.stations);
        stopStations = allStations;
      }

      // 3. 为完整路线数据匹配坐标
      final allStationsWithLocation = await _matchStationsWithLocalData(allStations);

      // 4. 为经停站数据匹配坐标（确保有准确的坐标信息）
      final stopStationsWithLocation = await _matchStationsWithLocalData(stopStations);

      // 5. 计算相对位置
      final positionedAllStations = _calculateRelativePositions(allStationsWithLocation);
      final positionedStopStations = _calculateRelativePositions(stopStationsWithLocation);

      setState(() {
        _allPositionedStations = positionedAllStations; // 完整路线
        _stopPositionedStations = positionedStopStations; // 经停站
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  // 将journey.stations转换为API数据格式
  List<Map<String, dynamic>> _convertJourneyStationsToApiFormat(List<StationDetail> stations) {
    return stations.asMap().entries.map((entry) {
      final i = entry.key;
      final station = entry.value;

      return {
        'stationName': station.stationName,
        'railwayLineName': '未知线路',
        'distance': i * 100, // 模拟距离
        'isIntersection': false,
        'arrivalTime': station.arrivalTime,
        'departureTime': station.departureTime,
        'isViaStation': station.isOperatingStation,
      };
    }).toList();
  }

  // 从API获取车站数据
  Future<List<Map<String, dynamic>>> _fetchStationsFromApi(String trainNumber) async {
    try {
      final url = Uri.parse('https://rail.moefactory.com/api/trainDetails/queryTrainRoutes');

      final response = await http.post(
        url,
        body: {"trainNumber": trainNumber},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('API返回错误: ${data['message'] ?? '未知错误'}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 从本地JSON匹配车站坐标
  Future<List<Map<String, dynamic>>> _matchStationsWithLocalData(List<Map<String, dynamic>> apiStations) async {
    try {
      // 加载本地车站数据文件
      final jsonString = await rootBundle.loadString('assets/stations.json');
      final List<dynamic> allStations = json.decode(jsonString);

      // 存储匹配后的车站数据
      final List<Map<String, dynamic>> matchedStations = [];

      for (final apiStation in apiStations) {
        final stationName = apiStation['stationName']?.toString() ?? '未知车站';

        // 清洗车站名称：移除"站"字并去除空格
        String cleanName = stationName.replaceAll('站', '').trim();

        // 策略1：精确匹配
        dynamic matched = allStations.firstWhere(
              (station) {
            final jsonName = station['name']?.toString() ?? '';
            final cleanJsonName = jsonName.replaceAll('站', '').trim();
            return cleanJsonName == cleanName;
          },
          orElse: () => null,
        );

        if (matched != null) {
          // 从匹配的本地数据中提取坐标信息
          final location = matched['location']?.toString() ?? '';
          final coords = location.split(',');
          double longitude = 0;
          double latitude = 0;

          if (coords.length == 2) {
            longitude = double.tryParse(coords[0]) ?? 0;
            latitude = double.tryParse(coords[1]) ?? 0;
          }

          // 构建匹配成功的车站数据
          matchedStations.add({
            'name': stationName,
            'location': location,
            'city': matched['city'] ?? '',
            'telecode': matched['telecode'] ?? '',
            'longitude': longitude,
            'latitude': latitude,
            'hasLocation': location.isNotEmpty && coords.length == 2,
            'railwayLineName': apiStation['railwayLineName'] ?? '未知线路',
            'distance': apiStation['distance'] ?? 0,
            'isViaStation': apiStation['isViaStation'] ?? true,
            'arrivalTime': apiStation['arrivalTime'],
            'departureTime': apiStation['departureTime'],
          });
        } else {
          // 如果本地没有匹配到车站，使用模拟坐标基于距离计算
          final totalDistance = apiStations.last['distance'] as int? ?? 1;
          final currentDistance = apiStation['distance'] as int? ?? 0;
          final progress = currentDistance / totalDistance;

          // 南宁到广州大致方向：从西向东
          final baseLng = 108.3; // 南宁经度
          final baseLat = 22.8;  // 南宁纬度
          final targetLng = 113.3; // 广州经度
          final targetLat = 23.1;  // 广州纬度

          // 构建模拟坐标的车站数据
          matchedStations.add({
            'name': stationName,
            'location': null,
            'city': '',
            'telecode': '',
            'longitude': baseLng + (targetLng - baseLng) * progress,
            'latitude': baseLat + (targetLat - baseLat) * progress,
            'hasLocation': true, // 标记为有坐标
            'railwayLineName': apiStation['railwayLineName'] ?? '未知线路',
            'distance': apiStation['distance'] ?? 0,
            'isViaStation': apiStation['isViaStation'] ?? true,
            'arrivalTime': apiStation['arrivalTime'],
            'departureTime': apiStation['departureTime'],
          });
        }
      }

      // 返回匹配完成的车站列表
      return matchedStations;

    } catch (e) {
      return [];
    }
  }

  // 计算相对位置
  List<Map<String, dynamic>> _calculateRelativePositions(List<Map<String, dynamic>> stations) {
    if (stations.isEmpty) return [];

    final validStations = stations.where((s) => s['hasLocation'] == true).toList();

    if (validStations.isEmpty) {
      return _calculateEvenPositions(stations);
    }

    double minLng = double.infinity;
    double maxLng = -double.infinity;
    double minLat = double.infinity;
    double maxLat = -double.infinity;

    for (final station in validStations) {
      final lng = station['longitude'] as double;
      final lat = station['latitude'] as double;

      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    final lngRange = maxLng - minLng;
    final latRange = maxLat - minLat;

    final targetAspectRatio = 1.8;
    final currentAspectRatio = lngRange / latRange;
    double adjustedLngRange = lngRange;
    double adjustedLatRange = latRange;

    if (currentAspectRatio > targetAspectRatio) {
      adjustedLatRange = lngRange / targetAspectRatio;
    } else {
      adjustedLngRange = latRange * targetAspectRatio;
    }

    final lngCenter = (minLng + maxLng) / 2;
    final latCenter = (minLat + maxLat) / 2;

    final adjustedMinLng = lngCenter - adjustedLngRange / 2;
    final adjustedMaxLng = lngCenter + adjustedLngRange / 2;
    final adjustedMinLat = latCenter - adjustedLatRange / 2;
    final adjustedMaxLat = latCenter + adjustedLatRange / 2;

    final lngMargin = adjustedLngRange * 0.1;
    final latMargin = adjustedLatRange * 0.1;

    final finalMinLng = adjustedMinLng - lngMargin;
    final finalMaxLng = adjustedMaxLng + lngMargin;
    final finalMinLat = adjustedMinLat - latMargin;
    final finalMaxLat = adjustedMaxLat + latMargin;

    final finalLngRange = finalMaxLng - finalMinLng;
    final finalLatRange = finalMaxLat - finalMinLat;

    final List<Map<String, dynamic>> positionedStations = [];
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      double x = 0.5;
      double y = 0.5;

      if (station['hasLocation'] == true) {
        final lng = station['longitude'] as double;
        final lat = station['latitude'] as double;

        if (finalLngRange > 0) {
          x = (lng - finalMinLng) / finalLngRange;
        }
        if (finalLatRange > 0) {
          y = 1.0 - (lat - finalMinLat) / finalLatRange;
        }

        x = x.clamp(0.0, 1.0);
        y = y.clamp(0.0, 1.0);
      } else {
        x = 0.5;
        y = i / (stations.length - 1);
      }

      positionedStations.add({
        ...station,
        'relativeX': x,
        'relativeY': y,
        'index': i,
      });
    }

    return positionedStations;
  }

  // 均匀分布计算
  List<Map<String, dynamic>> _calculateEvenPositions(List<Map<String, dynamic>> stations) {
    return stations.asMap().entries.map((entry) {
      final i = entry.key;
      final station = entry.value;

      return {
        ...station,
        'relativeX': 0.1 + 0.8 * (i / (stations.length - 1)),
        'relativeY': 0.5,
        'index': i,
      };
    }).toList();
  }

  // 处理空白处点击
  void _handleBackgroundTap() {
    setState(() {
      // 隐藏所有标签
      _stationLabelsVisible.clear();
      _selectedStationIndex = null;
    });
  }

  // 自动管理标签显示
  void _autoManageLabels(int clickedIndex, double containerWidth, double containerHeight) {
    setState(() {
      // 如果点击的是当前已选中的站点，则隐藏标签
      if (_selectedStationIndex == clickedIndex) {
        _stationLabelsVisible.clear();
        _selectedStationIndex = null;
      } else {
        // 隐藏所有标签
        _stationLabelsVisible.clear();

        // 显示点击的站点标签
        _stationLabelsVisible[clickedIndex] = true;
        _selectedStationIndex = clickedIndex;

        // 检查附近站点，如果距离过近也显示
        for (int i = 0; i < _stopPositionedStations.length; i++) {
          if (i != clickedIndex && _isTooClose(i, clickedIndex, containerWidth, containerHeight)) {
            _stationLabelsVisible[i] = true;
          }
        }
      }
    });
  }

  // 检查两个站点是否距离过近
  bool _isTooClose(int index1, int index2, double containerWidth, double containerHeight) {
    final station1 = _stopPositionedStations[index1];
    final station2 = _stopPositionedStations[index2];

    final x1 = (station1['relativeX'] as double) * containerWidth;
    final y1 = (station1['relativeY'] as double) * containerHeight;
    final x2 = (station2['relativeX'] as double) * containerWidth;
    final y2 = (station2['relativeY'] as double) * containerHeight;

    final distance = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

    // 根据标签大小调整距离阈值
    return distance < 10;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载线路图...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRouteMapData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 400,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: _handleBackgroundTap, // 添加空白处点击事件
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest.shortestSide;
                      final squareSize = Size(size, size);

                      return Stack(
                        children: [
                          // 添加一个透明的背景层来捕获点击事件
                          Container(
                            width: squareSize.width,
                            height: squareSize.height,
                            color: Colors.transparent,
                          ),

                          CustomPaint(
                            size: squareSize,
                            painter: _RouteLinePainter(
                              allStations: _allPositionedStations,
                              stopStations: _stopPositionedStations,
                            ),
                          ),
                          ..._buildStationMarkers(squareSize.width, squareSize.height),
                          ..._buildStationLabels(squareSize.width, squareSize.height),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStationMarkers(double containerWidth, double containerHeight) {
    return _stopPositionedStations.map((station) {
      final x = station['relativeX'] as double;
      final y = station['relativeY'] as double;
      final index = station['index'] as int;
      final isViaStation = station['isViaStation'] as bool? ?? true;

      final pixelX = x * containerWidth;
      final pixelY = y * containerHeight;

      return Positioned(
        left: pixelX - 8,
        top: pixelY - 8,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // 阻止事件穿透
          onTap: () => _autoManageLabels(index, containerWidth, containerHeight),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isViaStation ? Colors.blue : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildStationLabels(double containerWidth, double containerHeight) {
    return _stopPositionedStations.map((station) {
      final x = station['relativeX'] as double;
      final y = station['relativeY'] as double;
      final index = station['index'] as int;
      final name = station['name'] as String;
      final hasLocation = station['hasLocation'] as bool? ?? false;
      final city = station['city'] as String;
      final arrivalTime = station['arrivalTime'];
      final departureTime = station['departureTime'];
      final isViaStation = station['isViaStation'] as bool? ?? true;

      // 只显示被选中的标签或距离过近的标签
      final isVisible = _stationLabelsVisible[index] ?? false;
      if (!isVisible) {
        return const SizedBox.shrink();
      }

      final pixelX = x * containerWidth;
      final pixelY = y * containerHeight;

      // 智能计算标签位置，避免重叠和超出边界
      final labelPosition = _calculateLabelPosition(
          index, pixelX, pixelY, containerWidth, containerHeight
      );

      return Positioned(
        left: labelPosition.dx,
        top: labelPosition.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // 阻止事件穿透
          onTap: () {
            // 点击标签时也触发站点点击逻辑
            _autoManageLabels(index, containerWidth, containerHeight);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(242),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 10,
                        color: hasLocation ? Colors.black : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!hasLocation) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber, size: 8, color: Colors.orange),
                    ],
                  ],
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    city,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                    ),
                  ),
                ],
                if (arrivalTime != null || departureTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${arrivalTime ?? ''} - ${departureTime ?? ''}',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.blue,
                    ),
                  ),
                ],
                if (!isViaStation) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '经停站',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // 计算标签位置
  Offset _calculateLabelPosition(int index, double pixelX, double pixelY,
      double containerWidth, double containerHeight) {
    const labelWidth = 80.0;
    const labelHeight = 40.0;
    const margin = 8.0;

    // 定义位置优先级：右 > 左 > 上 > 下
    final List<Offset> positions = [
      // 右侧
      Offset(pixelX + margin, pixelY - labelHeight / 2),
      // 左侧
      Offset(pixelX - labelWidth - margin, pixelY - labelHeight / 2),
      // 上方
      Offset(pixelX - labelWidth / 2, pixelY - labelHeight - margin),
      // 下方
      Offset(pixelX - labelWidth / 2, pixelY + margin),
    ];

    // 按优先级检查位置是否合适
    for (final position in positions) {
      if (position.dx >= 0 &&
          position.dx + labelWidth <= containerWidth &&
          position.dy >= 0 &&
          position.dy + labelHeight <= containerHeight) {
        return position;
      }
    }

    // 如果所有位置都不合适，强制显示在右侧，但调整到边界内
    double x = pixelX + margin;
    double y = pixelY - labelHeight / 2;

    // 确保在边界内
    x = x.clamp(margin, containerWidth - labelWidth - margin);
    y = y.clamp(margin, containerHeight - labelHeight - margin);

    return Offset(x, y);
  }
}

class _RouteLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> allStations; // 完整路线
  final List<Map<String, dynamic>> stopStations; // 经停站

  _RouteLinePainter({
    required this.allStations,
    required this.stopStations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制完整路线连线
    _drawCompleteRoute(canvas, size);

    // 2. 绘制所有车站的小圆点
    _drawAllStationDots(canvas, size);

    // 3. 绘制经停站的大圆点
    _drawStopStationMarkers(canvas, size);
  }

  void _drawCompleteRoute(Canvas canvas, Size size) {
    final validStations = allStations.where((s) => s['hasLocation'] == true).toList();
    if (validStations.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade300.withValues(alpha:0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    final firstStation = validStations.first;
    final startX = (firstStation['relativeX'] as double) * size.width;
    final startY = (firstStation['relativeY'] as double) * size.height;
    path.moveTo(startX, startY);

    for (int i = 1; i < validStations.length; i++) {
      final station = validStations[i];
      final x = (station['relativeX'] as double) * size.width;
      final y = (station['relativeY'] as double) * size.height;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  void _drawAllStationDots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha:0.5)
      ..style = PaintingStyle.fill;

    for (final station in allStations) {
      final x = (station['relativeX'] as double) * size.width;
      final y = (station['relativeY'] as double) * size.height;

      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  void _drawStopStationMarkers(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final station in stopStations) {
      final x = (station['relativeX'] as double) * size.width;
      final y = (station['relativeY'] as double) * size.height;

      // 绘制大圆点
      canvas.drawCircle(Offset(x, y), 4, fillPaint);
      canvas.drawCircle(Offset(x, y), 4, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}