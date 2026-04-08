class UserProfile {
  const UserProfile({
    this.id,
    required this.currentBedtime,
    required this.currentWakeTime,
    required this.idealBedtime,
    required this.idealWakeTime,
    required this.morningRoutineCandidates,
    this.onboardingCompleted = false,
  });

  final String? id;
  final String currentBedtime;
  final String currentWakeTime;
  final String idealBedtime;
  final String idealWakeTime;
  final List<String> morningRoutineCandidates;
  final bool onboardingCompleted;

  UserProfile copyWith({
    String? id,
    String? currentBedtime,
    String? currentWakeTime,
    String? idealBedtime,
    String? idealWakeTime,
    List<String>? morningRoutineCandidates,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id ?? this.id,
      currentBedtime: currentBedtime ?? this.currentBedtime,
      currentWakeTime: currentWakeTime ?? this.currentWakeTime,
      idealBedtime: idealBedtime ?? this.idealBedtime,
      idealWakeTime: idealWakeTime ?? this.idealWakeTime,
      morningRoutineCandidates:
          morningRoutineCandidates ?? this.morningRoutineCandidates,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'current_bedtime': currentBedtime,
        'current_wake_time': currentWakeTime,
        'ideal_bedtime': idealBedtime,
        'ideal_wake_time': idealWakeTime,
        'morning_routine_candidates': morningRoutineCandidates,
        'onboarding_completed': onboardingCompleted,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String?,
      currentBedtime: json['current_bedtime'] as String,
      currentWakeTime: json['current_wake_time'] as String,
      idealBedtime: json['ideal_bedtime'] as String,
      idealWakeTime: json['ideal_wake_time'] as String,
      morningRoutineCandidates:
          (json['morning_routine_candidates'] as List<dynamic>? ?? const [])
              .map((value) => value as String)
              .toList(),
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    );
  }

  String toPromptContext() {
    final routines = morningRoutineCandidates.isEmpty
        ? '未選択'
        : morningRoutineCandidates.join('、');

    return '''
現在の就寝時刻: $currentBedtime
現在の起床時刻: $currentWakeTime
理想の就寝時刻: $idealBedtime
理想の起床時刻: $idealWakeTime
朝のルーティン候補: $routines
''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is UserProfile &&
        other.id == id &&
        other.currentBedtime == currentBedtime &&
        other.currentWakeTime == currentWakeTime &&
        other.idealBedtime == idealBedtime &&
        other.idealWakeTime == idealWakeTime &&
        other.onboardingCompleted == onboardingCompleted &&
        _listEquals(other.morningRoutineCandidates, morningRoutineCandidates);
  }

  @override
  int get hashCode => Object.hash(
        id,
        currentBedtime,
        currentWakeTime,
        idealBedtime,
        idealWakeTime,
        onboardingCompleted,
        Object.hashAll(morningRoutineCandidates),
      );

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
