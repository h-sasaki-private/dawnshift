import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未ログイン時はログイン画面を表示する', (WidgetTester tester) async {
    final authService = AuthService(provider: FakeAuthProvider());

    await tester.pumpWidget(App(authService: authService));
    await tester.pump();

    expect(find.text('ログイン'), findsWidgets);
  });

  testWidgets('ログイン済みの場合はオンボーディング画面を表示する', (WidgetTester tester) async {
    final fakeAuth = FakeAuthProvider();
    await fakeAuth.registerWithEmail(
      email: 'test@example.com',
      password: 'password123',
    );
    final authService = AuthService(provider: fakeAuth);

    final repository = OnboardingRepository(
      firestore: FakeFirestore(),
      preferences: _FakePreferences(),
      uid: 'test-user',
    );

    await tester.pumpWidget(
      App(repository: repository, authService: authService),
    );
    // ストリームの初期値 → FutureBuilder → OnboardingApp の _bootstrap を待つ
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Onboarding'), findsOneWidget);
  });
}

class _FakePreferences implements SharedPreferencesStore {
  final _bools = <String, bool>{};
  final _strings = <String, String>{};

  @override
  bool? getBool(String key) => _bools[key];
  @override
  String? getString(String key) => _strings[key];
  @override
  Future<bool> setBool(String key, bool value) async => _bools[key] = value;
  @override
  Future<bool> setString(String key, String value) async =>
      (_strings[key] = value) != null;
  @override
  Future<bool> remove(String key) async {
    _bools.remove(key);
    _strings.remove(key);
    return true;
  }
}
