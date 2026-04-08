import 'package:dawnshift/core/models/routine_item.dart';
import 'package:dawnshift/core/models/routine_log.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';

export 'package:dawnshift/features/sleep/sleep_record_repository.dart'
    show FakeFirestore, FirestoreInterface;

// ─── RoutineRepository ────────────────────────────────────────

class RoutineRepository {
  RoutineRepository({required FirestoreInterface store, required String uid})
    : _store = store,
      _uid = uid;

  final FirestoreInterface _store;
  final String _uid;

  String get collectionPath => 'users/$_uid/routines';
  String get routineLogCollectionPath => 'users/$_uid/routine_logs';

  Future<String> add(RoutineItem item) =>
      _store.add(collectionPath, item.toJson());

  Future<List<RoutineItem>> findAll() async {
    final docs = await _store.query(collectionPath, orderByField: 'order');
    return docs.map((d) => RoutineItem.fromJson(d.data)).toList();
  }

  Future<void> update(String id, RoutineItem item) =>
      _store.set(collectionPath, id, item.toJson());

  Future<void> delete(String id) => _store.delete(collectionPath, id);

  Future<void> seedDefaultTemplates() async {
    final existing = await findAll();
    if (existing.isNotEmpty) {
      return;
    }

    for (final item in defaultRoutineTemplates) {
      await add(item);
    }
  }

  Future<void> saveRoutineLog(RoutineLog log) async {
    await _store.set(
      routineLogCollectionPath,
      _dateKey(log.date),
      log.toJson(),
    );
  }

  Future<RoutineLog?> findRoutineLogForDate(DateTime date) async {
    final data = await _store.get(routineLogCollectionPath, _dateKey(date));
    if (data == null) {
      return null;
    }

    return RoutineLog.fromJson(data);
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}

final defaultRoutineTemplates = <RoutineItem>[
  RoutineItem(title: '散歩', durationMinutes: 15, order: 0),
  RoutineItem(title: '朝食', durationMinutes: 20, order: 1),
  RoutineItem(title: '白湯', durationMinutes: 5, order: 2),
  RoutineItem(title: '読書', durationMinutes: 10, order: 3),
];
