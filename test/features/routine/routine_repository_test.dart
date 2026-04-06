import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/core/models/routine_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2: Firestore ルーティン項目 CRUD
/// 完了条件: ルーティンデータの読み書きができること
void main() {
  group('RoutineRepository', () {
    late RoutineRepository repository;
    const uid = 'user-123';

    setUp(() {
      repository = RoutineRepository(
        store: FakeFirestore(),
        uid: uid,
      );
    });

    // ─── 追加 ───────────────────────────────────────────────────

    test('ルーティン項目を追加すると ID が返る', () async {
      final item = RoutineItem(title: '白湯を飲む', durationMinutes: 5);

      final id = await repository.add(item);

      expect(id, isNotEmpty);
    });

    // ─── 一覧取得 ───────────────────────────────────────────────

    test('追加した項目を一覧で取得できる', () async {
      await repository.add(RoutineItem(title: '白湯を飲む', durationMinutes: 5));
      await repository.add(RoutineItem(title: '軽いストレッチ', durationMinutes: 10));

      final items = await repository.findAll();

      expect(items.length, 2);
    });

    test('項目が存在しない場合は空リストを返す', () async {
      final items = await repository.findAll();

      expect(items, isEmpty);
    });

    // ─── 更新 ───────────────────────────────────────────────────

    test('ルーティン項目を更新できる', () async {
      final id = await repository.add(
        RoutineItem(title: '白湯を飲む', durationMinutes: 5),
      );

      await repository.update(
        id,
        RoutineItem(title: '白湯を飲む', durationMinutes: 10),
      );

      final items = await repository.findAll();
      expect(items.first.durationMinutes, 10);
    });

    // ─── 削除 ───────────────────────────────────────────────────

    test('ルーティン項目を削除できる', () async {
      final id = await repository.add(
        RoutineItem(title: '白湯を飲む', durationMinutes: 5),
      );

      await repository.delete(id);

      final items = await repository.findAll();
      expect(items, isEmpty);
    });

    // ─── セキュリティ ───────────────────────────────────────────

    test('保存先パスに uid が含まれている（自分のデータのみアクセス可）', () {
      expect(repository.collectionPath, contains(uid));
    });
  });

  group('RoutineItem', () {
    test('JSON へシリアライズ・デシリアライズできる', () {
      final original = RoutineItem(title: '白湯を飲む', durationMinutes: 5);

      final json = original.toJson();
      final restored = RoutineItem.fromJson(json);

      expect(restored.title, original.title);
      expect(restored.durationMinutes, original.durationMinutes);
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
  });
}
