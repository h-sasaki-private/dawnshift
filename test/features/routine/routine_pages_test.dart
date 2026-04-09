import 'package:dawnshift/core/models/routine_item.dart';
import 'package:dawnshift/core/models/routine_log.dart';
import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:dawnshift/features/routine/morning_routine_page.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/routine/routine_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../subscription/fake_subscription_service.dart';

void main() {
  group('RoutineSettingsPage', () {
    late RoutineRepository repository;
    late FakeSubscriptionService subscriptionService;

    setUp(() {
      subscriptionService = FakeSubscriptionService(
        initialStatus: SubscriptionStatus.free(),
      );
      repository = RoutineRepository(
        store: FakeFirestore(),
        uid: 'user-123',
        subscriptionService: subscriptionService,
      );
    });

    testWidgets('デフォルトテンプレートを表示し項目を追加・編集・削除できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RoutineSettingsPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('散歩'), findsOneWidget);
      expect(find.text('朝食'), findsOneWidget);
      expect(find.text('白湯'), findsOneWidget);
      expect(find.text('読書'), findsOneWidget);
      expect(find.text('無料プラン'), findsOneWidget);
      expect(find.text('プレミアムプラン'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-routine-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('routine-title-field')),
        '日光を浴びる',
      );
      await tester.enterText(
        find.byKey(const Key('routine-duration-field')),
        '8',
      );
      await tester.tap(find.byKey(const Key('save-routine-item')));
      await tester.pumpAndSettle();

      expect(find.text('日光を浴びる'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-routine-日光を浴びる')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('routine-title-field')),
        '深呼吸',
      );
      await tester.enterText(
        find.byKey(const Key('routine-duration-field')),
        '6',
      );
      await tester.tap(find.byKey(const Key('save-routine-item')));
      await tester.pumpAndSettle();

      expect(find.text('深呼吸'), findsOneWidget);
      expect(find.text('日光を浴びる'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-routine-深呼吸')));
      await tester.pumpAndSettle();

      expect(find.text('深呼吸'), findsNothing);

      final items = await repository.findAll();
      expect(items.map((item) => item.order), orderedEquals([0, 1, 2, 3]));
    });

    testWidgets('既存項目を削除してから追加しても order を重複させない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RoutineSettingsPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete-routine-朝食')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-routine-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('routine-title-field')),
        '瞑想',
      );
      await tester.enterText(
        find.byKey(const Key('routine-duration-field')),
        '12',
      );
      await tester.tap(find.byKey(const Key('save-routine-item')));
      await tester.pumpAndSettle();

      final items = await repository.findAll();

      expect(
        items.map((item) => item.title),
        orderedEquals(['散歩', '白湯', '読書', '瞑想']),
      );
      expect(items.map((item) => item.order), orderedEquals([0, 1, 2, 3]));
    });

    testWidgets('無料プランで5件に達すると追加時に制限メッセージを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RoutineSettingsPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-routine-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('routine-title-field')),
        '瞑想',
      );
      await tester.enterText(
        find.byKey(const Key('routine-duration-field')),
        '12',
      );
      await tester.tap(find.byKey(const Key('save-routine-item')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-routine-item')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('routine-title-field')),
        '6件目',
      );
      await tester.enterText(
        find.byKey(const Key('routine-duration-field')),
        '8',
      );
      await tester.tap(find.byKey(const Key('save-routine-item')));
      await tester.pumpAndSettle();

      expect(find.text('無料プランの上限は5件です。プレミアムで解除できます。'), findsOneWidget);
      expect(find.text('6件目'), findsNothing);
    });
  });

  group('MorningRoutinePage', () {
    late RoutineRepository repository;
    final now = DateTime(2026, 4, 7, 6, 30);

    setUp(() async {
      repository = RoutineRepository(store: FakeFirestore(), uid: 'user-123');
      await repository.add(
        RoutineItem(title: '散歩', durationMinutes: 15, order: 0),
      );
      await repository.add(
        RoutineItem(title: '朝食', durationMinutes: 20, order: 1),
      );
    });

    testWidgets('チェック状態から完了率を保存して表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MorningRoutinePage(repository: repository, now: () => now),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('routine-check-散歩')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-routine-log')));
      await tester.pumpAndSettle();

      final log = await repository.findRoutineLogForDate(now);

      expect(log, isNotNull);
      expect(
        log,
        RoutineLog(
          date: DateTime(2026, 4, 7),
          completedItemIds: const ['doc-1'],
          totalItems: 2,
        ),
      );
      expect(find.text('完了率 50%'), findsOneWidget);
    });

    testWidgets('未設定でもデフォルトテンプレートを読み込んで朝の実行画面を表示する', (tester) async {
      repository = RoutineRepository(store: FakeFirestore(), uid: 'user-123');

      await tester.pumpWidget(
        MaterialApp(
          home: MorningRoutinePage(repository: repository, now: () => now),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routine-check-散歩')), findsOneWidget);
      expect(find.byKey(const Key('routine-check-朝食')), findsOneWidget);
      expect(find.byKey(const Key('routine-check-白湯')), findsOneWidget);
      expect(find.byKey(const Key('routine-check-読書')), findsOneWidget);
    });
  });
}
