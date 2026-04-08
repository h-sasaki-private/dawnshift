import 'package:dawnshift/core/models/routine_item.dart' as morning;
import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/ai_suggestion/night_suggestion_page.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnthropicClient implements AnthropicClient {
  FakeAnthropicClient(this.result);

  final RoutineSuggestionResult result;

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
    return result;
  }
}

void main() {
  group('NightSuggestionPage', () {
    late SleepRecordRepository sleepRepository;
    late RoutineRepository routineRepository;
    late AnthropicClient anthropicClient;

    setUp(() async {
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
            targetBedtime: '22:40',
            routines: [
              RoutineItem(title: '窓を開ける', durationMinutes: 1),
              RoutineItem(title: 'ストレッチ', durationMinutes: 5),
            ],
          ),
          timeToFirstChunk: Duration(milliseconds: 800),
        ),
      );

      await sleepRepository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 6, 23, 15),
          wakeTime: DateTime(2026, 4, 7, 6, 45),
        ),
      );
      await routineRepository.add(
        morning.RoutineItem(title: '既存', durationMinutes: 10, order: 0),
      );
    });

    testWidgets('提案取得とワンタップ適用ができる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NightSuggestionPage(
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            anthropicClient: anthropicClient,
            now: () => DateTime(2026, 4, 7, 21),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('generate-night-suggestion')));
      await tester.pumpAndSettle();

      expect(find.text('推奨就寝時刻 22:40'), findsOneWidget);
      expect(find.text('窓を開ける'), findsOneWidget);
      expect(find.text('ストレッチ'), findsOneWidget);
      expect(find.text('初回応答 0.8秒'), findsOneWidget);

      await tester.tap(find.byKey(const Key('apply-night-suggestion')));
      await tester.pumpAndSettle();

      final items = await routineRepository.findAll();
      expect(
        items.map((e) => (title: e.title, duration: e.durationMinutes, order: e.order)).toList(),
        orderedEquals([
          (title: '窓を開ける', duration: 1, order: 0),
          (title: 'ストレッチ', duration: 5, order: 1),
        ]),
      );
      expect(find.text('明日の朝ルーティンに反映しました'), findsOneWidget);
    });

    testWidgets('睡眠記録がない場合は案内を表示する', (tester) async {
      sleepRepository = SleepRecordRepository(
        store: FakeFirestore(),
        uid: 'user-456',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NightSuggestionPage(
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            anthropicClient: anthropicClient,
            now: () => DateTime(2026, 4, 7, 21),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('generate-night-suggestion')));
      await tester.pumpAndSettle();

      expect(find.text('睡眠記録を1件以上登録すると提案を作成できます'), findsOneWidget);
    });
  });
}
