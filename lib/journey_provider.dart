// journey_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'journey_model.dart';

class JourneyProvider extends ChangeNotifier {
  final List<Journey> _journeys = [];
  static const String _storageKey = 'journeys_data';

  List<Journey> get journeys => List.unmodifiable(_journeys);

  JourneyProvider() {
    _loadJourneys();
  }

  // 从存储加载行程
  Future<void> _loadJourneys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? journeysJson = prefs.getString(_storageKey);

      if (journeysJson != null && journeysJson.isNotEmpty) {
        final List<dynamic> journeysList = json.decode(journeysJson);
        _journeys.clear();
        _journeys.addAll(
            journeysList.map((journeyMap) =>
                Journey.fromStorageMap(journeyMap as Map<String, dynamic>)
            ).toList()
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('加载行程数据失败: $e');
      }
    }
  }

  // 保存行程到存储
  Future<void> _saveJourneys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String journeysJson = json.encode(
          _journeys.map((journey) => journey.toMap()).toList()
      );
      await prefs.setString(_storageKey, journeysJson);
    } catch (e) {
      if (kDebugMode) {
        print('保存行程数据失败: $e');
      }
    }
  }

  // 添加行程
  void addJourney(Journey journey) {
    // 检查是否已存在相同ID的行程
    if (!_journeys.any((j) => j.id == journey.id)) {
      _journeys.add(journey);
      _saveJourneys();
      notifyListeners();
    }
  }

  // 删除行程
  void removeJourney(String id) {
    _journeys.removeWhere((j) => j.id == id);
    _saveJourneys();
    notifyListeners();
  }

  // 清空所有行程
  void clearAll() {
    _journeys.clear();
    _saveJourneys();
    notifyListeners();
  }

  // 根据日期排序
  void sortByDate() {
    _journeys.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    _saveJourneys();
    notifyListeners();
  }

  // 获取特定日期的行程
  List<Journey> getJourneysByDate(DateTime date) {
    return _journeys.where((j) {
      return j.travelDate.year == date.year &&
          j.travelDate.month == date.month &&
          j.travelDate.day == date.day;
    }).toList();
  }

  // 更新行程（如果需要）
  void updateJourney(Journey updatedJourney) {
    final index = _journeys.indexWhere((j) => j.id == updatedJourney.id);
    if (index != -1) {
      _journeys[index] = updatedJourney;
      _saveJourneys();
      notifyListeners();
    }
  }
}