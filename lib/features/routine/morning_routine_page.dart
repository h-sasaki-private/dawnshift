import 'package:dawnshift/core/models/routine_item.dart';
import 'package:dawnshift/core/models/routine_log.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:flutter/material.dart';

class MorningRoutinePage extends StatefulWidget {
  const MorningRoutinePage({
    super.key,
    required this.repository,
    this.now = _now,
  });

  final RoutineRepository repository;
  final DateTime Function() now;

  static DateTime _now() => DateTime.now();

  @override
  State<MorningRoutinePage> createState() => _MorningRoutinePageState();
}

class _MorningRoutinePageState extends State<MorningRoutinePage> {
  List<RoutineItem> _items = const [];
  Set<String> _completedItemIds = <String>{};
  RoutineLog? _savedLog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.repository.seedDefaultTemplates();
    final items = await widget.repository.findAll();
    final savedLog = await widget.repository.findRoutineLogForDate(
      widget.now(),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _savedLog = savedLog;
      _completedItemIds = savedLog?.completedItemIds.toSet() ?? <String>{};
    });
  }

  Future<void> _toggleItem(RoutineItem item, bool? checked) async {
    setState(() {
      if (checked ?? false) {
        _completedItemIds.add(item.id!);
      } else {
        _completedItemIds.remove(item.id!);
      }
    });
  }

  Future<void> _save() async {
    final log = RoutineLog(
      date: DateTime(widget.now().year, widget.now().month, widget.now().day),
      completedItemIds: _items
          .where((item) => _completedItemIds.contains(item.id))
          .map((item) => item.id!)
          .toList(),
      totalItems: _items.length,
    );

    await widget.repository.saveRoutineLog(log);
    if (!mounted) {
      return;
    }

    setState(() {
      _savedLog = log;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completionRate = ((_savedLog?.completionRate ?? 0) * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('今朝のルーティン')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('完了率 $completionRate%'),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _items)
            CheckboxListTile(
              key: Key('routine-check-${item.title}'),
              title: Text(item.title),
              subtitle: Text('${item.durationMinutes}分'),
              value: _completedItemIds.contains(item.id),
              onChanged: (checked) => _toggleItem(item, checked),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('save-routine-log'),
            onPressed: _save,
            child: const Text('完了率を保存'),
          ),
        ],
      ),
    );
  }
}
