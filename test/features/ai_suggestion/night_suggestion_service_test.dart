import 'package:dawnshift/core/models/routine_item.dart' as morning;
import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/ai_suggestion/night_suggestion_service.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnthropicClient implements AnthropicClient {
  FakeAnthropicClient(this.result);

  final RoutineSuggestionResult result;
  NightSuggestionRequest? lastRequest;

  @override
  String get systemPrompt => 'test';

  @override
  String buildRequestBody(NightSuggestionRequest request) => '';

  @override
  String buildUserPrompt(NightSuggestionRequest request) => '';

  @override
  Future<RoutineSuggestionResult> fetchRoutineSuggestion(
    NightSuggestionRequest request,
  ) async {
    lastRequest = request;
    return result;
  }
}

void main() {
  group('NightSuggestionService', () {
    late SleepRecordRepository sleepRepository;
    late RoutineRepository routineRepository;
    late FakeAnthropicClient anthropicClient;
    late NightSuggestionService service;

    setUp(() {
      sleepRepository = SleepRecordRepository(
        store: FakeFirestore(),
        uid: 'user-123',
      );
      routineRepository = RoutineRepository(
        store: FakeFirestore(),
        uid: 'user-123',
      );
      anthropicClient = FakeAnthropicClient(
        const RoutineSuggestionResult(
          suggestion: RoutineSuggestion(
            targetBedtime: '22:45',
            routines: [
              RoutineItem(title: 'カーテンを開ける', durationMinutes: 2),
              RoutineItem(title: '散歩する', durationMinutes: 15),
            ],
          ),
          timeToFirstChunk: Duration(seconds: 1),
        ),
      );
      service = NightSuggestionService(
        sleepRepository: sleepRepository,
        routineRepository: routineRepository,
        anthropicClient: anthropicClient,
      );
    });

    test('直近7日分の睡眠記録を AI に渡して提案を取得する', () async {
      await sleepRepository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 6, 23, 30),
          wakeTime: DateTime(2026, 4, 7, 6, 30),
        ),
      );
      await sleepRepository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 5, 23, 0),
          wakeTime: DateTime(2026, 4, 6, 7, 0),
        ),
      );

      final result = await service.generateSuggestion(
        from: DateTime(2026, 4, 7, 21),
      );

      expect(result.suggestion.targetBedtime, '22:45');
      expect(anthropicClient.lastRequest, isNotNull);
      expect(anthropicClient.lastRequest!.recentSleepRecords, hasLength(2));
      expect(
        anthropicClient.lastRequest!.recentSleepSummary,
        contains('2026-04-07'),
      );
      expect(
        anthropicClient.lastRequest!.recentSleepSummary,
        contains('睡眠時間 7.0時間'),
      );
      expect(
        anthropicClient.lastRequest!.recentSleepSummary,
        contains('睡眠時間 8.0時間'),
      );
    });

    test('提案を適用すると既存の朝ルーティンを翌日分向けに置き換える', () async {
      await routineRepository.add(
        morning.RoutineItem(title: '既存1', durationMinutes: 5, order: 0),
      );
      await routineRepository.add(
        morning.RoutineItem(title: '既存2', durationMinutes: 10, order: 1),
      );

      await service.applySuggestion(
        const RoutineSuggestion(
          targetBedtime: '22:30',
          routines: [
            RoutineItem(title: '日光を浴びる', durationMinutes: 10),
            RoutineItem(title: '白湯を飲む', durationMinutes: 5),
          ],
        ),
      );

      final items = await routineRepository.findAll();

      expect(
        items.map((e) => (title: e.title, duration: e.durationMinutes, order: e.order)).toList(),
        orderedEquals([
          (title: '日光を浴びる', duration: 10, order: 0),
          (title: '白湯を飲む', duration: 5, order: 1),
        ]),
      );
    });
  });
}
