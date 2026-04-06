import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2: Firestore 睡眠記録 CRUD
/// 完了条件: 睡眠記録の読み書きができること
void main() {
  group('SleepRecordRepository', () {
    late SleepRecordRepository repository;
    const uid = 'user-123';

    setUp(() {
      repository = SleepRecordRepository(
        store: FakeFirestore(),
        uid: uid,
      );
    });

    // ─── 保存 ───────────────────────────────────────────────────

    test('睡眠記録を保存すると ID が返る', () async {
      final record = SleepRecord(
        bedtime: DateTime(2026, 4, 6, 23, 0),
        wakeTime: DateTime(2026, 4, 7, 7, 0),
      );

      final id = await repository.save(record);

      expect(id, isNotEmpty);
    });

    test('保存した記録を ID で取得できる', () async {
      final record = SleepRecord(
        bedtime: DateTime(2026, 4, 6, 23, 0),
        wakeTime: DateTime(2026, 4, 7, 7, 0),
      );
      final id = await repository.save(record);

      final fetched = await repository.findById(id);

      expect(fetched, isNotNull);
      expect(fetched!.sleepDuration.inHours, 8);
    });

    // ─── 更新 ───────────────────────────────────────────────────

    test('保存した記録を更新できる', () async {
      final record = SleepRecord(
        bedtime: DateTime(2026, 4, 6, 23, 0),
        wakeTime: DateTime(2026, 4, 7, 7, 0),
      );
      final id = await repository.save(record);

      await repository.update(
        id,
        record.copyWith(wakeTime: DateTime(2026, 4, 7, 6, 0)),
      );

      final updated = await repository.findById(id);
      expect(updated!.sleepDuration.inHours, 7);
    });

    // ─── 削除 ───────────────────────────────────────────────────

    test('記録を削除すると findById が null を返す', () async {
      final id = await repository.save(SleepRecord(
        bedtime: DateTime(2026, 4, 6, 23, 0),
        wakeTime: DateTime(2026, 4, 7, 7, 0),
      ));

      await repository.delete(id);

      expect(await repository.findById(id), isNull);
    });

    // ─── 一覧取得 ───────────────────────────────────────────────

    test('過去7日分の記録を新しい順で取得できる', () async {
      final now = DateTime(2026, 4, 6);
      for (var i = 0; i < 10; i++) {
        await repository.save(SleepRecord(
          bedtime: now.subtract(Duration(days: i, hours: 1)),
          wakeTime: now.subtract(Duration(days: i)),
        ));
      }

      final records = await repository.findLast7Days(from: now);

      expect(records.length, 7);
      expect(
        records.first.wakeTime.isAfter(records.last.wakeTime),
        isTrue,
        reason: '新しい順に並んでいること',
      );
    });

    // ─── セキュリティ ───────────────────────────────────────────

    test('保存先パスに uid が含まれている（自分のデータのみアクセス可）', () {
      expect(repository.collectionPath, contains(uid));
    });
  });

  group('SleepRecord', () {
    test('就寝〜起床の睡眠時間を自動計算できる', () {
      final record = SleepRecord(
        bedtime: DateTime(2026, 4, 6, 23, 0),
        wakeTime: DateTime(2026, 4, 7, 7, 30),
      );

      expect(record.sleepDuration.inMinutes, 510); // 8.5h
    });

    test('日付をまたぐ睡眠時間を正しく計算できる', () {
      final record = SleepRecord(
        bedtime: DateTime(2026, 4, 6, 22, 30),
        wakeTime: DateTime(2026, 4, 7, 6, 0),
      );

      expect(record.sleepDuration.inMinutes, 450); // 7.5h
    });

    test('起床時刻が就寝時刻より前の場合は ArgumentError を投げる', () {
      expect(
        () => SleepRecord(
          bedtime: DateTime(2026, 4, 7, 7, 0),
          wakeTime: DateTime(2026, 4, 7, 6, 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('JSON へシリアライズ・デシリアライズできる', () {
      final original = SleepRecord(
        bedtime: DateTime(2026, 4, 6, 23, 0),
        wakeTime: DateTime(2026, 4, 7, 7, 0),
      );

      final json = original.toJson();
      final restored = SleepRecord.fromJson(json);

      expect(restored.bedtime, original.bedtime);
      expect(restored.wakeTime, original.wakeTime);
    });
  });
}
