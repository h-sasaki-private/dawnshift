import 'package:dawnshift/core/models/user_profile.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
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

void main() {
  group('OnboardingRepository', () {
    late FakeFirestore firestore;
    late FakeSharedPreferences preferences;
    late OnboardingRepository repository;

    setUp(() {
      firestore = FakeFirestore();
      preferences = FakeSharedPreferences();
      repository = OnboardingRepository(
        firestore: firestore,
        preferences: preferences,
        uid: 'user-123',
      );
    });

    test('プロフィール保存時に SharedPreferences と Firestore の両方へ反映する', () async {
      const profile = UserProfile(
        currentBedtime: '23:15',
        currentWakeTime: '06:45',
        idealBedtime: '22:30',
        idealWakeTime: '06:00',
        morningRoutineCandidates: [
          '日光を浴びる',
          '白湯を飲む',
        ],
      );

      await repository.saveProfile(profile);

      expect(await repository.isCompleted(), isTrue);

      final remote = await firestore.get(
        repository.collectionPath,
        repository.documentId,
      );

      expect(preferences.getBool(repository.completedKey), isTrue);
      expect(preferences.getString(repository.profileKey), isNotNull);
      expect(remote, isNotNull);
      expect(remote?['onboarding_completed'], isTrue);
      expect(remote?['ideal_bedtime'], '22:30');
    });

    test('Firestore の保存済みプロフィールを読み込める', () async {
      const profile = UserProfile(
        currentBedtime: '23:00',
        currentWakeTime: '07:00',
        idealBedtime: '22:15',
        idealWakeTime: '06:15',
        morningRoutineCandidates: ['朝食をとる'],
        onboardingCompleted: true,
      );

      await firestore.set(
        repository.collectionPath,
        repository.documentId,
        profile.toJson(),
      );

      final loaded = await repository.loadProfile();

      expect(loaded?.currentBedtime, profile.currentBedtime);
      expect(loaded?.currentWakeTime, profile.currentWakeTime);
      expect(loaded?.idealBedtime, profile.idealBedtime);
      expect(loaded?.idealWakeTime, profile.idealWakeTime);
      expect(loaded?.morningRoutineCandidates, profile.morningRoutineCandidates);
      expect(loaded?.onboardingCompleted, isTrue);
      expect(preferences.getBool(repository.completedKey), isTrue);
    });
  });
}
