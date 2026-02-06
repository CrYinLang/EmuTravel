// journey.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'home_screen.dart';
import 'main.dart';

class AddJourneyPage extends StatefulWidget {
  const AddJourneyPage({super.key});

  @override
  State<AddJourneyPage> createState() => _AddJourneyPageState();
}

class _AddJourneyPageState extends State<AddJourneyPage>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  final _trainNumberCtrl = TextEditingController();
  bool _loading = false;
  List<dynamic> _trainResults = [];
  int? _expandedIndex;
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  String? _fromCode, _toCode;
  String? _fromName = '请选择', _toName = '请选择';
  List<dynamic> _allStations = [];
  bool _loadingStations = false;
  List<dynamic> _stationResults = [];
  int? _stationExpandedIndex;
  final Map<int, List<dynamic>> _stationDetails = {};
  final Map<int, bool> _stationLoading = {};
  int _searchMode = 0;
  final Map<int, List<dynamic>> _trainDetails = {};
  final Map<int, bool> _trainLoading = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _loadStations();
    _trainNumberCtrl.addListener(() {
      final text = _trainNumberCtrl.text;
      if (text.isNotEmpty && text != text.toUpperCase()) _formatInput(text);
    });
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = today.add(const Duration(days: 1));
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final jsonString = await rootBundle.loadString('assets/stations.json');
      setState(() => _allStations = json.decode(jsonString));
    } catch (e) {
      _showSnack('加载站点数据失败: $e');
    } finally {
      setState(() => _loadingStations = false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _trainNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daytwo = today.add(const Duration(days: -2));
    final tomorrow = today.add(const Duration(days: 1));
    final maxDate = today.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? tomorrow,
      firstDate: daytwo,
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _expandedIndex = null;
        _stationExpandedIndex = null;
        _trainDetails.clear();
        _trainLoading.clear();
        _stationDetails.clear();
        _stationLoading.clear();
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
    }
  }

  String get dateText => _selectedDate == null
      ? "选择日期"
      : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

  String get _formattedDate => _selectedDate == null
      ? ""
      : "${_selectedDate!.year}${_selectedDate!.month.toString().padLeft(2, '0')}${_selectedDate!.day.toString().padLeft(2, '0')}";

  void _formatInput(String value) {
    if (value.isEmpty) return;
    String uppercase = value.toUpperCase();
    const allowed = 'GDCSKZTWPQ';
    String result = '';
    for (int i = 0; i < uppercase.length; i++) {
      String char = uppercase[i];
      if (i == 0) {
        if (RegExp(r'[0-9]').hasMatch(char) || allowed.contains(char)) {
          result += char;
        }
      } else {
        if (RegExp(r'[0-9]').hasMatch(char)) result += char;
      }
    }
    if (result != _trainNumberCtrl.text) {
      _trainNumberCtrl.value = _trainNumberCtrl.value.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  void _switchMode(int mode) {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode = mode;
      _expandedIndex = null;
      _stationExpandedIndex = null;
      _trainDetails.clear();
      _trainLoading.clear();
      _stationDetails.clear();
      _stationLoading.clear();
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });
  }

  Future<void> _searchTrain() async {
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }
    final trainNumber = _trainNumberCtrl.text.trim();
    if (trainNumber.isEmpty) {
      _showSnack('请输入车次');
      return;
    }
    setState(() {
      _loading = true;
      _trainResults.clear();
      _trainDetails.clear();
      _trainLoading.clear();
      _expandedIndex = null;
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });
    try {
      final url =
          'https://search.12306.cn/search/v1/train/search?keyword=$trainNumber&date=$_formattedDate';
      // final url =
      //     'http://10.166.135.96:8888/code';
      final response = await http.get(
        Uri.parse(url),
        headers: Vars.normalHeaders,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final allResults = data['data'] ?? [];
          final limitedResults = allResults.length > 15
              ? allResults.sublist(0, 15)
              : allResults;

          setState(() => _trainResults = limitedResults);
          _showSnack(
            _trainResults.isEmpty
                ? '未找到相关车次信息'
                : '找到 ${_trainResults.length} 条结果',
          );
        } else {
          _showSnack('搜索失败: ${data['errorMsg']}');
        }
      } else {
        _showSnack('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('发生错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _searchStation() async {
    if (_selectedDate == null) {
      _showSnack('请先选择日期');
      return;
    }
    if (_fromCode == null || _toCode == null) {
      _showSnack('请选择起始站和终点站');
      return;
    }
    setState(() {
      _loading = true;
      _stationResults.clear();
      _stationDetails.clear();
      _stationLoading.clear();
      _stationExpandedIndex = null;
      if (_animCtrl.isAnimating) _animCtrl.reset();
    });
    try {
      final url =
          'https://search.12306.cn/search/v1/train/search?from_station=$_fromCode&to_station=$_toCode&date=$_formattedDate';
      final response = await http.get(
        Uri.parse(url),
        headers: Vars.normalHeaders,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() => _stationResults = data['data'] ?? []);
          _showSnack(
            _stationResults.isEmpty
                ? '未找到相关车次信息'
                : '找到 ${_stationResults.length} 条结果',
          );
        } else {
          _showSnack('搜索失败: ${data['errorMsg']}');
        }
      } else {
        _showSnack('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('发生错误: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchDetails(int index, bool isStation) async {
    if (isStation) {
      if (_stationDetails.containsKey(index)) return;
      final trainInfo = _stationResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isEmpty) return;
      setState(() => _stationLoading[index] = true);
      try {
        final stopData = await _fetchStopInfo(trainNumber);
        setState(() {
          _stationDetails[index] = stopData;
          _stationLoading[index] = false;
        });
      } catch (e) {
        debugPrint('获取停站信息失败: $e');
        _showSnack('获取停站信息失败: $e');
        setState(() => _stationLoading[index] = false);
      }
    } else {
      if (_trainDetails.containsKey(index)) return;
      final trainInfo = _trainResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isEmpty) return;
      setState(() => _trainLoading[index] = true);
      try {
        final stopData = await _fetchStopInfo(trainNumber);
        setState(() {
          _trainDetails[index] = stopData;
          _trainLoading[index] = false;
        });
      } catch (e) {
        debugPrint('获取停站信息失败: $e');
        _showSnack('获取停站信息失败: $e');
        setState(() => _trainLoading[index] = false);
      }
    }
  }

  Future<List<dynamic>> _fetchStopInfo(String trainNumber) async {
    // final url = Uri.parse(
    //   'http://10.166.135.96:8888/stop',
    // );
    final url = Uri.parse(
      'https://m.ctrip.com/restapi/soa2/14674/json/GetTrainStopTimeInfo',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://m.ctrip.com/',
      'Origin': 'https://m.ctrip.com',
    };
    final body = {'TrainNumber': trainNumber, 'DepartDate': _formattedDate};
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['RetCode'] == 1 && data['StopList'] != null) {
          final List<dynamic> stopList = data['StopList'];
          return stopList
              .map(
                (stop) => {
                  'stationNo': stop['StationNo'] ?? '',
                  'stationName': stop['StationName'] ?? '',
                  'arriveTime': stop['ArriveTime'] ?? '--:--',
                  'departTime': stop['DepartTime'] ?? '--:--',
                  'stayTime': stop['StayWayStationTime'] ?? '0',
                  'DayDifference': stop['DayDifference'] ?? 0,
                  'telCode': stop['TelCode'] ?? '',
                  'isFirst': stop['StationNo'] == '01',
                  'isLast': stop['StationNo'] == stopList.length.toString().padLeft(2, '0'),
                },
              )
              .toList();
        } else if (data['RetCode'] != 1) {
          throw Exception(
            'API返回失败: RetCode=${data['RetCode']}, Ack=${data['ResponseStatus']?['Ack']}',
          );
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取停站信息错误: $e');
      rethrow;
    }
  }

  Future<void> _showStationSelector(bool isFrom) async {
    if (_loadingStations) {
      _showSnack('正在加载站点数据...');
      return;
    }
    if (_allStations.isEmpty) {
      _showSnack('站点数据为空，请稍后重试');
      return;
    }
    String? selectedCode = isFrom ? _fromCode : _toCode;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StationSelectorModal(
        stations: _allStations,
        selectedCode: selectedCode,
        title: isFrom ? '选择出发站' : '选择到达站',
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromCode = result['code'];
          _fromName = result['name'];
        } else {
          _toCode = result['code'];
          _toName = result['name'];
        }
      });
    }
  }

  void _toggleExpand(int index, bool isStation) async {
    if (isStation) {
      if (_stationExpandedIndex == index) {
        _animCtrl.reverse().then((_) {
          if (mounted) {
            setState(() => _stationExpandedIndex = null);
          }
        });
      } else {
        setState(() => _stationExpandedIndex = index);
        _animCtrl.forward();
        await _fetchDetails(index, true);
      }
    } else {
      if (_expandedIndex == index) {
        _animCtrl.reverse().then((_) {
          if (mounted) {
            setState(() => _expandedIndex = null);
          }
        });
      } else {
        setState(() => _expandedIndex = index);
        _animCtrl.forward();
        await _fetchDetails(index, false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _clearResults() {
    if (_searchMode == 0) {
      setState(() {
        _trainResults.clear();
        _trainDetails.clear();
        _trainLoading.clear();
        _expandedIndex = null;
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
      _trainNumberCtrl.clear();
      _showSnack('已清除车次搜索结果');
    } else {
      setState(() {
        _stationResults.clear();
        _stationDetails.clear();
        _stationLoading.clear();
        _stationExpandedIndex = null;
        if (_animCtrl.isAnimating) _animCtrl.reset();
      });
      _showSnack('已清除站点搜索结果');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加旅途'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if ((_searchMode == 0 && _trainResults.isNotEmpty) ||
              (_searchMode == 1 && _stationResults.isNotEmpty))
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearResults,
              tooltip: '清除搜索结果',
            ),
        ],
      ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 日期选择器 - 使用主题色边框
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dateText,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _selectedDate == null
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SegmentedButton - 保持原样
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text(
                          '车次查询',
                          style: TextStyle(fontSize: 16),
                        ),
                        icon: Icon(Icons.train, size: 20),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(
                          '车站查询',
                          style: TextStyle(fontSize: 16),
                        ),
                        icon: Icon(Icons.location_on, size: 20),
                      ),
                    ],
                    selected: {_searchMode},
                    onSelectionChanged: (Set<int> s) => _switchMode(s.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                      selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_searchMode == 0) ...[
                  // 车次输入框 - 使用主题色
                  SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _trainNumberCtrl,
                      onChanged: (value) {
                        if (value.isNotEmpty) _formatInput(value);
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9GDCSKZTWPQgdcskztwpq1]'),
                        ),
                        TextInputFormatter.withFunction(
                              (oldValue, newValue) =>
                              newValue.copyWith(text: newValue.text.toUpperCase()),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: "请输入车次",
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 搜索按钮
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _searchTrain,
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
                          : Text(
                        '搜索车次',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 车次列表结果
                  _buildTrainList(),
                ],

                if (_searchMode == 1) ...[
                  // 车站选择器 - 使用主题色
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showStationSelector(true),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _fromCode != null
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
                                  color: _fromCode != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _fromName!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _fromCode != null
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showStationSelector(false),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _toCode != null
                                    ? Colors.red
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
                                  color: _toCode != null
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _toName!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _toCode != null
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 搜索按钮
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _searchStation,
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
                        '搜索站点间车次',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 车站列表结果
                  _buildStationList(),
                ],
              ],
            ),
          ),
        )
    );
  }

  Widget _buildTrainList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_trainResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无车次搜索结果',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        _trainResults.length,
            (index) => _buildItem(index, false),
      ),
    );
  }

  Widget _buildStationList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_stationResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无站点间车次结果',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        _stationResults.length,
            (index) => _buildItem(index, true),
      ),
    );
  }

  Widget _buildItem(int index, bool isStation) {
    final item = isStation ? _stationResults[index] : _trainResults[index];
    final isExpanded = isStation
        ? _stationExpandedIndex == index
        : _expandedIndex == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.train, color: Colors.blue),
            title: Text(
              '${item['station_train_code']} 次列车',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${item['from_station']} → ${item['to_station']}'),
            trailing: AnimatedIcon(
              icon: AnimatedIcons.arrow_menu,
              progress: isExpanded
                  ? _anim
                  : Tween<double>(begin: 0, end: 1).animate(AlwaysStoppedAnimation(0)),
              color: Theme.of(context).colorScheme.primary,
            ),
            onTap: () => _toggleExpand(index, isStation),
          ),
          if (isExpanded) ...[
            SizeTransition(
              sizeFactor: _anim,
              child: _buildExpanded(index, item, isStation),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpanded(int index, Map<String, dynamic> item, bool isStation) {
    final loading = isStation
        ? (_stationLoading[index] ?? false)
        : (_trainLoading[index] ?? false);
    final stopData = isStation
        ? (_stationDetails[index] ?? [])
        : (_trainDetails[index] ?? []);
    String depTime = item['start_time']?.toString() ?? '--:--';
    String arrTime = item['arrive_time']?.toString() ?? '--:--';
    String runTime = item['run_time']?.toString() ?? '--';
    if (stopData.isNotEmpty) {
      final firstStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
            (stop) => stop?['isFirst'] == true,
            orElse: () => null,
          ) ?? stopData.first as Map<String, dynamic>?;
      final lastStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
            (stop) => stop?['isLast'] == true,
            orElse: () => null,
          ) ?? stopData.last as Map<String, dynamic>?;
      if (firstStop != null) {
        final firstArr = firstStop['arriveTime'] as String?;
        final firstDep = firstStop['departTime'] as String?;
        depTime = firstDep ?? firstArr ?? depTime;
      }
      if (lastStop != null) {
        final lastArr = lastStop['arriveTime'] as String?;
        final lastDep = lastStop['departTime'] as String?;
        arrTime = lastArr ?? lastDep ?? arrTime;
      }
      if (firstStop != null && lastStop != null) {
        final firstDep = firstStop['departTime'] as String?;
        final lastArr = lastStop['arriveTime'] as String?;
        if (firstDep != null && lastArr != null) {
          runTime = _calcRunTime(firstDep, lastArr, lastStop['DayDifference']);
        }
      }
    }
    final bool expired = _isExpired(index, item, isStation);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item['station_train_code'] ?? '--',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: expired
                                        ? Colors.grey
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (expired) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '已过期',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['train_class_name'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: expired
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: expired
                                    ? Colors.grey
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                depTime,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: expired ? Colors.grey : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: expired
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                arrTime,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: expired ? Colors.grey : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '运行时长: $runTime',
                            style: TextStyle(
                              fontSize: 13,
                              color: expired
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stationRow(
                              '始发站',
                              item['from_station'],
                              expired ? Colors.grey : Colors.green,
                            ),
                            const SizedBox(height: 8),
                            _stationRow(
                              '终点站',
                              item['to_station'],
                              expired ? Colors.grey : Colors.red,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 24,
                        color: expired
                            ? Colors.grey.shade400
                            : Colors.blue.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildStopSection(index, stopData, loading, isStation),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: expired
                  ? null
                  : () => _handleSelect(index, item, isStation),
              icon: Icon(
                Icons.add,
                color: expired ? Colors.grey.shade400 : Colors.white,
              ),
              label: Text(
                expired ? '车次已过期' : '添加此车次',
                style: TextStyle(
                  color: expired ? Colors.grey.shade400 : Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: expired
                    ? Colors.grey.shade300
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: expired ? Colors.grey.shade400 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calcRunTime(String start, String end, String day) {
    try {
      if (start == '--:--' || end == '--:--') return '--';
      List<String> startParts = start.split(':');
      List<String> endParts = end.split(':');
      if (startParts.length != 2 || endParts.length != 2) return '--';

      int startHour = int.tryParse(startParts[0]) ?? 0;
      int startMin = int.tryParse(startParts[1]) ?? 0;
      int endHour = int.tryParse(endParts[0]) ?? 0;
      int endMin = int.tryParse(endParts[1]) ?? 0;

      // 将day转换为整数，day=0表示不跨天
      int dayOffset = int.tryParse(day) ?? 0;

      int startTotal = startHour * 60 + startMin;
      int endTotal = endHour * 60 + endMin;

      // 如果day>0，需要加上跨天的分钟数
      endTotal += dayOffset * 24 * 60;

      // 如果end时间仍然小于start时间，再补上24小时
      if (endTotal < startTotal) endTotal += 24 * 60;

      int total = endTotal - startTotal;
      int hours = total ~/ 60;
      int minutes = total % 60;

      if (hours > 0) {
        return '$hours小时$minutes分';
      } else {
        return '$minutes分';
      }
    } catch (e) {
      return '--';
    }
  }

  bool _isStationPassed(Map<String, dynamic> stop, DateTime trainDate) {
    final first = (stop['isFirst'] as bool?) ?? false;
    final last = (stop['isLast'] as bool?) ?? false;
    final dayDiff = (stop['DayDifference'] as int?) ?? 0;

    if (first) {
      // 始发站判断发车时间
      final dep = stop['departTime'] as String?;
      return _isTimePassed(trainDate, dep, dayDiff, last);
    } else if (last) {
      // 终点站判断到达时间
      final arr = stop['arriveTime'] as String?;
      return _isTimePassed(trainDate, arr, dayDiff, last);
    } else {
      // 中间站优先判断到达时间
      final arr = stop['arriveTime'] as String?;
      final dep = stop['departTime'] as String?;
      if (arr != null && arr != '--:--') {
        return _isTimePassed(trainDate, arr, dayDiff, last);
      } else if (dep != null && dep != '--:--') {
        return _isTimePassed(trainDate, dep, dayDiff, last);
      }
    }
    return false;
  }

  bool _isExpired(int index, Map<String, dynamic> item, bool isStation) {
    // 获取车次日期
    final date = _selectedDate ?? DateTime.now();

    if (isStation) {
      return _isStationExpired(index, date);
    } else {
      return _isTrainExpired(index, date);
    }
  }

  bool _isStationExpired(int index, DateTime trainDate) {
    final stopData = _stationDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    // 找到用户查询的车站
    final queryStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
          (stop) => stop?['isCurrent'] == true,
      orElse: () => null,
    );

    if (queryStop != null) {
      return _isStationPassed(queryStop, trainDate);
    }

    return false;
  }

  bool _isTrainExpired(int index, DateTime trainDate) {
    final stopData = _trainDetails[index] ?? [];
    if (stopData.isEmpty) return false;

    // 找到终点站
    final lastStop = stopData.cast<Map<String, dynamic>?>().firstWhere(
          (stop) => stop?['isLast'] == true,
      orElse: () => null,
    );

    if (lastStop != null) {
      final arriveTime = lastStop['arriveTime'] as String?;
      final dayDiff = _parseDayDifference(lastStop['DayDifference']);
      return _isTimePassed(trainDate, arriveTime, dayDiff, true);
    }

    return false;
  }

  int _parseDayDifference(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    return 0;
  }

  Widget _stationRow(String label, String? name, Color iconColor) {
    return Row(
      children: [
        Icon(Icons.place, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              name ?? '--',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStopSection(
      int index,
      List<dynamic> stops,
      bool loading,
      bool isStation,
      ) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (stops.isEmpty) {
      return GestureDetector(
        onTap: () => _fetchDetails(index, isStation),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(child: Text('点击加载停站信息')),
        ),
      );
    }

    // 修改这里：使用选择的日期，而不是数据中的日期
    final trainDate = _selectedDate ?? DateTime.now();

    return _buildStopList(stops, trainDate);
  }

  Widget _buildStopList(List<dynamic> stops, DateTime trainDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: stops.length,
        itemBuilder: (context, index) {
          final stop = stops[index] as Map<String, dynamic>;
          final no = stop['stationNo']?.toString() ?? '';
          final name = stop['stationName']?.toString() ?? '';
          final arr = stop['arriveTime']?.toString() ?? '--:--';
          final dep = stop['departTime']?.toString() ?? '--:--';
          final stay = int.tryParse(stop['stayTime']?.toString() ?? '0') ?? 0;
          final first = (stop['isFirst'] as bool?) ?? false;
          final last = (stop['isLast'] as bool?) ?? false;
          final terminal = first || last;

          // 安全转换 DayDifference
          final dayDiffValue = stop['DayDifference'];
          int dayDiff = 0;

          if (dayDiffValue != null) {
            if (dayDiffValue is int) {
              dayDiff = dayDiffValue;
            } else if (dayDiffValue is String) {
              dayDiff = int.tryParse(dayDiffValue) ?? 0;
            } else if (dayDiffValue is num) {
              dayDiff = dayDiffValue.toInt();
            }
          }

          bool passed = false;
          if (first) {
            passed = _isTimePassed(trainDate, dep, dayDiff, last);
          } else if (last) {
            passed = _isTimePassed(trainDate, arr, dayDiff, last);
          } else if (arr != '--:--') {
            passed = _isTimePassed(trainDate, arr, dayDiff, last);
          } else if (dep != '--:--') {
            passed = _isTimePassed(trainDate, dep, dayDiff, last);
          }

          BorderRadius? getBorderRadius() {
            if (stops.length == 1) {
              return BorderRadius.circular(12);
            } else if (index == 0) {
              return const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              );
            } else if (index == stops.length - 1) {
              return const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              );
            }
            return null;
          }

          return Container(
            decoration: BoxDecoration(
              border: index < stops.length - 1
                  ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              )
                  : null,
              color: passed
                  ? (isDark
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.orange.shade50)
                  : terminal
                  ? (isDark
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.green.shade50)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: getBorderRadius(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 车站编号圆圈
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: passed
                          ? (isDark
                          ? Colors.orange.shade700
                          : Colors.orange)
                          : terminal
                          ? (isDark
                          ? Colors.green.shade700
                          : Colors.green)
                          : (isDark
                          ? Colors.blue.shade700
                          : Colors.blue),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      no,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: passed
                                    ? (isDark
                                    ? Colors.orange.shade300
                                    : Colors.orange.shade700)
                                    : terminal
                                    ? (isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (passed)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.orange.shade700
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '已过时',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (dayDiff > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.purple.withValues(alpha: 0.3)
                                      : Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+$dayDiff天',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.purple.shade300
                                        : Colors.purple.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _timeBlock('到达', first ? '--' : arr, passed, first),
                            if (stay > 0)
                              Column(
                                children: [
                                  Text(
                                    '停站',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: passed
                                            ? Colors.orange.shade700
                                            : (isDark
                                            ? Colors.green.shade300
                                            : Colors.green.shade600),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$stay分',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: passed
                                              ? Colors.orange.shade700
                                              : (isDark
                                              ? Colors.green.shade300
                                              : Colors.green.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            _timeBlock('发车', last ? '--' : dep, passed, last),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// 时间块组件
  Widget _timeBlock(String label, String time, bool passed, bool isTerminal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: passed
                ? Colors.orange.shade700
                : isTerminal
                ? (isDark
                ? Colors.green.shade300
                : Colors.green.shade600)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  bool _isTimePassed(DateTime trainDate, String? timeString, int dayDiff, bool isLast) {
    if (timeString == null || timeString.isEmpty || timeString == '--:--') {
      return false;
    }

    try {
      // 解析时间字符串
      final timeParts = timeString.split(':');
      if (timeParts.length < 2) return false;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      // 计算列车实际时间
      // trainDate 是用户选择的日期
      // dayDiff 是相对于发车日的天数差
      final stationDateTime = DateTime(
        trainDate.year,
        trainDate.month,
        trainDate.day + dayDiff,  // 加上天数差
        hour,
        minute,
      );

      // 获取当前时间
      final now = DateTime.now();

      // 直接比较：列车时间是否已经过去了
      return stationDateTime.isBefore(now);

    } catch (e) {
      return false;
    }
  }

  void _handleSelect(int index, Map<String, dynamic> train, bool isStation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认添加'),
        content: Text('是否添加 ${train['station_train_code']} 次列车？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addJourney(index, train, isStation);
            },
            child: const Text('确认添加'),
          ),
        ],
      ),
    );
  }

  void _addJourney(int index, Map<String, dynamic> train, bool isStation) {
    if (_isExpired(index, train, isStation)) {
      _showSnack('车次已过期，无法添加');
      return;
    }
    _showSnack('已添加 ${train['station_train_code']} 次列车');
  }
}