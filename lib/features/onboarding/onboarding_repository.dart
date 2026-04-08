import 'dart:convert';
import 'dart:io';

import 'package:dawnshift/core/models/user_profile.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';

abstract class SharedPreferencesStore {
  bool? getBool(String key);
  String? getString(String key);
  Future<bool> setBool(String key, bool value);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

class FileSharedPreferencesStore implements SharedPreferencesStore {
  FileSharedPreferencesStore._(this._file, this._values);

  final File _file;
  final Map<String, Object?> _values;

  static Future<FileSharedPreferencesStore> load(File file) async {
    if (!await file.exists()) {
      return FileSharedPreferencesStore._(file, <String, Object?>{});
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return FileSharedPreferencesStore._(file, <String, Object?>{});
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return FileSharedPreferencesStore._(
      file,
      Map<String, Object?>.from(decoded),
    );
  }

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return _flush();
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _values[key] = value;
    return _flush();
  }

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return _flush();
  }

  Future<bool> _flush() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(_values));
    return true;
  }
}

class OnboardingRepository {
  OnboardingRepository({
    required this.firestore,
    required this.preferences,
    required this.uid,
  });

  final FirestoreInterface firestore;
  final SharedPreferencesStore preferences;
  final String uid;

  String get completedKey => 'onboarding_completed';
  String get profileKey => 'onboarding_profile';
  String get documentId => 'profile';

  String get collectionPath => 'users/$uid/user_profile';

  Future<bool> isCompleted() async {
    final local = preferences.getBool(completedKey);
    if (local != null) {
      return local;
    }

    final remote = await firestore.get(collectionPath, documentId);
    final completed = remote?['onboarding_completed'] == true;
    if (completed) {
      await preferences.setBool(completedKey, true);
    }
    return completed;
  }

  Future<UserProfile?> loadProfile() async {
    final cached = preferences.getString(profileKey);
    if (cached != null) {
      try {
        return UserProfile.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } on FormatException {
        await preferences.remove(profileKey);
      }
    }

    final remote = await firestore.get(collectionPath, documentId);
    if (remote == null || !remote.containsKey('current_bedtime')) {
      return null;
    }

    final profile = UserProfile.fromJson(remote);
    await _cacheProfile(profile);
    return profile;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final completedProfile = profile.copyWith(onboardingCompleted: true);
    await _cacheProfile(completedProfile);
    await firestore.set(collectionPath, documentId, completedProfile.toJson());
  }

  Future<void> markSkipped() async {
    await preferences.setBool(completedKey, true);
    await firestore.set(
      collectionPath,
      documentId,
      {'onboarding_completed': true},
    );
  }

  Future<void> clear() async {
    await preferences.remove(completedKey);
    await preferences.remove(profileKey);
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    await preferences.setBool(completedKey, profile.onboardingCompleted);
    await preferences.setString(profileKey, jsonEncode(profile.toJson()));
  }
}

Future<SharedPreferencesStore> createSharedPreferencesStore() async {
  final homeDirectory = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final file = File('$homeDirectory/.dawnshift/onboarding_prefs.json');
  return FileSharedPreferencesStore.load(file);
}
