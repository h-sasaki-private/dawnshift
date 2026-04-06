import 'package:dawnshift/core/models/sleep_record.dart';

// ─── Firestore抽象 ─────────────────────────────────────────────

abstract class FirestoreInterface {
  Future<String> add(String collection, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> get(String collection, String id);
  Future<void> set(String collection, String id, Map<String, dynamic> data);
  Future<void> delete(String collection, String id);
  Future<List<({String id, Map<String, dynamic> data})>> query(
    String collection, {
    DateTime? afterDate,
    int? limit,
    String? orderByField,
    bool descending = false,
  });
}

// ─── テスト用フェイク ──────────────────────────────────────────

class FakeFirestore implements FirestoreInterface {
  final _store = <String, Map<String, Map<String, dynamic>>>{};
  var _counter = 0;

  @override
  Future<String> add(String collection, Map<String, dynamic> data) async {
    final id = 'doc-${++_counter}';
    _store.putIfAbsent(collection, () => {})[id] = {...data, 'id': id};
    return id;
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async =>
      _store[collection]?[id];

  @override
  Future<void> set(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async =>
      _store.putIfAbsent(collection, () => {})[id] = {...data, 'id': id};

  @override
  Future<void> delete(String collection, String id) async =>
      _store[collection]?.remove(id);

  @override
  Future<List<({String id, Map<String, dynamic> data})>> query(
    String collection, {
    DateTime? afterDate,
    int? limit,
    String? orderByField,
    bool descending = false,
  }) async {
    var docs = (_store[collection]?.entries ?? [])
        .map((e) => (id: e.key, data: e.value))
        .toList();

    if (afterDate != null && orderByField != null) {
      docs = docs.where((d) {
        final value = d.data[orderByField];
        if (value is String) {
          return DateTime.parse(value).isAfter(afterDate);
        }
        return true;
      }).toList();
    }

    if (orderByField != null) {
      docs.sort((a, b) {
        final av = a.data[orderByField] as String? ?? '';
        final bv = b.data[orderByField] as String? ?? '';
        return descending ? bv.compareTo(av) : av.compareTo(bv);
      });
    }

    if (limit != null && docs.length > limit) {
      docs = docs.sublist(0, limit);
    }

    return docs;
  }
}

// ─── SleepRecordRepository ────────────────────────────────────

class SleepRecordRepository {
  SleepRecordRepository({
    required FirestoreInterface store,
    required String uid,
  })  : _store = store,
        _uid = uid;

  final FirestoreInterface _store;
  final String _uid;

  String get collectionPath => 'users/$_uid/sleep_records';

  Future<String> save(SleepRecord record) =>
      _store.add(collectionPath, record.toJson());

  Future<SleepRecord?> findById(String id) async {
    final data = await _store.get(collectionPath, id);
    if (data == null) return null;
    return SleepRecord.fromJson(data);
  }

  Future<void> update(String id, SleepRecord record) =>
      _store.set(collectionPath, id, record.toJson());

  Future<void> delete(String id) => _store.delete(collectionPath, id);

  Future<List<SleepRecord>> findLast7Days({required DateTime from}) async {
    final sevenDaysAgo = from.subtract(const Duration(days: 7));
    final docs = await _store.query(
      collectionPath,
      afterDate: sevenDaysAgo,
      limit: 7,
      orderByField: 'wake_time',
      descending: true,
    );
    return docs.map((d) => SleepRecord.fromJson(d.data)).toList();
  }
}
