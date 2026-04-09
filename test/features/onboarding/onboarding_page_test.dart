import 'package:dawnshift/features/onboarding/onboarding_app.dart';
import 'package:dawnshift/features/onboarding/onboarding_page.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSharedPreferences implements SharedPreferencesStore {
  final _boolValues = <String, bool>{};
  final _stringValues = <String, String>{};

  @override
  bool? getBool(String key) => _boolValues[key];

  @override
  String? getString(String key) => _stringValues[key];

  @override
  Future<bool> remove(String key) async {
    _boolValues.remove(key);
    _stringValues.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _boolValues[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _stringValues[key] = value;
    return true;
  }
}

Future<TimeOfDay?> _fixedPicker(
  BuildContext context,
  TimeOfDay initialTime,
) async => initialTime;

void main() {
  group('OnboardingPage', () {
    late FakeFirestore firestore;
    late FakeSharedPreferences preferences;
    late OnboardingRepository repository;
    late AuthService authService;

    setUp(() {
      firestore = FakeFirestore();
      preferences = FakeSharedPreferences();
      repository = OnboardingRepository(
        firestore: firestore,
        preferences: preferences,
        uid: 'user-123',
      );
      authService = AuthService(provider: FakeAuthProvider());
    });

    testWidgets('入力内容を保存して完了できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingPage(
            repository: repository,
            currentBedtimePicker: (_, __) async =>
                const TimeOfDay(hour: 23, minute: 15),
            currentWakeTimePicker: (_, __) async =>
                const TimeOfDay(hour: 6, minute: 45),
            idealBedtimePicker: (_, __) async =>
                const TimeOfDay(hour: 22, minute: 30),
            idealWakeTimePicker: (_, __) async =>
                const TimeOfDay(hour: 6, minute: 0),
            onCompleted: (_) {},
            onSkipped: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('current-bedtime-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('current-wake-time-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ideal-bedtime-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ideal-wake-time-field')));
      await tester.pumpAndSettle();

      // 白湯を飲むをタップして解除する（デフォルトは全選択）
      await tester.tap(find.byKey(const Key('routine-candidate-白湯を飲む')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-onboarding')));
      await tester.pumpAndSettle();

      final saved = await repository.loadProfile();

      expect(saved, isNotNull);
      expect(saved!.currentBedtime, '23:15');
      expect(saved.currentWakeTime, '06:45');
      expect(saved.idealBedtime, '22:30');
      expect(saved.morningRoutineCandidates, isNot(contains('白湯を飲む')));
      expect(saved.morningRoutineCandidates, contains('日光を浴びる'));
      expect(find.text('ホーム'), findsNothing);
    });

    testWidgets('スキップできる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingPage(
            repository: repository,
            currentBedtimePicker: _fixedPicker,
            currentWakeTimePicker: _fixedPicker,
            idealBedtimePicker: _fixedPicker,
            idealWakeTimePicker: _fixedPicker,
            onCompleted: (_) {},
            onSkipped: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skip-onboarding')));
      await tester.pumpAndSettle();

      expect(preferences.getBool(repository.completedKey), isTrue);
      expect(await repository.isCompleted(), isTrue);
    });
  });

  group('OnboardingApp', () {
    late FakeFirestore firestore;
    late FakeSharedPreferences preferences;
    late OnboardingRepository repository;
    late AuthService authService;

    setUp(() {
      firestore = FakeFirestore();
      preferences = FakeSharedPreferences();
      repository = OnboardingRepository(
        firestore: firestore,
        preferences: preferences,
        uid: 'user-123',
      );
      authService = AuthService(provider: FakeAuthProvider());
    });

    testWidgets('初回起動では onboarding を表示し、完了後はホームを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingApp(
            repository: repository,
            authService: authService,
            currentBedtimePicker: (_, __) async =>
                const TimeOfDay(hour: 23, minute: 15),
            currentWakeTimePicker: (_, __) async =>
                const TimeOfDay(hour: 6, minute: 45),
            idealBedtimePicker: (_, __) async =>
                const TimeOfDay(hour: 22, minute: 30),
            idealWakeTimePicker: (_, __) async =>
                const TimeOfDay(hour: 6, minute: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboarding'), findsOneWidget);

      await tester.tap(find.byKey(const Key('current-bedtime-field')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-onboarding')));
      await tester.pumpAndSettle();

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.byKey(const Key('edit-onboarding')), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-onboarding')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('current-bedtime-field')), findsOneWidget);
      expect(find.text('23:15'), findsWidgets);
    });

    testWidgets('スキップした後もホームから再編集できる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingApp(repository: repository, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skip-onboarding')));
      await tester.pumpAndSettle();

      expect(find.text('ホーム'), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-onboarding')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ideal-wake-time-field')), findsOneWidget);
    });

    testWidgets('ホームから設定画面へ遷移できる', (tester) async {
      await preferences.setBool(repository.completedKey, true);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingApp(repository: repository, authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open-settings')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
    });
  });
}
