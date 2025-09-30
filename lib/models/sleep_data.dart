/// 수면 데이터 모델 클래스
class SleepData {
  final String id;
  final DateTime sleepDate;
  final DateTime bedTime;
  final DateTime sleepTime;
  final DateTime wakeTime;
  final Duration totalSleepDuration;
  final Duration deepSleepDuration;
  final Duration lightSleepDuration;
  final Duration remSleepDuration;
  final Duration awakeTimeDuration;
  final double sleepQualityScore;
  final String sourceId;
  final DateTime recordedAt;

  const SleepData({
    required this.id,
    required this.sleepDate,
    required this.bedTime,
    required this.sleepTime,
    required this.wakeTime,
    required this.totalSleepDuration,
    required this.deepSleepDuration,
    required this.lightSleepDuration,
    required this.remSleepDuration,
    required this.awakeTimeDuration,
    required this.sleepQualityScore,
    required this.sourceId,
    required this.recordedAt,
  });

  /// JSON으로부터 SleepData 인스턴스 생성
  factory SleepData.fromJson(Map<String, dynamic> json) {
    return SleepData(
      id: json['id'] as String,
      sleepDate: DateTime.parse(json['sleepDate'] as String),
      bedTime: DateTime.parse(json['bedTime'] as String),
      sleepTime: DateTime.parse(json['sleepTime'] as String),
      wakeTime: DateTime.parse(json['wakeTime'] as String),
      totalSleepDuration: Duration(minutes: json['totalSleepMinutes'] as int),
      deepSleepDuration: Duration(minutes: json['deepSleepMinutes'] as int),
      lightSleepDuration: Duration(minutes: json['lightSleepMinutes'] as int),
      remSleepDuration: Duration(minutes: json['remSleepMinutes'] as int),
      awakeTimeDuration: Duration(minutes: json['awakeTimeMinutes'] as int),
      sleepQualityScore: (json['sleepQualityScore'] as num).toDouble(),
      sourceId: json['sourceId'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  /// SleepData를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sleepDate': sleepDate.toIso8601String(),
      'bedTime': bedTime.toIso8601String(),
      'sleepTime': sleepTime.toIso8601String(),
      'wakeTime': wakeTime.toIso8601String(),
      'totalSleepMinutes': totalSleepDuration.inMinutes,
      'deepSleepMinutes': deepSleepDuration.inMinutes,
      'lightSleepMinutes': lightSleepDuration.inMinutes,
      'remSleepMinutes': remSleepDuration.inMinutes,
      'awakeTimeMinutes': awakeTimeDuration.inMinutes,
      'sleepQualityScore': sleepQualityScore,
      'sourceId': sourceId,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  /// 수면 시간을 시간:분 형식으로 반환
  String get formattedTotalSleepTime {
    final int hours = totalSleepDuration.inHours;
    final int minutes = totalSleepDuration.inMinutes % 60;
    return '${hours}시간 ${minutes}분';
  }

  /// 취침 시간을 12시간 형식으로 반환
  String get formattedBedTime {
    final int hour = bedTime.hour > 12 ? bedTime.hour - 12 : bedTime.hour;
    final String period = bedTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${bedTime.minute.toString().padLeft(2, '0')} $period';
  }

  /// 기상 시간을 12시간 형식으로 반환
  String get formattedWakeTime {
    final int hour = wakeTime.hour > 12 ? wakeTime.hour - 12 : wakeTime.hour;
    final String period = wakeTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${wakeTime.minute.toString().padLeft(2, '0')} $period';
  }

  /// 수면 품질 등급 반환 (A~F)
  String get sleepQualityGrade {
    if (sleepQualityScore >= 90) return 'A';
    if (sleepQualityScore >= 80) return 'B';
    if (sleepQualityScore >= 70) return 'C';
    if (sleepQualityScore >= 60) return 'D';
    if (sleepQualityScore >= 50) return 'E';
    return 'F';
  }

  /// 수면 효율성 계산 (실제 수면 시간 / 침대에 있던 시간)
  double get sleepEfficiency {
    final Duration timeInBed = wakeTime.difference(bedTime);
    if (timeInBed.inMinutes == 0) return 0.0;
    
    return (totalSleepDuration.inMinutes / timeInBed.inMinutes) * 100;
  }

  /// 깊은 잠 비율 계산
  double get deepSleepPercentage {
    if (totalSleepDuration.inMinutes == 0) return 0.0;
    return (deepSleepDuration.inMinutes / totalSleepDuration.inMinutes) * 100;
  }

  /// REM 수면 비율 계산
  double get remSleepPercentage {
    if (totalSleepDuration.inMinutes == 0) return 0.0;
    return (remSleepDuration.inMinutes / totalSleepDuration.inMinutes) * 100;
  }

  /// 얕은 잠 비율 계산
  double get lightSleepPercentage {
    if (totalSleepDuration.inMinutes == 0) return 0.0;
    return (lightSleepDuration.inMinutes / totalSleepDuration.inMinutes) * 100;
  }

  /// 객체 복사 메서드
  SleepData copyWith({
    String? id,
    DateTime? sleepDate,
    DateTime? bedTime,
    DateTime? sleepTime,
    DateTime? wakeTime,
    Duration? totalSleepDuration,
    Duration? deepSleepDuration,
    Duration? lightSleepDuration,
    Duration? remSleepDuration,
    Duration? awakeTimeDuration,
    double? sleepQualityScore,
    String? sourceId,
    DateTime? recordedAt,
  }) {
    return SleepData(
      id: id ?? this.id,
      sleepDate: sleepDate ?? this.sleepDate,
      bedTime: bedTime ?? this.bedTime,
      sleepTime: sleepTime ?? this.sleepTime,
      wakeTime: wakeTime ?? this.wakeTime,
      totalSleepDuration: totalSleepDuration ?? this.totalSleepDuration,
      deepSleepDuration: deepSleepDuration ?? this.deepSleepDuration,
      lightSleepDuration: lightSleepDuration ?? this.lightSleepDuration,
      remSleepDuration: remSleepDuration ?? this.remSleepDuration,
      awakeTimeDuration: awakeTimeDuration ?? this.awakeTimeDuration,
      sleepQualityScore: sleepQualityScore ?? this.sleepQualityScore,
      sourceId: sourceId ?? this.sourceId,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SleepData &&
        other.id == id &&
        other.sleepDate == sleepDate &&
        other.bedTime == bedTime &&
        other.sleepTime == sleepTime &&
        other.wakeTime == wakeTime &&
        other.totalSleepDuration == totalSleepDuration &&
        other.deepSleepDuration == deepSleepDuration &&
        other.lightSleepDuration == lightSleepDuration &&
        other.remSleepDuration == remSleepDuration &&
        other.awakeTimeDuration == awakeTimeDuration &&
        other.sleepQualityScore == sleepQualityScore &&
        other.sourceId == sourceId &&
        other.recordedAt == recordedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sleepDate.hashCode ^
        bedTime.hashCode ^
        sleepTime.hashCode ^
        wakeTime.hashCode ^
        totalSleepDuration.hashCode ^
        deepSleepDuration.hashCode ^
        lightSleepDuration.hashCode ^
        remSleepDuration.hashCode ^
        awakeTimeDuration.hashCode ^
        sleepQualityScore.hashCode ^
        sourceId.hashCode ^
        recordedAt.hashCode;
  }

  @override
  String toString() {
    return 'SleepData(id: $id, sleepDate: $sleepDate, totalSleepDuration: $totalSleepDuration, sleepQualityScore: $sleepQualityScore)';
  }
}
