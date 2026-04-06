import 'dart:async';

// ─── 例外クラス ────────────────────────────────────────────────

class EmailAlreadyInUseException implements Exception {
  const EmailAlreadyInUseException(this.email);
  final String email;
  @override
  String toString() => 'EmailAlreadyInUseException: $email はすでに登録済みです。';
}

class UserNotFoundException implements Exception {
  const UserNotFoundException(this.email);
  final String email;
  @override
  String toString() => 'UserNotFoundException: $email は見つかりません。';
}

class WrongPasswordException implements Exception {
  const WrongPasswordException();
  @override
  String toString() => 'WrongPasswordException: パスワードが一致しません。';
}

// ─── データモデル ──────────────────────────────────────────────

class AppUser {
  const AppUser({required this.uid, required this.email});
  final String uid;
  final String email;
}

// ─── 認証プロバイダ抽象 ────────────────────────────────────────

abstract class AuthProvider {
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  AppUser? get currentUser;

  Stream<AppUser?> get authStateChanges;
}

// ─── テスト用フェイク ──────────────────────────────────────────

class FakeAuthProvider implements AuthProvider {
  final _users = <String, ({String uid, String password})>{};
  final _stateController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _stateController.stream;

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (_users.containsKey(email)) throw EmailAlreadyInUseException(email);
    final uid = 'uid-${_users.length + 1}';
    _users[email] = (uid: uid, password: password);
    final user = AppUser(uid: uid, email: email);
    _currentUser = user;
    _stateController.add(user);
    return user;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final record = _users[email];
    if (record == null) throw UserNotFoundException(email);
    if (record.password != password) throw const WrongPasswordException();
    final user = AppUser(uid: record.uid, email: email);
    _currentUser = user;
    _stateController.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _stateController.add(null);
  }
}

// ─── AuthService ──────────────────────────────────────────────

class AuthService {
  AuthService({required AuthProvider provider}) : _provider = provider;

  final AuthProvider _provider;

  AppUser? get currentUser => _provider.currentUser;

  Stream<AppUser?> get authStateChanges => _provider.authStateChanges;

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
  }) =>
      _provider.registerWithEmail(email: email, password: password);

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _provider.signInWithEmail(email: email, password: password);

  Future<void> signOut() => _provider.signOut();
}
