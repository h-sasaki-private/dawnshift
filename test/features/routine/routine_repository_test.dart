import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/core/models/routine_item.dart';
import 'package:dawnshift/core/models/routine_log.dart';
import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../subscription/fake_subscription_service.dart';

/// Issue #2: Firestore ルーティン項目 CRUD
/// 完了条件: ルーティンデータの読み書きができること
void main() {
  group('RoutineRepository', () {
    late RoutineRepository repository;
    late FakeSubscriptionService subscriptionService;
    const uid = 'user-123';

    setUp(() {
      subscriptionService = FakeSubscriptionService(
        initialStatus: SubscriptionStatus.premium(),
      );
      repository = RoutineRepository(
        store: FakeFirestore(),
        uid: uid,
        subscriptionService: subscriptionService,
      );
    });

    // ─── 追加 ───────────────────────────────────────────────────

    test('ルーティン項目を追加すると ID が返る', () async {
      final item = RoutineItem(title: '白湯を飲む', durationMinutes: 5, order: 0);

      final id = await repository.add(item);

      expect(id, isNotEmpty);
    });

    // ─── 一覧取得 ───────────────────────────────────────────────

    test('追加した項目を一覧で取得できる', () async {
      await repository.add(
        RoutineItem(title: '軽いストレッチ', durationMinutes: 10, order: 1),
      );
      await repository.add(
        RoutineItem(title: '白湯を飲む', durationMinutes: 5, order: 0),
      );

      final items = await repository.findAll();

      expect(items.length, 2);
      expect(items.first.title, '白湯を飲む');
    });

    test('項目が存在しない場合は空リストを返す', () async {
      final items = await repository.findAll();

      expect(items, isEmpty);
    });

    // ─── 更新 ───────────────────────────────────────────────────

    test('ルーティン項目を更新できる', () async {
      final id = await repository.add(
        RoutineItem(title: '白湯を飲む', durationMinutes: 5, order: 0),
      );

      await repository.update(
        id,
        RoutineItem(title: '白湯を飲む', durationMinutes: 10, order: 0),
      );

      final items = await repository.findAll();
      expect(items.first.durationMinutes, 10);
    });

    // ─── 削除 ───────────────────────────────────────────────────

    test('ルーティン項目を削除できる', () async {
      final id = await repository.add(
        RoutineItem(title: '白湯を飲む', durationMinutes: 5, order: 0),
      );

      await repository.delete(id);

      final items = await repository.findAll();
      expect(items, isEmpty);
    });

    // ─── セキュリティ ───────────────────────────────────────────

    test('保存先パスに uid が含まれている（自分のデータのみアクセス可）', () {
      expect(repository.collectionPath, contains(uid));
    });

    test('デフォルトテンプレートを初回のみ投入できる', () async {
      await repository.seedDefaultTemplates();
      await repository.seedDefaultTemplates();

      final items = await repository.findAll();

      expect(items.length, 4);
      expect(items.map((item) => item.order), orderedEquals([0, 1, 2, 3]));
    });

    test('完了率ログを日付単位で保存・取得できる', () async {
      final log = RoutineLog(
        date: DateTime(2026, 4, 7),
        completedItemIds: ['doc-1', 'doc-2'],
        totalItems: 4,
      );

      await repository.saveRoutineLog(log);

      final fetched = await repository.findRoutineLogForDate(
        DateTime(2026, 4, 7, 23, 59),
      );

      expect(fetched, log);
      expect(fetched!.completionRate, 0.5);
    });

    test('直近7日分の完了率ログを新しい順で取得できる', () async {
      await repository.saveRoutineLog(
        RoutineLog(
          date: DateTime(2026, 4, 1),
          completedItemIds: const ['a'],
          totalItems: 2,
        ),
      );
      await repository.saveRoutineLog(
        RoutineLog(
          date: DateTime(2026, 4, 8),
          completedItemIds: const ['a', 'b', 'c'],
          totalItems: 4,
        ),
      );
      await repository.saveRoutineLog(
        RoutineLog(
          date: DateTime(2026, 4, 9),
          completedItemIds: const ['a'],
          totalItems: 4,
        ),
      );

      final logs = await repository.getRecentLogs(
        from: DateTime(2026, 4, 9, 22),
      );

      expect(logs.map((log) => log.date), [
        DateTime(2026, 4, 9),
        DateTime(2026, 4, 8),
      ]);
    });

    test('無料プランではルーティン項目を5件までしか追加できない', () async {
      repository = RoutineRepository(
        store: FakeFirestore(),
        uid: uid,
        subscriptionService: FakeSubscriptionService(
          initialStatus: SubscriptionStatus.free(),
        ),
      );

      for (var index = 0; index < 5; index++) {
        await repository.add(
          RoutineItem(title: '項目$index', durationMinutes: 5, order: index),
        );
      }

      expect(
        () => repository.add(
          RoutineItem(title: '6件目', durationMinutes: 5, order: 5),
        ),
        throwsA(isA<RoutineLimitExceededException>()),
      );
    });
  });

  group('RoutineItem', () {
    test('JSON へシリアライズ・デシリアライズできる', () {
      final original = RoutineItem(
        title: '白湯を飲む',
        durationMinutes: 5,
        order: 2,
      );

      final json = original.toJson();
      final restored = RoutineItem.fromJson(json);

      expect(restored.title, original.title);
      expect(restored.durationMinutes, original.durationMinutes);
      expect(restored.order, original.order);
    });

    test('タイトルが空の場合は ArgumentError を投げる', () {
      expect(
        () => RoutineItem(title: '', durationMinutes: 5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('duration が0以下の場合は ArgumentError を投げる', () {
      expect(
        () => RoutineItem(title: '白湯を飲む', durationMinutes: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('order が負数の場合は ArgumentError を投げる', () {
      expect(
        () => RoutineItem(title: '白湯を飲む', durationMinutes: 5, order: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('RoutineLog', () {
    test('完了率を計算できる', () {
      final log = RoutineLog(
        date: DateTime(2026, 4, 7),
        completedItemIds: ['a', 'b'],
        totalItems: 4,
      );

      expect(log.completionRate, 0.5);
    });

    test('JSON へシリアライズ・デシリアライズできる', () {
      final original = RoutineLog(
        date: DateTime(2026, 4, 7),
        completedItemIds: ['doc-1'],
        totalItems: 3,
      );

      final restored = RoutineLog.fromJson(original.toJson());

      expect(restored, original);
    });
  });
}
