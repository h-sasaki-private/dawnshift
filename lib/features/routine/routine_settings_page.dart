import 'package:dawnshift/core/models/routine_item.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:flutter/material.dart';

class RoutineSettingsPage extends StatefulWidget {
  const RoutineSettingsPage({super.key, required this.repository});

  final RoutineRepository repository;

  @override
  State<RoutineSettingsPage> createState() => _RoutineSettingsPageState();
}

class _RoutineItemFormDialog extends StatefulWidget {
  const _RoutineItemFormDialog({this.item});
  final RoutineItem? item;

  @override
  State<_RoutineItemFormDialog> createState() => _RoutineItemFormDialogState();
}

class _RoutineItemFormDialogState extends State<_RoutineItemFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _durationController = TextEditingController(
      text: widget.item?.durationMinutes.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'ルーティン追加' : 'ルーティン編集'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('routine-title-field'),
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'タイトル'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('routine-duration-field'),
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '所要時間（分）'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('save-routine-item'),
          onPressed: () {
            final parsedDuration = int.tryParse(_durationController.text);
            if (parsedDuration == null) return;
            Navigator.of(context).pop(
              (title: _titleController.text, duration: parsedDuration),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _RoutineSettingsPageState extends State<RoutineSettingsPage> {
  List<RoutineItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    await widget.repository.seedDefaultTemplates();
    final items = await widget.repository.findAll();
    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
    });
  }

  Future<void> _showItemDialog({RoutineItem? item}) async {
    final result = await showDialog<({String title, int duration})>(
      context: context,
      builder: (context) => _RoutineItemFormDialog(item: item),
    );

    if (result == null) return;

    final routineItem = RoutineItem(
      id: item?.id,
      title: result.title,
      durationMinutes: result.duration,
      order: item?.order ?? _nextOrder(),
    );

    if (item == null) {
      await widget.repository.add(routineItem);
    } else {
      await widget.repository.update(item.id!, routineItem);
    }

    await _loadItems();
  }

  Future<void> _deleteItem(RoutineItem item) async {
    await widget.repository.delete(item.id!);
    await _reloadAndNormalizeOrders();
  }

  int _nextOrder() {
    if (_items.isEmpty) {
      return 0;
    }

    final maxOrder = _items
        .map((item) => item.order)
        .reduce((current, next) => current > next ? current : next);
    return maxOrder + 1;
  }

  Future<void> _reloadAndNormalizeOrders() async {
    final items = await widget.repository.findAll();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item.id == null || item.order == index) {
        continue;
      }

      await widget.repository.update(item.id!, item.copyWith(order: index));
    }
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('朝ルーティン設定'),
        actions: [
          IconButton(
            key: const Key('add-routine-item'),
            onPressed: _showItemDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text(item.title),
                subtitle: Text('${item.durationMinutes}分'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('edit-routine-${item.title}'),
                      onPressed: () => _showItemDialog(item: item),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      key: Key('delete-routine-${item.title}'),
                      onPressed: () => _deleteItem(item),
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
