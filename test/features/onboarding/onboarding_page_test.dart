import 'package:dawnshift/features/onboarding/onboarding_app.dart';
import 'package:dawnshift/features/onboarding/onboarding_page.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/ai_suggestion/night_suggestion_page.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/review/review_page.dart';
import 'package:dawnshift/features/sleep/sleep_record_page.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:dawnshift/features/subscription/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../subscription/fake_subscription_service.dart';

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

class FakeAnthropicClient implements AnthropicClient {
  @override
  String get systemPrompt => 'test';

  @override
  String buildRequestBody(NightSuggestionRequest request) => '';

  @override
  String buildUserPrompt(NightSuggestionRequest request) => '';

  @override
  Future<RoutineSuggestionResult> fetchRoutineSuggestion(
    NightSuggestionRequest request,
  ) async {
    return const RoutineSuggestionResult(
      suggestion: RoutineSuggestion(targetBedtime: '22:30', routines: []),
      timeToFirstChunk: Duration(milliseconds: 100),
    );
  }
}

void main() {
  group('OnboardingPage', () {
    late FakeFirestore firestore;
    late FakeSharedPreferences preferences;
    late OnboardingRepository repository;
    late AuthService authService;
    late SleepRecordRepository sleepRepository;
    late RoutineRepository routineRepository;
    late AnthropicClient anthropicClient;
    late SubscriptionService subscriptionService;

    setUp(() {
      firestore = FakeFirestore();
      preferences = FakeSharedPreferences();
      repository = OnboardingRepository(
        firestore: firestore,
        preferences: preferences,
        uid: 'user-123',
      );
      authService = AuthService(provider: FakeAuthProvider());
      sleepRepository = SleepRecordRepository(
        store: firestore,
        uid: 'user-123',
      );
      routineRepository = RoutineRepository(store: firestore, uid: 'user-123');
      anthropicClient = FakeAnthropicClient();
      subscriptionService = FakeSubscriptionService(
        initialStatus: SubscriptionStatus.free(),
      );
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
            onCompleted: (_) async {},
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
            onCompleted: (_) async {},
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
    late SleepRecordRepository sleepRepository;
    late RoutineRepository routineRepository;
    late AnthropicClient anthropicClient;
    late SubscriptionService subscriptionService;

    setUp(() {
      firestore = FakeFirestore();
      preferences = FakeSharedPreferences();
      repository = OnboardingRepository(
        firestore: firestore,
        preferences: preferences,
        uid: 'user-123',
      );
      authService = AuthService(provider: FakeAuthProvider());
      sleepRepository = SleepRecordRepository(
        store: firestore,
        uid: 'user-123',
      );
      routineRepository = RoutineRepository(store: firestore, uid: 'user-123');
      anthropicClient = FakeAnthropicClient();
      subscriptionService = FakeSubscriptionService(
        initialStatus: SubscriptionStatus.free(),
      );
    });

    testWidgets('初回起動では onboarding を表示し、完了後はホームを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingApp(
            repository: repository,
            authService: authService,
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            anthropicClient: anthropicClient,
            subscriptionService: subscriptionService,
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
          home: OnboardingApp(
            repository: repository,
            authService: authService,
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            anthropicClient: anthropicClient,
            subscriptionService: subscriptionService,
          ),
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
          home: OnboardingApp(
            repository: repository,
            authService: authService,
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            anthropicClient: anthropicClient,
            subscriptionService: subscriptionService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open-settings')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('ホームから各機能画面へ遷移できる', (tester) async {
      await preferences.setBool(repository.completedKey, true);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingApp(
            repository: repository,
            authService: authService,
            sleepRepository: sleepRepository,
            routineRepository: routineRepository,
            anthropicClient: anthropicClient,
            subscriptionService: subscriptionService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-sleep-record')));
      await tester.pumpAndSettle();
      expect(find.text('睡眠記録'), findsOneWidget);
      expect(find.byType(SleepRecordPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(SleepRecordPage))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-morning-routine')));
      await tester.pumpAndSettle();
      expect(find.text('今朝のルーティン'), findsOneWidget);

      Navigator.of(tester.element(find.text('今朝のルーティン'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-routine-settings')));
      await tester.pumpAndSettle();
      expect(find.text('朝ルーティン設定'), findsOneWidget);

      Navigator.of(tester.element(find.text('朝ルーティン設定'))).pop();
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-night-suggestion')));
      await tester.pumpAndSettle();
      expect(find.text('今夜のAI提案'), findsOneWidget);
      expect(find.byType(NightSuggestionPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(NightSuggestionPage))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-review')));
      await tester.pumpAndSettle();
      expect(find.text('振り返り'), findsOneWidget);
      expect(find.byType(ReviewPage), findsOneWidget);
    });
  });
}
