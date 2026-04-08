class RoutineItem {
  RoutineItem({
    this.id,
    required this.title,
    required this.durationMinutes,
    this.order = 0,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('タイトルが空です。');
    }
    if (durationMinutes <= 0) {
      throw ArgumentError('duration は1以上である必要があります。');
    }
    if (order < 0) {
      throw ArgumentError('order は0以上である必要があります。');
    }
  }

  final String? id;
  final String title;
  final int durationMinutes;
  final int order;

  RoutineItem copyWith({
    String? id,
    String? title,
    int? durationMinutes,
    int? order,
  }) => RoutineItem(
    id: id ?? this.id,
    title: title ?? this.title,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'duration_minutes': durationMinutes,
    'order': order,
  };

  factory RoutineItem.fromJson(Map<String, dynamic> json) => RoutineItem(
    id: json['id'] as String?,
    title: json['title'] as String,
    durationMinutes: json['duration_minutes'] as int,
    order: json['order'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RoutineItem &&
        other.id == id &&
        other.title == title &&
        other.durationMinutes == durationMinutes &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(id, title, durationMinutes, order);
}
