// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    final repository = OnboardingRepository(
      firestore: FakeFirestore(),
      preferences: _FakePreferences(),
      uid: 'test-user',
    );

    await tester.pumpWidget(App(repository: repository));
    await tester.pumpAndSettle();

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
