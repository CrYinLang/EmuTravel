import 'package:flutter/material.dart';
import 'journey.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AddJourneyPage())),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              hintText: '搜索车站名称、拼音、三字码...',
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
