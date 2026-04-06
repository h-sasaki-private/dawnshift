class RoutineItem {
  RoutineItem({
    this.id,
    required this.title,
    required this.durationMinutes,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('タイトルが空です。');
    }
    if (durationMinutes <= 0) {
      throw ArgumentError('duration は1以上である必要があります。');
    }
  }

  final String? id;
  final String title;
  final int durationMinutes;

  RoutineItem copyWith({String? id, String? title, int? durationMinutes}) =>
      RoutineItem(
        id: id ?? this.id,
        title: title ?? this.title,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'duration_minutes': durationMinutes,
      };

  factory RoutineItem.fromJson(Map<String, dynamic> json) => RoutineItem(
        id: json['id'] as String?,
        title: json['title'] as String,
        durationMinutes: json['duration_minutes'] as int,
      );
}
