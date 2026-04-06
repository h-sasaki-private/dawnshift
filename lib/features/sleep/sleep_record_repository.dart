import 'package:dawnshift/core/models/sleep_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class FirebaseFirestoreClient implements FirestoreInterface {
  FirebaseFirestoreClient({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<String> add(String collection, Map<String, dynamic> data) async {
    final document = await _collection(collection).add(data);
    return document.id;
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final snapshot = await _collection(collection).doc(id).get();
    if (!snapshot.exists) {
      return null;
    }

    return _withId(snapshot);
  }

  @override
  Future<void> set(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _collection(collection).doc(id).set(data);
  }

  @override
  Future<void> delete(String collection, String id) async {
    await _collection(collection).doc(id).delete();
  }

  @override
  Future<List<({String id, Map<String, dynamic> data})>> query(
    String collection, {
    DateTime? afterDate,
    int? limit,
    String? orderByField,
    bool descending = false,
  }) async {
    Query<Map<String, dynamic>> firestoreQuery = _collection(collection);

    if (orderByField != null) {
      firestoreQuery = firestoreQuery.orderBy(
        orderByField,
        descending: descending,
      );
      if (afterDate != null) {
        firestoreQuery = firestoreQuery.where(
          orderByField,
          isGreaterThan: Timestamp.fromDate(afterDate),
        );
      }
    }

    if (limit != null) {
      firestoreQuery = firestoreQuery.limit(limit);
    }

    final snapshot = await firestoreQuery.get();
    return snapshot.docs
        .map((doc) => (id: doc.id, data: _withId(doc)))
        .toList();
  }

  CollectionReference<Map<String, dynamic>> _collection(String path) =>
      _firestore.collection(path);

  Map<String, dynamic> _withId(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      return {'id': snapshot.id};
    }

    return {...data, 'id': snapshot.id};
  }
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
