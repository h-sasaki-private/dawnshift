import 'package:dawnshift/core/models/routine_item.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';

export 'package:dawnshift/features/sleep/sleep_record_repository.dart'
    show FakeFirestore, FirestoreInterface;

// ─── RoutineRepository ────────────────────────────────────────

class RoutineRepository {
  RoutineRepository({
    required FirestoreInterface store,
    required String uid,
  })  : _store = store,
        _uid = uid;

  final FirestoreInterface _store;
  final String _uid;

  String get collectionPath => 'users/$_uid/routines';

  Future<String> add(RoutineItem item) =>
      _store.add(collectionPath, item.toJson());

  Future<List<RoutineItem>> findAll() async {
    final docs = await _store.query(collectionPath);
    return docs.map((d) => RoutineItem.fromJson(d.data)).toList();
  }

  Future<void> update(String id, RoutineItem item) =>
      _store.set(collectionPath, id, item.toJson());

  Future<void> delete(String id) => _store.delete(collectionPath, id);
}
