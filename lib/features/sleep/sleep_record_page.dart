import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:flutter/material.dart';

typedef TimePickerCallback =
    Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime);

class SleepRecordPage extends StatefulWidget {
  const SleepRecordPage({
    super.key,
    required this.repository,
    this.now = _now,
    this.bedtimePicker = _showTimePicker,
    this.wakeTimePicker = _showTimePicker,
  });

  final SleepRecordRepository repository;
  final DateTime Function() now;
  final TimePickerCallback bedtimePicker;
  final TimePickerCallback wakeTimePicker;

  static DateTime _now() => DateTime.now();

  static Future<TimeOfDay?> _showTimePicker(
    BuildContext context,
    TimeOfDay initialTime,
  ) {
    return showTimePicker(context: context, initialTime: initialTime);
  }

  @override
  State<SleepRecordPage> createState() => _SleepRecordPageState();
}

class _SleepRecordPageState extends State<SleepRecordPage> {
  late TimeOfDay _bedtime;
  late TimeOfDay _wakeTime;
  List<SleepRecord> _records = const [];
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bedtime = const TimeOfDay(hour: 23, minute: 0);
    _wakeTime = const TimeOfDay(hour: 7, minute: 0);
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await widget.repository.findLast7Days(from: widget.now());
    if (!mounted) {
      return;
    }

    setState(() {
      _records = records;
    });
  }

  Future<void> _selectBedtime() async {
    final selected = await widget.bedtimePicker(context, _bedtime);
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _bedtime = selected;
    });
  }

  Future<void> _selectWakeTime() async {
    final selected = await widget.wakeTimePicker(context, _wakeTime);
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _wakeTime = selected;
    });
  }

  Future<void> _saveRecord() async {
    setState(() {
      _isSaving = true;
    });

    final record = _buildRecord();
    await widget.repository.save(record);
    await _loadRecords();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  SleepRecord _buildRecord() {
    final now = widget.now();
    final wakeTime = DateTime(
      now.year,
      now.month,
      now.day,
      _wakeTime.hour,
      _wakeTime.minute,
    );
    var bedtime = DateTime(
      now.year,
      now.month,
      now.day,
      _bedtime.hour,
      _bedtime.minute,
    );

    if (!wakeTime.isAfter(bedtime)) {
      bedtime = bedtime.subtract(const Duration(days: 1));
    }

    return SleepRecord(bedtime: bedtime, wakeTime: wakeTime);
  }

  @override
  Widget build(BuildContext context) {
    final latestDuration = _records.isEmpty
        ? null
        : _formatDuration(_records.first.sleepDuration);

    return Scaffold(
      appBar: AppBar(title: const Text('睡眠記録')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimeField(
                    key: const Key('bedtime-field'),
                    label: '就寝時刻',
                    value: _formatTimeOfDay(_bedtime),
                    onTap: _selectBedtime,
                  ),
                  const SizedBox(height: 12),
                  _TimeField(
                    key: const Key('wake-time-field'),
                    label: '起床時刻',
                    value: _formatTimeOfDay(_wakeTime),
                    onTap: _selectWakeTime,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('save-sleep-record'),
                    onPressed: _isSaving ? null : _saveRecord,
                    child: Text(_isSaving ? '保存中...' : '保存する'),
                  ),
                  if (latestDuration != null) ...[
                    const SizedBox(height: 12),
                    Text('最新の睡眠時間: $latestDuration'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SleepDurationChart(records: _records),
          const SizedBox(height: 16),
          for (final record in _records)
            Card(
              child: ListTile(
                title: Text(_formatDuration(record.sleepDuration)),
                subtitle: Text(_formatRecordDate(record)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatRecordDate(SleepRecord record) =>
      '${record.wakeTime.month}/${record.wakeTime.day}';

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}

class SleepDurationChart extends StatelessWidget {
  const SleepDurationChart({super.key, required this.records});

  final List<SleepRecord> records;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = records
        .map((record) => record.sleepDuration.inMinutes)
        .fold<int>(0, (max, minutes) => minutes > max ? minutes : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('過去7日間の睡眠時間'),
            const SizedBox(height: 12),
            SizedBox(
              key: const Key('sleep-duration-chart'),
              height: 160,
              child: records.isEmpty
                  ? const Center(child: Text('まだ記録がありません'))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var index = 0; index < records.length; index++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _SleepBar(
                                key: Key('sleep-bar-$index'),
                                label:
                                    '${records[index].wakeTime.month}/${records[index].wakeTime.day}',
                                minutes: records[index].sleepDuration.inMinutes,
                                maxMinutes: maxMinutes,
                              ),
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

class _SleepBar extends StatelessWidget {
  const _SleepBar({
    super.key,
    required this.label,
    required this.minutes,
    required this.maxMinutes,
  });

  final String label;
  final int minutes;
  final int maxMinutes;

  @override
  Widget build(BuildContext context) {
    final ratio = maxMinutes == 0 ? 0.0 : minutes / maxMinutes;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('${(minutes / 60).toStringAsFixed(1)}h'),
        const SizedBox(height: 8),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: ratio.clamp(0.0, 1.0),
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }
}
