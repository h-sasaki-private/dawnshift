import 'package:dawnshift/core/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('JSON へ変換しても入力内容を保持する', () {
      const profile = UserProfile(
        id: 'profile-1',
        currentBedtime: '23:15',
        currentWakeTime: '06:45',
        idealBedtime: '22:30',
        idealWakeTime: '06:00',
        morningRoutineCandidates: [
          '日光を浴びる',
          '白湯を飲む',
          '軽いストレッチ',
        ],
        onboardingCompleted: true,
      );

      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored, profile);
    });

    test('AI プロンプト用の文脈文字列を生成できる', () {
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

      final prompt = profile.toPromptContext();

      expect(prompt, contains('現在の就寝時刻: 23:15'));
      expect(prompt, contains('理想の起床時刻: 06:00'));
      expect(prompt, contains('日光を浴びる'));
    });
  });
}
