class RoutineLog {
  const RoutineLog({
    required this.date,
    required this.completedItemIds,
    required this.totalItems,
  }) : assert(totalItems >= 0);

  final DateTime date;
  final List<String> completedItemIds;
  final int totalItems;

  double get completionRate =>
      totalItems == 0 ? 0 : completedItemIds.length / totalItems;

  Map<String, dynamic> toJson() => {
    'date': DateTime(date.year, date.month, date.day).toIso8601String(),
    'completed_item_ids': completedItemIds,
    'total_items': totalItems,
  };

  factory RoutineLog.fromJson(Map<String, dynamic> json) => RoutineLog(
    date: DateTime.parse(json['date'] as String),
    completedItemIds: (json['completed_item_ids'] as List<dynamic>)
        .map((item) => item as String)
        .toList(),
    totalItems: json['total_items'] as int,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RoutineLog &&
        other.date == date &&
        _listEquals(other.completedItemIds, completedItemIds) &&
        other.totalItems == totalItems;
  }

  @override
  int get hashCode =>
      Object.hash(date, Object.hashAll(completedItemIds), totalItems);

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
