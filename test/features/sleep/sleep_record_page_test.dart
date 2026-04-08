import 'package:dawnshift/features/sleep/sleep_record_page.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SleepRecordPage', () {
    late SleepRecordRepository repository;
    final now = DateTime(2026, 4, 7, 9);

    setUp(() {
      repository = SleepRecordRepository(
        store: FakeFirestore(),
        uid: 'user-123',
      );
    });

    Future<void> pumpPage(
      WidgetTester tester, {
      Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? bedtimePicker,
      Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? wakeTimePicker,
    }) async {
      Future<TimeOfDay?> unchangedPicker(
        BuildContext context,
        TimeOfDay initialTime,
      ) async => initialTime;

      await tester.pumpWidget(
        MaterialApp(
          home: SleepRecordPage(
            repository: repository,
            now: () => now,
            bedtimePicker: bedtimePicker ?? unchangedPicker,
            wakeTimePicker: wakeTimePicker ?? unchangedPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('保存済み記録と過去7日グラフを表示する', (tester) async {
      await repository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 6, 23),
          wakeTime: DateTime(2026, 4, 7, 7),
        ),
      );
      await repository.save(
        SleepRecord(
          bedtime: DateTime(2026, 4, 5, 22, 30),
          wakeTime: DateTime(2026, 4, 6, 6),
        ),
      );

      await pumpPage(tester);

      expect(find.text('8h 0m'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('7h 30m'), findsOneWidget);
      expect(find.byKey(const Key('sleep-duration-chart')), findsOneWidget);
      expect(find.byKey(const Key('sleep-bar-0')), findsOneWidget);
      expect(find.byKey(const Key('sleep-bar-1')), findsOneWidget);
    });

    testWidgets('就寝時刻より早い起床時刻は翌朝として保存する', (tester) async {
      await pumpPage(
        tester,
        bedtimePicker: (_, __) async => const TimeOfDay(hour: 23, minute: 0),
        wakeTimePicker: (_, __) async => const TimeOfDay(hour: 7, minute: 0),
      );

      await tester.tap(find.byKey(const Key('bedtime-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake-time-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-sleep-record')));
      await tester.pumpAndSettle();

      final records = await repository.findLast7Days(from: now);

      expect(records, hasLength(1));
      expect(records.single.bedtime, DateTime(2026, 4, 6, 23));
      expect(records.single.wakeTime, DateTime(2026, 4, 7, 7));
      expect(find.text('8h 0m'), findsOneWidget);
    });
  });
}
