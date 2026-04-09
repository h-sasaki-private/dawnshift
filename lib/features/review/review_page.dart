import 'package:dawnshift/core/models/routine_log.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_page.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:flutter/material.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.sleepRepository,
    required this.routineRepository,
    this.now = _now,
  });

  final SleepRecordRepository sleepRepository;
  final RoutineRepository routineRepository;
  final DateTime Function() now;

  static DateTime _now() => DateTime.now();

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<SleepRecord> _sleepRecords = const [];
  List<RoutineLog> _routineLogs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sleepRecords = await widget.sleepRepository.findLast7Days(
      from: widget.now(),
    );
    final routineLogs = await widget.routineRepository.getRecentLogs(
      from: widget.now(),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _sleepRecords = sleepRecords;
      _routineLogs = routineLogs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('振り返り')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SleepDurationChart(records: _sleepRecords),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('睡眠詳細'),
                  const SizedBox(height: 12),
                  if (_sleepRecords.isEmpty)
                    const Text('まだ記録がありません')
                  else
                    for (final record in _sleepRecords) ...[
                      Text(_formatDate(record.wakeTime)),
                      Text(
                        '就寝 ${_formatTime(record.bedtime)} / 起床 ${_formatTime(record.wakeTime)}',
                      ),
                      Text('睡眠時間 ${_formatDuration(record.sleepDuration)}'),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ルーティン達成率履歴'),
                  const SizedBox(height: 12),
                  if (_routineLogs.isEmpty)
                    const Text('ルーティン達成率の履歴はまだありません')
                  else
                    for (final log in _routineLogs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_formatDate(log.date)),
                        trailing: Text(
                          '${(log.completionRate * 100).round()}%',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
