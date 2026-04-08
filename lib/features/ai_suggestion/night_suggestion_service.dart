import 'package:dawnshift/core/models/routine_item.dart' as morning;
import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';

class NoSleepRecordsException implements Exception {
  const NoSleepRecordsException();
}

class NightSuggestionService {
  NightSuggestionService({
    required SleepRecordRepository sleepRepository,
    required RoutineRepository routineRepository,
    required AnthropicClient anthropicClient,
  }) : _sleepRepository = sleepRepository,
       _routineRepository = routineRepository,
       _anthropicClient = anthropicClient;

  final SleepRecordRepository _sleepRepository;
  final RoutineRepository _routineRepository;
  final AnthropicClient _anthropicClient;

  Future<RoutineSuggestionResult> generateSuggestion({
    required DateTime from,
  }) async {
    final recentSleepRecords = await _sleepRepository.findLast7Days(from: from);
    if (recentSleepRecords.isEmpty) {
      throw const NoSleepRecordsException();
    }

    return _anthropicClient.fetchRoutineSuggestion(
      NightSuggestionRequest(
        recentSleepRecords: recentSleepRecords,
        recentSleepSummary: _buildRecentSleepSummary(recentSleepRecords),
      ),
    );
  }

  Future<void> applySuggestion(RoutineSuggestion suggestion) async {
    final existingItems = await _routineRepository.findAll();
    for (final item in existingItems) {
      if (item.id == null) {
        continue;
      }
      await _routineRepository.delete(item.id!);
    }

    for (var index = 0; index < suggestion.routines.length; index++) {
      final routine = suggestion.routines[index];
      await _routineRepository.add(
        morning.RoutineItem(
          title: routine.title,
          durationMinutes: routine.durationMinutes,
          order: index,
        ),
      );
    }
  }

  String _buildRecentSleepSummary(List<SleepRecord> records) {
    return records
        .map((record) {
          final wakeDate = _formatDate(record.wakeTime);
          final bedtime = _formatTime(record.bedtime);
          final wakeTime = _formatTime(record.wakeTime);
          final hours = (record.sleepDuration.inMinutes / 60).toStringAsFixed(
            1,
          );

          return '- $wakeDate: 就寝 $bedtime / 起床 $wakeTime / 睡眠時間 $hours時間';
        })
        .join('\n');
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
