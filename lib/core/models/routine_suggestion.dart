class RoutineItem {
  const RoutineItem({
    required this.title,
    required this.durationMinutes,
  });

  final String title;
  final int durationMinutes;

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    return RoutineItem(
      title: json['title'] as String,
      durationMinutes: json['duration_minutes'] as int,
    );
  }
}

class RoutineSuggestion {
  const RoutineSuggestion({
    required this.targetBedtime,
    required this.routines,
  });

  final String targetBedtime;
  final List<RoutineItem> routines;

  factory RoutineSuggestion.fromJson(Map<String, dynamic> json) {
    final routines = (json['routines'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(RoutineItem.fromJson)
        .toList();

    return RoutineSuggestion(
      targetBedtime: json['target_bedtime'] as String,
      routines: routines,
    );
  }
}

class RoutineSuggestionResult {
  const RoutineSuggestionResult({
    required this.suggestion,
    required this.timeToFirstChunk,
  });

  final RoutineSuggestion suggestion;
  final Duration timeToFirstChunk;
}
