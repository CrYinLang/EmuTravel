// linemap.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            // 线路图信息摘要
            _buildRouteSummary(context, journey),
            const SizedBox(height: 16),
            // 线路图内容
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
            Icon(Icons.train, color: Theme.of(context).primaryColor),
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
  List<Map<String, dynamic>> _positionedStations = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRouteMapData();
  }

  Future<void> _loadRouteMapData() async {
    try {
      final stationsWithLocation = await _loadStationsForRouteMap(widget.journey);
      final positionedStations = _calculateRelativePositions(stationsWithLocation);

      setState(() {
        _positionedStations = positionedStations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 加载站点位置数据
  Future<List<Map<String, dynamic>>> _loadStationsForRouteMap(Journey journey) async {
    try {
      final jsonString = await rootBundle.loadString('assets/stations.json');
      final List<dynamic> allStations = json.decode(jsonString);

      final journeyStationNames = journey.stations.map((s) => s.stationName).toList();
      final List<Map<String, dynamic>> matchedStations = [];

      for (final stationName in journeyStationNames) {
        final cleanName = stationName.replaceAll('站', '').trim();

        final matched = allStations.firstWhere(
              (station) {
            final jsonName = station['name']?.toString() ?? '';
            final cleanJsonName = jsonName.replaceAll('站', '').trim();
            return cleanJsonName == cleanName;
          },
          orElse: () => null,
        );

        if (matched != null) {
          final location = matched['location']?.toString() ?? '';
          final coords = location.split(',');
          double longitude = 0;
          double latitude = 0;

          if (coords.length == 2) {
            longitude = double.tryParse(coords[0]) ?? 0;
            latitude = double.tryParse(coords[1]) ?? 0;
          }

          matchedStations.add({
            'name': stationName,
            'location': location,
            'city': matched['city'] ?? '',
            'telecode': matched['telecode'] ?? '',
            'longitude': longitude,
            'latitude': latitude,
            'hasLocation': location.isNotEmpty && coords.length == 2,
          });
        } else {
          matchedStations.add({
            'name': stationName,
            'location': null,
            'city': '',
            'telecode': '',
            'longitude': 0,
            'latitude': 0,
            'hasLocation': false,
          });
        }
      }

      return matchedStations;
    } catch (e) {
      throw Exception('加载站点位置数据失败: $e');
    }
  }

  // 修复相对位置计算
  List<Map<String, dynamic>> _calculateRelativePositions(List<Map<String, dynamic>> stations) {
    if (stations.isEmpty) return [];

    // 提取有位置数据的站点
    final validStations = stations.where((s) => s['hasLocation'] == true).toList();

    if (validStations.isEmpty) {
      // 如果没有有效位置数据，使用均匀分布
      return _calculateEvenPositions(stations);
    }

    // 计算所有有效站点的坐标范围
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

    // 添加边距
    final lngMargin = (maxLng - minLng) * 0.1;
    final latMargin = (maxLat - minLat) * 0.1;

    minLng -= lngMargin;
    maxLng += lngMargin;
    minLat -= latMargin;
    maxLat += latMargin;

    final lngRange = maxLng - minLng;
    final latRange = maxLat - minLat;

    print('坐标范围: 经度 $minLng ~ $maxLng, 纬度 $minLat ~ $maxLat');
    print('坐标范围差值: 经度 $lngRange, 纬度 $latRange');

    // 为所有站点计算相对位置
    final List<Map<String, dynamic>> positionedStations = [];
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      double x = 0.5;
      double y = 0.5;

      if (station['hasLocation'] == true) {
        final lng = station['longitude'] as double;
        final lat = station['latitude'] as double;

        // 修复相对位置计算
        if (lngRange > 0) {
          x = (lng - minLng) / lngRange;
        }
        if (latRange > 0) {
          y = 1.0 - (lat - minLat) / latRange; // 反转Y轴
        }

        // 确保在0-1范围内
        x = x.clamp(0.0, 1.0);
        y = y.clamp(0.0, 1.0);

        print('站点 ${station['name']}: 经度 $lng -> X $x, 纬度 $lat -> Y $y');
      } else {
        // 没有位置数据的站点均匀分布
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
        'relativeX': 0.5,
        'relativeY': i / (stations.length - 1),
        'index': i,
      };
    }).toList();
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

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 绘制连接线
          _buildRouteLines(),

          // 绘制站点标记
          ..._buildStationMarkers(),

          // 调试信息
          _buildDebugInfo(),
        ],
      ),
    );
  }

  // 构建路线连接线
  Widget _buildRouteLines() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _RouteLinePainter(_positionedStations),
        );
      },
    );
  }

  // 修复站点标记位置计算
  List<Widget> _buildStationMarkers() {
    return _positionedStations.map((station) {
      final x = station['relativeX'] as double;
      final y = station['relativeY'] as double;
      final index = station['index'] as int;
      final hasLocation = station['hasLocation'] as bool;
      final name = station['name'] as String;

      return LayoutBuilder(
        builder: (context, constraints) {
          // 修复：将相对位置转换为实际像素位置
          final pixelX = x * constraints.maxWidth;
          final pixelY = y * constraints.maxHeight;

          print('站点 $name: 相对位置($x, $y) -> 像素位置($pixelX, $pixelY) 容器大小: ${constraints.maxWidth}x${constraints.maxHeight}');

          return Positioned(
            left: pixelX - 8,  // 减去一半宽度居中
            top: pixelY - 8,   // 减去一半高度居中
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: hasLocation ? Colors.blue : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.3),
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
          );
        },
      );
    }).toList();
  }

  // 调试信息
  Widget _buildDebugInfo() {
    final validCount = _positionedStations.where((s) => s['hasLocation'] == true).length;

    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总站点: ${_positionedStations.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            Text('有效站点: $validCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
            if (_positionedStations.isNotEmpty)
              Text('样例相对位置: ${_positionedStations.first['relativeX']?.toStringAsFixed(3)}, ${_positionedStations.first['relativeY']?.toStringAsFixed(3)}',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// 路线绘制器
class _RouteLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stations;

  _RouteLinePainter(this.stations);

  @override
  void paint(Canvas canvas, Size size) {
    // 只连接有位置数据的站点
    final validStations = stations.where((s) => s['hasLocation'] == true).toList();
    if (validStations.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // 移动到第一个点
    final firstStation = validStations.first;
    final startX = (firstStation['relativeX'] as double) * size.width;
    final startY = (firstStation['relativeY'] as double) * size.height;
    path.moveTo(startX, startY);

    // 连接所有有效站点
    for (int i = 1; i < validStations.length; i++) {
      final station = validStations[i];
      final x = (station['relativeX'] as double) * size.width;
      final y = (station['relativeY'] as double) * size.height;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}