import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 这里可以添加其他内容
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 跳转到添加旅途页面
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddJourneyPage(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // 圆角正方形
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // 右下角位置
    );
  }
}

// 添加旅途页面
class AddJourneyPage extends StatefulWidget {
  const AddJourneyPage({super.key});

  @override
  State<AddJourneyPage> createState() => _AddJourneyPageState();
}

class _AddJourneyPageState extends State<AddJourneyPage> {
  DateTime? selectedDate;
  final _textController = TextEditingController();

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  String get dateText {
    if (selectedDate == null) return "选择日期";
    return "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
  }

  void _validateAndFormatInput(String value) {
    if (value.isEmpty) {
      return;
    }

    // 1. 先转换为大写
    String uppercase = value.toUpperCase();

    // 2. 过滤不允许的字符
    String filtered = uppercase.replaceAll(RegExp(r'[^0-9GDCSKZTW]'), '');

    // 3. 处理格式化
    String result = '';
    if (filtered.isNotEmpty) {
      const String allowedLetters = 'GDCSKZTW';

      // 检查第一个字符
      String firstChar = filtered[0];

      if (allowedLetters.contains(firstChar)) {
        // 第一个字符是允许的字母
        result = firstChar;
        // 添加后面的数字
        if (filtered.length > 1) {
          String numbersOnly = filtered.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
          result += numbersOnly;
        }
      }// else if (RegExp(r'^[0-9]').hasMatch(filtered)) {
      //   // 第一个字符是数字
      //   String numbersOnly = filtered.replaceAll(RegExp(r'[^0-9]'), '');
      //   result = 'G$numbersOnly'; // 添加G
      // } else {
      //   result = '';
      // }
    }

    // 4. 更新文本
    if (result != _textController.text) {
      _textController.value = _textController.value.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // 监听控制器变化
    _textController.addListener(() {
      final text = _textController.text;
      if (text.isNotEmpty && text != text.toUpperCase()) {
        // 确保文本是大写
        _validateAndFormatInput(text);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔹 顶部时间栏（40%是日期）
            Row(
              children: [
                Expanded(
                  flex: 4, // 40%
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 16,
                              color: selectedDate == null
                                  ? Theme.of(context).hintColor
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                /// 剩下 60% 文本输入框
                Expanded(
                  flex: 5, // 60%
                  child: TextField(
                    controller: _textController,
                    onChanged: (value) {
                      // 立即处理输入
                      if (value.isNotEmpty) {
                        _validateAndFormatInput(value);
                      }
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9GDCSKZTWgdcskztw]')),
                      // 添加一个formatter来自动转换为大写
                      TextInputFormatter.withFunction(
                            (oldValue, newValue) {
                          return newValue.copyWith(
                            text: newValue.text.toUpperCase(),
                          );
                        },
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: "请输入车次",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            const Icon(Icons.add_location_alt, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              '添加新旅途',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('这里可以添加旅途的表单内容'),
          ],
        ),
      ),
    );
  }
}