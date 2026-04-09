import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2: Firebase認証
/// 完了条件: ユーザー登録・ログインが動作すること
void main() {
  group('AuthService', () {
    late AuthService authService;
    late FakeAuthProvider fakeAuth;

    setUp(() {
      fakeAuth = FakeAuthProvider();
      authService = AuthService(provider: fakeAuth);
    });

    // ─── 新規登録 ───────────────────────────────────────────────

    test('メール・パスワードで新規登録するとユーザーが返る', () async {
      final user = await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );

      expect(user.uid, isNotEmpty);
      expect(user.email, 'test@example.com');
    });

    test('すでに登録済みのメールで登録すると EmailAlreadyInUseException を投げる', () async {
      await authService.registerWithEmail(
        email: 'existing@example.com',
        password: 'Password123!',
      );

      expect(
        () => authService.registerWithEmail(
          email: 'existing@example.com',
          password: 'Password123!',
        ),
        throwsA(isA<EmailAlreadyInUseException>()),
      );
    });

    // ─── ログイン ───────────────────────────────────────────────

    test('登録済みメール・パスワードでログインするとユーザーが返る', () async {
      await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );

      final user = await authService.signInWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );

      expect(user.uid, isNotEmpty);
      expect(user.email, 'test@example.com');
    });

    test('未登録メールでログインすると UserNotFoundException を投げる', () {
      expect(
        () => authService.signInWithEmail(
          email: 'notfound@example.com',
          password: 'Password123!',
        ),
        throwsA(isA<UserNotFoundException>()),
      );
    });

    test('パスワード不一致でログインすると WrongPasswordException を投げる', () async {
      await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );

      expect(
        () => authService.signInWithEmail(
          email: 'test@example.com',
          password: 'WrongPassword!',
        ),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    // ─── ログアウト ─────────────────────────────────────────────

    test('ログアウト後は currentUser が null になる', () async {
      await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );
      await authService.signOut();

      expect(authService.currentUser, isNull);
    });

    test('アカウント削除後は currentUser が null になり再ログインできない', () async {
      await authService.registerWithEmail(
        email: 'delete@example.com',
        password: 'Password123!',
      );

      await authService.deleteAccount();

      expect(authService.currentUser, isNull);
      expect(
        () => authService.signInWithEmail(
          email: 'delete@example.com',
          password: 'Password123!',
        ),
        throwsA(isA<UserNotFoundException>()),
      );
    });

    test('未ログイン状態でアカウント削除すると StateError を投げる', () {
      expect(() => authService.deleteAccount(), throwsA(isA<StateError>()));
    });

    // ─── 認証状態 ───────────────────────────────────────────────

    test('ログイン済みユーザーの UID が取得できる', () async {
      await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );

      expect(authService.currentUser?.uid, isNotEmpty);
    });

    test('authStateChanges がログイン・ログアウト状態を通知する', () async {
      final states = <AppUser?>[];
      final sub = authService.authStateChanges.listen(states.add);

      await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );
      await authService.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(states, [isA<AppUser>(), isNull]);
      await sub.cancel();
    });
  });
}
