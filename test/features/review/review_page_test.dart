import 'package:dawnshift/core/models/routine_log.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:dawnshift/features/review/review_page.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReviewPage', () {
    late FakeFirestore firestore;
    late SleepRecordRepository sleepRepository;
    late RoutineRepository routineRepository;
    final now = DateTime(2026, 4, 9, 8);

    setUp(() {
      firestore = FakeFirestore();
      sleepRepository = SleepRecordRepository(
        store: firestore,
        uid: 'user-123',
      );
      routineRepository = RoutineRepository(store: firestore, uid: 'user-123');
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPage(
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('直近7日分の睡眠グラフとルーティン達成率履歴を表示する', (tester) async {
      await sleepRepository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 8, 23, 0),
          wakeTime: DateTime(2026, 4, 9, 7, 0),
        ),
      );
      await sleepRepository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 7, 22, 30),
          wakeTime: DateTime(2026, 4, 8, 6, 30),
        ),
      );
      await routineRepository.saveRoutineLog(
        RoutineLog(
          date: DateTime(2026, 4, 9),
          completedItemIds: const ['a', 'b', 'c'],
          totalItems: 4,
        ),
      );
      await routineRepository.saveRoutineLog(
        RoutineLog(
          date: DateTime(2026, 4, 8),
          completedItemIds: const ['a'],
          totalItems: 2,
        ),
      );

      await pumpPage(tester);

      expect(find.text('過去7日間の睡眠時間'), findsOneWidget);
      expect(find.byKey(const Key('sleep-duration-chart')), findsOneWidget);
      expect(find.byKey(const Key('sleep-bar-0')), findsOneWidget);
      expect(find.byKey(const Key('sleep-bar-1')), findsOneWidget);
      expect(find.text('就寝 23:00 / 起床 07:00'), findsOneWidget);
      expect(find.text('睡眠時間 8h 0m'), findsNWidgets(2));
      expect(find.text('ルーティン達成率履歴'), findsOneWidget);
      expect(find.text('4/9'), findsWidgets);
      expect(find.text('75%'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('4/8'), findsWidgets);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('記録がない場合は空状態を表示する', (tester) async {
      await pumpPage(tester);

      expect(find.text('まだ記録がありません'), findsNWidgets(2));
      expect(find.text('ルーティン達成率の履歴はまだありません'), findsOneWidget);
    });
  });
}
