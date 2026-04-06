class SleepRecord {
  SleepRecord({
    this.id,
    required this.bedtime,
    required this.wakeTime,
  }) {
    if (!wakeTime.isAfter(bedtime)) {
      throw ArgumentError('起床時刻は就寝時刻より後である必要があります。');
    }
  }

  final String? id;
  final DateTime bedtime;
  final DateTime wakeTime;

  Duration get sleepDuration => wakeTime.difference(bedtime);

  SleepRecord copyWith({String? id, DateTime? bedtime, DateTime? wakeTime}) =>
      SleepRecord(
        id: id ?? this.id,
        bedtime: bedtime ?? this.bedtime,
        wakeTime: wakeTime ?? this.wakeTime,
      );

  Map<String, dynamic> toJson() => {
        'bedtime': bedtime.toIso8601String(),
        'wake_time': wakeTime.toIso8601String(),
      };

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
        id: json['id'] as String?,
        bedtime: DateTime.parse(json['bedtime'] as String),
        wakeTime: DateTime.parse(json['wake_time'] as String),
      );
}
