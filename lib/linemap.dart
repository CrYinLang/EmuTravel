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
  List<Map<String, dynamic>> _filteredStations = []; // 过滤后的站点（用于显示标签）
  List<Map<String, dynamic>> _fullRouteStations = []; // 完整路线站点（用于绘制连线）
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
      print('🚂 开始加载线路图数据...');

      // 1. 从API获取完整车站数据
      final fullStationsFromApi = await _fetchStationsFromApi(widget.journey.trainCode)
          .timeout(const Duration(seconds: 10));

      print('📊 完整API数据获取成功，共${fullStationsFromApi.length}个站点');
      _debugPrintStations('完整API站点', fullStationsFromApi);

      // 2. 过滤API数据，只保留journey.stations中存在的车站
      final filteredStations = _filterApiStations(fullStationsFromApi, widget.journey.stations);

      print('🎯 过滤后站点：${filteredStations.length}个');
      _debugPrintStations('过滤站点', filteredStations);

      // 3. 为完整路线和过滤站点分别匹配坐标
      print('🗺️ 开始匹配完整路线坐标...');
      final fullRouteWithLocation = await _matchStationsWithLocalData(fullStationsFromApi);

      print('📍 开始匹配过滤站点坐标...');
      final filteredWithLocation = await _matchStationsWithLocalData(filteredStations);

      // 调试坐标信息
      _debugPrintCoordinateInfo('完整路线坐标', fullRouteWithLocation);
      _debugPrintCoordinateInfo('过滤站点坐标', filteredWithLocation);

      // 4. 使用完整路线的坐标范围来计算所有站点的相对位置
      print('📐 计算相对位置...');
      final positionedFullRoute = _calculateRelativePositions(fullRouteWithLocation);
      final positionedFiltered = _calculatePositionsUsingFullRouteRange(
          filteredWithLocation,
          fullRouteWithLocation
      );

      // 调试相对位置
      _debugPrintRelativePositions('完整路线相对位置', positionedFullRoute);
      _debugPrintRelativePositions('过滤站点相对位置', positionedFiltered);

      setState(() {
        _fullRouteStations = positionedFullRoute;
        _filteredStations = positionedFiltered;
        _isLoading = false;
      });

      print('✅ 线路图加载完成');
      print('完整路线站点数: ${_fullRouteStations.length}');
      print('过滤站点数: ${_filteredStations.length}');

    } catch (e) {
      print('❌ 线路图加载失败: $e');
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _calculatePositionsUsingFullRouteRange(List<Map<String, dynamic>> targetStations,List<Map<String, dynamic>> fullRouteStations) {
    if (targetStations.isEmpty) return [];

    // 使用完整路线的有效站点来计算坐标范围
    final validFullStations = fullRouteStations.where((s) => s['hasLocation'] == true).toList();

    if (validFullStations.isEmpty) {
      print('⚠️ 完整路线无有效坐标，使用均匀分布');
      return _calculateEvenPositions(targetStations);
    }

    // 计算完整路线的坐标范围
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    double minLat = double.infinity;
    double maxLat = -double.infinity;

    for (final station in validFullStations) {
      final lng = station['longitude'] as double;
      final lat = station['latitude'] as double;

      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    print('🗺️ 完整路线坐标范围: 经度[$minLng~$maxLng] 纬度[$minLat~$maxLat]');

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

    print('📏 计算后范围: 经度[$finalMinLng~$finalMaxLng] 纬度[$finalMinLat~$finalMaxLat]');

    final List<Map<String, dynamic>> positionedStations = [];
    for (int i = 0; i < targetStations.length; i++) {
      final station = targetStations[i];
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

        print('📍 ${station['name']} - 原始坐标($lng,$lat) -> 相对坐标(${x.toStringAsFixed(3)},${y.toStringAsFixed(3)})');
      } else {
        // 对于无坐标的站点，使用线性插值
        x = 0.5;
        y = i / (targetStations.length - 1);
        print('⚠️ ${station['name']} - 无坐标，使用默认位置(${x.toStringAsFixed(3)},${y.toStringAsFixed(3)})');
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



  // 调试方法：打印站点信息
  void _debugPrintStations(String title, List<Map<String, dynamic>> stations) {
    print('--- $title ---');
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      final name = station['stationName'] ?? station['name'] ?? '未知';
      final hasLoc = station['hasLocation'] ?? false;
      print('$i. $name - 有坐标: $hasLoc');
    }
    print('----------------');
  }

  // 调试方法：打印坐标信息
  void _debugPrintCoordinateInfo(String title, List<Map<String, dynamic>> stations) {
    print('--- $title 坐标信息 ---');
    int validCount = 0;
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      final name = station['name'] ?? '未知';
      final hasLoc = station['hasLocation'] ?? false;
      if (hasLoc) {
        validCount++;
        final lng = station['longitude'] ?? 0;
        final lat = station['latitude'] ?? 0;
        print('$i. $name - 经度: $lng, 纬度: $lat');
      }
    }
    print('有效坐标站点: $validCount/${stations.length}');
    print('----------------------');
  }

  // 调试方法：打印相对位置
  void _debugPrintRelativePositions(String title, List<Map<String, dynamic>> stations) {
    print('--- $title 相对位置 ---');
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      final name = station['name'] ?? '未知';
      final x = station['relativeX'] ?? 0;
      final y = station['relativeY'] ?? 0;
      final hasLoc = station['hasLocation'] ?? false;
      print('$i. $name - X: ${x.toStringAsFixed(3)}, Y: ${y.toStringAsFixed(3)} - 有坐标: $hasLoc');
    }
    print('----------------------');
  }

  // 过滤API数据，只保留journey.stations中存在的车站
  List<Map<String, dynamic>> _filterApiStations(
      List<Map<String, dynamic>> apiStations,
      List<StationDetail> journeyStations
      ) {
    // 提取journey.stations中的车站名称（清理格式）
    final journeyStationNames = journeyStations.map((station) {
      return station.stationName.replaceAll('站', '').trim();
    }).toList();

    print('🎯 开始过滤API站点，目标站点: $journeyStationNames');

    // 过滤API数据
    final filtered = apiStations.where((apiStation) {
      final apiStationName = (apiStation['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      final isInJourney = journeyStationNames.contains(apiStationName);

      if (isInJourney) {
        print('✅ 匹配到站点: $apiStationName');
      }

      return isInJourney;
    }).toList();

    // 确保车站顺序与journey.stations一致
    filtered.sort((a, b) {
      final aName = (a['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      final bName = (b['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';

      final aIndex = journeyStationNames.indexOf(aName);
      final bIndex = journeyStationNames.indexOf(bName);

      return aIndex.compareTo(bIndex);
    });

    print('🎯 过滤完成，共找到${filtered.length}个匹配站点');
    return filtered;
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
      final jsonString = await rootBundle.loadString('assets/stations.json');
      final List<dynamic> allStations = json.decode(jsonString);

      final List<Map<String, dynamic>> matchedStations = [];

      for (final apiStation in apiStations) {
        final stationName = apiStation['stationName']?.toString() ?? '未知车站';
        final cleanName = stationName.replaceAll('站', '').trim();

        dynamic matched;
        try {
          matched = allStations.firstWhere(
                (station) {
              final jsonName = station['name']?.toString() ?? '';
              final cleanJsonName = jsonName.replaceAll('站', '').trim();
              return cleanJsonName == cleanName;
            },
            orElse: () => null,
          );
        } catch (e) {
          matched = null;
        }

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
            // 保留API数据
            'railwayLineName': apiStation['railwayLineName'] ?? '未知线路',
            'distance': apiStation['distance'] ?? 0,
            'isViaStation': apiStation['isViaStation'] ?? true,
            'arrivalTime': apiStation['arrivalTime'],
            'departureTime': apiStation['departureTime'],
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
            // 保留API数据
            'railwayLineName': apiStation['railwayLineName'] ?? '未知线路',
            'distance': apiStation['distance'] ?? 0,
            'isViaStation': apiStation['isViaStation'] ?? true,
            'arrivalTime': apiStation['arrivalTime'],
            'departureTime': apiStation['departureTime'],
          });
        }
      }

      return matchedStations;
    } catch (e) {
      // 如果匹配失败，返回原始数据（无坐标）
      return apiStations.map((station) => {
        ...station,
        'name': station['stationName'] ?? '未知车站',
        'location': null,
        'city': '',
        'telecode': '',
        'longitude': 0,
        'latitude': 0,
        'hasLocation': false,
      }).toList();
    }
  }

  // 计算相对位置
  List<Map<String, dynamic>> _calculateRelativePositions(List<Map<String, dynamic>> stations) {
    if (stations.isEmpty) return [];

    final validStations = stations.where((s) => s['hasLocation'] == true).toList();

    if (validStations.isEmpty) {
      return _calculateEvenPositions(stations);
    }

    // ... 原有的计算逻辑保持不变 ...
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
        for (int i = 0; i < _filteredStations.length; i++) {
          if (i != clickedIndex && _isTooClose(i, clickedIndex, containerWidth, containerHeight)) {
            _stationLabelsVisible[i] = true;
          }
        }
      }
    });
  }

  // 检查两个站点是否距离过近
  bool _isTooClose(int index1, int index2, double containerWidth, double containerHeight) {
    final station1 = _filteredStations[index1];
    final station2 = _filteredStations[index2];

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
                  onTap: _handleBackgroundTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest.shortestSide;
                      final squareSize = Size(size, size);

                      return Stack(
                        children: [
                          // 透明背景层捕获点击事件
                          Container(
                            width: squareSize.width,
                            height: squareSize.height,
                            color: Colors.transparent,
                          ),

                          // 绘制完整路线连线（背景）
                          CustomPaint(
                            size: squareSize,
                            painter: _FullRouteLinePainter(_fullRouteStations),
                          ),

                          // 绘制过滤站点连线（高亮）
                          CustomPaint(
                            size: squareSize,
                            painter: _FilteredRouteLinePainter(_filteredStations),
                          ),

                          // 过滤站点标记点
                          ..._buildStationMarkers(squareSize.width, squareSize.height),

                          // 过滤站点标签
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
    return _filteredStations.map((station) {
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
          behavior: HitTestBehavior.opaque,
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
    return _filteredStations.map((station) {
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

      // 智能计算标签位置
      final labelPosition = _calculateLabelPosition(
          index, pixelX, pixelY, containerWidth, containerHeight
      );

      return Positioned(
        left: labelPosition.dx,
        top: labelPosition.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
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

// 完整路线连线绘制器（背景灰色线条）
class _FullRouteLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stations;

  _FullRouteLinePainter(this.stations);

  @override
  void paint(Canvas canvas, Size size) {
    final validStations = stations.where((s) => s['hasLocation'] == true).toList();
    if (validStations.length < 2) return;

    final paint = Paint()
      ..color = Colors.grey.shade300  // 灰色背景线条
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 过滤路线连线绘制器（高亮蓝色线条）
class _FilteredRouteLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stations;

  _FilteredRouteLinePainter(this.stations);

  @override
  void paint(Canvas canvas, Size size) {
    final validStations = stations.where((s) => s['hasLocation'] == true).toList();
    if (validStations.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade600  // 高亮蓝色线条
      ..strokeWidth = 3
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}