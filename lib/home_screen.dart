import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [])),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddJourneyPage())),
        backgroundColor: Colors.blue, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class AddJourneyPage extends StatefulWidget {
  const AddJourneyPage({super.key});
  @override
  State<AddJourneyPage> createState() => _AddJourneyPageState();
}

class _AddJourneyPageState extends State<AddJourneyPage> with SingleTickerProviderStateMixin {
  DateTime? selectedDate;
  final _textController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _searchResults = [];
  int? _expandedIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final Map<int, List<dynamic>> _stopDetails = {};
  final Map<int, bool> _loadingStopDetails = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _textController.addListener(() {
      final text = _textController.text;
      if (text.isNotEmpty && text != text.toUpperCase()) _validateAndFormatInput(text);
    });

    // 自动选择明天作为默认日期
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    selectedDate = today.add(const Duration(days: 1));  // 明天
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));  // 明天
    final maxDate = today.add(const Duration(days: 14));
    final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? tomorrow,  // 默认显示明天
        firstDate: today,  // 最早可选今天
        lastDate: maxDate
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _expandedIndex = null;
        _stopDetails.clear(); // 清空之前的停站信息
        _loadingStopDetails.clear();
        if (_animationController.isAnimating) _animationController.reset();
      });
    }
  }

  String get dateText => selectedDate == null ? "选择日期" :
  "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
  String get _formattedDate => selectedDate == null ? "" :
  "${selectedDate!.year}${selectedDate!.month.toString().padLeft(2, '0')}${selectedDate!.day.toString().padLeft(2, '0')}";

  void _validateAndFormatInput(String value) {
    if (value.isEmpty) return;
    String uppercase = value.toUpperCase();
    const allowedLetters = 'GDCSKZTW';
    String result = '';
    for (int i = 0; i < uppercase.length; i++) {
      String char = uppercase[i];
      if (i == 0) {
        if (RegExp(r'[0-9]').hasMatch(char) || allowedLetters.contains(char)) result += char;
      } else {
        if (RegExp(r'[0-9]').hasMatch(char)) result += char;
      }
    }
    if (result != _textController.text) {
      _textController.value = _textController.value.copyWith(
        text: result, selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  Future<void> _searchTrainInfo() async {
    if (selectedDate == null) { _showSnackBar('请先选择日期'); return; }
    final trainNumber = _textController.text.trim();
    if (trainNumber.isEmpty) { _showSnackBar('请输入车次'); return; }
    setState(() {
      _isLoading = true;
      _searchResults.clear();
      _stopDetails.clear(); // 清空停站信息
      _loadingStopDetails.clear();
      _expandedIndex = null;
      if (_animationController.isAnimating) _animationController.reset();
    });
    try {
      final url = 'https://search.12306.cn/search/v1/train/search?keyword=$trainNumber&date=$_formattedDate';
      final response = await http.get(Uri.parse(url),headers: Vars.normalHeaders);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() { _searchResults = data['data'] ?? []; });
          if (_searchResults.isEmpty) {
            _showSnackBar('未找到相关车次信息');
          } else {
            _showSnackBar('找到 ${_searchResults.length} 条结果');
          }
        } else {
          _showSnackBar('搜索失败: ${data['errorMsg']}');
        }
      } else {
        _showSnackBar('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('发生错误: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _fetchStopDetails(int index) async {
    if (_stopDetails.containsKey(index)) return; // 已加载过

    final trainInfo = _searchResults[index];
    final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
    if (trainNumber.isEmpty) return;

    setState(() {
      _loadingStopDetails[index] = true;
    });

    try {
      // 调用携程API获取停站信息
      final stopData = await _fetchCtripStopTimeInfo(trainNumber);

      setState(() {
        _stopDetails[index] = stopData;
        _loadingStopDetails[index] = false;
      });
    } catch (e) {
      debugPrint('获取停站信息失败: $e'); // 使用debugPrint替代print
      _showSnackBar('获取停站信息失败: $e');
      setState(() {
        _loadingStopDetails[index] = false;
      });
    }
  }

  Future<List<dynamic>> _fetchCtripStopTimeInfo(String trainNumber) async {
    // 携程API地址
    final url = Uri.parse('https://m.ctrip.com/restapi/soa2/14674/json/GetTrainStopTimeInfo');

    // 准备请求头
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://m.ctrip.com/',
      'Origin': 'https://m.ctrip.com',
    };

    // 准备请求体 - 根据实际返回数据结构，可能只需要TrainNumber
    final body = {
      'TrainNumber': trainNumber,
      // 根据实际需要添加日期参数，但根据返回结果看可能不需要
      // 'DepartureDate': dateText.replaceAll('选择日期', ''),
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 根据您提供的返回数据结构进行解析
        if (data['RetCode'] == 1 && data['StopList'] != null) {
          final List<dynamic> stopList = data['StopList'];

          // 格式化停站信息
          final formattedStops = stopList.map((stop) {
            return {
              'stationNo': stop['StationNo'] ?? '',
              'stationName': stop['StationName'] ?? '',
              'arriveTime': stop['ArriveTime'] ?? '--:--',
              'departTime': stop['DepartTime'] ?? '--:--',
              'runTime': stop['RunTime'] ?? '0',
              'stayTime': stop['StayWayStationTime'] ?? '0',
              'delayMinutes': stop['DelayMinutes'] ?? 0,
              'telCode': stop['TelCode'] ?? '',
              'isFirst': stop['StationNo'] == '01',
              'isLast': stop['StationNo'] == stopList.length.toString().padLeft(2, '0'),
            };
          }).toList();

          return formattedStops;
        } else if (data['RetCode'] != 1) {
          throw Exception('API返回失败: RetCode=${data['RetCode']}, Ack=${data['ResponseStatus']?['Ack']}');
        } else {
          return [];
        }
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取停站信息错误: $e'); // 使用debugPrint替代print
      rethrow;
    }
  }

  void _toggleExpand(int index) async {
    if (_expandedIndex == index) {
      _animationController.reverse().then((_) {
        if (mounted) { setState(() { _expandedIndex = null; }); }
      });
    } else {
      setState(() { _expandedIndex = index; });
      _animationController.forward();

      // 展开时自动加载停站信息
      await _fetchStopDetails(index);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加旅途'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(flex: 4, child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                height: 56, padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Text(dateText, style: TextStyle(
                    fontSize: 16,
                    color: selectedDate == null ? Theme.of(context).hintColor : Theme.of(context).textTheme.bodyLarge?.color,
                  )),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: TextField(
              controller: _textController,
              onChanged: (value) { if (value.isNotEmpty) _validateAndFormatInput(value); },
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9GDCSKZTWgdcskztw]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return newValue.copyWith(text: newValue.text.toUpperCase());
                }),
              ],
              decoration: InputDecoration(
                hintText: "请输入车次", contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                filled: true, fillColor: Colors.transparent,
              ),
              style: const TextStyle(fontSize: 16), maxLines: 1,
            )),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _searchTrainInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Text('搜索车次信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildResultsList()),
        ]),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.train, size: 64, color: Colors.grey), SizedBox(height: 16),
          Text('暂无搜索结果',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _buildTrainItem(index),
    );
  }

  Widget _buildTrainItem(int index) {
    final item = _searchResults[index];
    final isExpanded = _expandedIndex == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.train, color: Colors.blue),
          title: Text('${item['station_train_code']} 次列车', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${item['from_station']} → ${item['to_station']}'),
          trailing: AnimatedIcon(
            icon: AnimatedIcons.arrow_menu,
            progress: isExpanded ? _animation : Tween<double>(begin: 0, end: 1).animate(AlwaysStoppedAnimation(0)),
            color: Colors.blue,
          ),
          onTap: () => _toggleExpand(index),
        ),
        if (isExpanded) ...[
          SizeTransition(sizeFactor: _animation, child: _buildExpandedContent(index, item)),
        ],
      ]),
    );
  }

  Widget _buildExpandedContent(int index, Map<String, dynamic> item) {
    final isLoading = _loadingStopDetails[index] ?? false;
    final stopData = _stopDetails[index] ?? [];

    // 获取始发站和终点站的到达/出发时间
    String departureTime = item['start_time']?.toString() ?? '--:--';
    String arrivalTime = item['arrive_time']?.toString() ?? '--:--';
    String runTime = item['run_time']?.toString() ?? '--';

    // 从停站信息中查找始发站和终点站
    Map<String, dynamic>? firstStop;
    Map<String, dynamic>? lastStop;

    if (stopData.isNotEmpty) {
      // 查找始发站（第一站）
      try {
        firstStop = stopData.firstWhere(
              (stop) => (stop['isFirst'] as bool?) == true,
        ) as Map<String, dynamic>?;
      } catch (e) {
        // 如果没有找到 isFirst 为 true 的车站，使用第一站
        firstStop = stopData.isNotEmpty ? stopData[0] as Map<String, dynamic>? : null;
      }

      // 查找终点站（最后一站）
      try {
        lastStop = stopData.firstWhere(
              (stop) => (stop['isLast'] as bool?) == true,
        ) as Map<String, dynamic>?;
      } catch (e) {
        // 如果没有找到 isLast 为 true 的车站，使用最后一站
        lastStop = stopData.isNotEmpty ? stopData.last as Map<String, dynamic>? : null;
      }

      if (firstStop != null) {
        // 始发站使用发车时间
        departureTime = firstStop['departTime']?.toString() ??
            firstStop['arriveTime']?.toString() ??
            departureTime;
      }

      if (lastStop != null) {
        // 终点站使用到达时间
        arrivalTime = lastStop['arriveTime']?.toString() ??
            lastStop['departTime']?.toString() ??
            arrivalTime;
      }

      // 从停站信息中计算总运行时间
      if (stopData.isNotEmpty && firstStop != null && lastStop != null) {
        // 获取始发站发车时间
        final departureTimeStr = firstStop['departTime']?.toString() ??
            firstStop['arriveTime']?.toString();
        // 获取终点站到达时间
        final arrivalTimeStr = lastStop['arriveTime']?.toString() ??
            lastStop['departTime']?.toString();

        if (departureTimeStr != null &&
            arrivalTimeStr != null &&
            departureTimeStr.length >= 5 &&
            arrivalTimeStr.length >= 5) {

          try {
            // 解析时间字符串，如 "07:00", "11:29"
            final departureParts = departureTimeStr.split(':');
            final arrivalParts = arrivalTimeStr.split(':');

            if (departureParts.length == 2 && arrivalParts.length == 2) {
              final departureHour = int.tryParse(departureParts[0]) ?? 0;
              final departureMinute = int.tryParse(departureParts[1]) ?? 0;
              final arrivalHour = int.tryParse(arrivalParts[0]) ?? 0;
              final arrivalMinute = int.tryParse(arrivalParts[1]) ?? 0;

              // 转换为分钟数
              final departureMinutes = departureHour * 60 + departureMinute;
              final arrivalMinutes = arrivalHour * 60 + arrivalMinute;

              // 计算时间差
              int totalMinutes = arrivalMinutes - departureMinutes;

              // 如果跨天（到达时间小于出发时间），说明是第二天
              if (totalMinutes < 0) {
                totalMinutes += 24 * 60; // 加上一天的时间
              }

              if (totalMinutes > 0) {
                final hours = totalMinutes ~/ 60;
                final minutes = totalMinutes % 60;
                runTime = hours > 0 ? '$hours小时$minutes分' : '$minutes分';
              }
            }
          } catch (e) {
            debugPrint('时间解析错误: $e');
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本车次信息卡片
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 车次名称和时间
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['station_train_code']?.toString() ?? '--',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['train_class_name']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
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
                              const Icon(Icons.schedule, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                departureTime,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                arrivalTime,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '运行时长: $runTime',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.grey),

                  // 车站信息
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.place, size: 16, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '始发站',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        item['from_station']?.toString() ?? '--',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.place, size: 16, color: Colors.red),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '终点站',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        item['to_station']?.toString() ?? '--',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 24,
                        color: Colors.blue.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 停站信息标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.train, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    '停站信息',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (stopData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stopData.length}站',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!isLoading && stopData.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => _refreshStopDetails(index),
                  tooltip: '刷新停站信息',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 停站信息内容
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      '正在加载停站信息...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (stopData.isEmpty)
            GestureDetector(
              onTap: () => _fetchStopDetails(index),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '暂无停站信息',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击加载停站信息',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildStopList(stopData),

          const SizedBox(height: 20),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleTrainSelection(item),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    '添加此车次',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 新增：刷新停站信息的方法
  void _refreshStopDetails(int index) async {
    setState(() {
      _loadingStopDetails[index] = true;
      _stopDetails.remove(index); // 清除缓存数据
    });

    try {
      final trainInfo = _searchResults[index];
      final trainNumber = trainInfo['station_train_code']?.toString() ?? '';
      if (trainNumber.isNotEmpty) {
        final stopData = await _fetchCtripStopTimeInfo(trainNumber);
        setState(() {
          _stopDetails[index] = stopData;
          _loadingStopDetails[index] = false;
        });
        _showSnackBar('停站信息已刷新');
      }
    } catch (e) {
      _showSnackBar('刷新失败: $e');
      setState(() {
        _loadingStopDetails[index] = false;
      });
    }
  }

  Widget _buildStopList(List<dynamic> stops) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stops.length,
        itemBuilder: (context, index) {
          final stop = stops[index];
          final stationNo = stop['stationNo']?.toString() ?? '';
          final stationName = stop['stationName']?.toString() ?? '';
          final arriveTime = stop['arriveTime']?.toString() ?? '--:--';
          final departTime = stop['departTime']?.toString() ?? '--:--';
          final stayTime = int.tryParse(stop['stayTime']?.toString() ?? '0') ?? 0;
          final isFirst = (stop['isFirst'] as bool?) ?? false;
          final isLast = (stop['isLast'] as bool?) ?? false;
          final isTerminal = isFirst || isLast;  // 判断是否是起点站或终点站

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: index < stops.length - 1
                  ? Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              )
                  : null,
              color: isTerminal
                  ? Colors.green.shade50
                  : Colors.white,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 站序
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isTerminal
                        ? Colors.green
                        : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    stationNo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 车站信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 车站名称
                      Row(
                        children: [
                          Text(
                            stationName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isTerminal
                                  ? Colors.green.shade700
                                  : Colors.black,
                            ),
                          ),
                          if (stop['stationStatus'] != null &&
                              stop['stationStatus'] != '未知')
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                      stop['stationStatus']?.toString() ?? ''),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  stop['stationStatus']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // 时间信息
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 到达时间
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '到达',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                // 如果是始发站，到达时间显示为 --
                                isFirst ? '--' : (arriveTime != '--:--' ? arriveTime : '--'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isFirst
                                      ? Colors.grey
                                      : arriveTime != '--:--'
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),

                          // 停站时间
                          if (stayTime > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '停站',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${stayTime}分',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                          // 发车时间
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '发车',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                // 如果是终点站，发车时间显示为 --
                                isLast ? '--' : (departTime != '--:--' ? departTime : '--'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isLast
                                      ? Colors.grey
                                      : departTime != '--:--'
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '始发/终到站':
        return Colors.green;
      case '过路站':
        return Colors.blue;
      case '折返站':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }


  void _handleTrainSelection(Map<String, dynamic> trainInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认添加'),
        content: Text('是否添加 ${trainInfo['station_train_code']} 次列车？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ElevatedButton(onPressed: () { Navigator.of(context).pop(); _addJourney(trainInfo); }, child: const Text('确认添加')),
        ],
      ),
    );
  }

  void _addJourney(Map<String, dynamic> trainInfo) {
    _showSnackBar('已添加 ${trainInfo['station_train_code']} 次列车');
  }
}