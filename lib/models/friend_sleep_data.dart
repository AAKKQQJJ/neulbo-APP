class FriendSleepData {
  final String friendId;
  final String friendUsername;
  final String? friendProfileImage;
  final FriendPrivacyInfo privacyInfo;
  final FriendSleepStatistics statistics;
  final List<FriendSleepScore> recentScores;

  FriendSleepData({
    required this.friendId,
    required this.friendUsername,
    this.friendProfileImage,
    required this.privacyInfo,
    required this.statistics,
    required this.recentScores,
  });

  factory FriendSleepData.fromJson(Map<String, dynamic> json) {
    return FriendSleepData(
      friendId: json['friendId'] as String,
      friendUsername: json['friendUsername'] as String,
      friendProfileImage: json['friendProfileImage'] as String?,
      privacyInfo: FriendPrivacyInfo.fromJson(json['privacyInfo'] as Map<String, dynamic>),
      statistics: FriendSleepStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
      recentScores: (json['sleepScores'] as List? ?? [])  // 서버 필드명: sleepScores
          .map((score) => FriendSleepScore.fromJson(score as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendId': friendId,
      'friendUsername': friendUsername,
      'friendProfileImage': friendProfileImage,
      'privacyInfo': privacyInfo.toJson(),
      'statistics': statistics.toJson(),
      'recentScores': recentScores.map((score) => score.toJson()).toList(),
    };
  }
}

class FriendPrivacyInfo {
  final bool canSeeDetailedScores;
  final bool canSeeNotes;
  final bool showsInLeaderboard;

  FriendPrivacyInfo({
    required this.canSeeDetailedScores,
    required this.canSeeNotes,
    required this.showsInLeaderboard,
  });

  factory FriendPrivacyInfo.fromJson(Map<String, dynamic> json) {
    return FriendPrivacyInfo(
      canSeeDetailedScores: json['canSeeDetailedScores'] as bool,
      canSeeNotes: json['canSeeNotes'] as bool,
      showsInLeaderboard: json['showsInLeaderboard'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canSeeDetailedScores': canSeeDetailedScores,
      'canSeeNotes': canSeeNotes,
      'showsInLeaderboard': showsInLeaderboard,
    };
  }
}

class FriendSleepStatistics {
  final double averageSleepScore;
  final double highestSleepScore;
  final double lowestSleepScore;
  final int consecutiveRecordingDays;

  FriendSleepStatistics({
    required this.averageSleepScore,
    required this.highestSleepScore,
    required this.lowestSleepScore,
    required this.consecutiveRecordingDays,
  });

  factory FriendSleepStatistics.fromJson(Map<String, dynamic> json) {
    return FriendSleepStatistics(
      averageSleepScore: (json['averageScore'] as num? ?? 0).toDouble(),
      highestSleepScore: (json['maxScore'] as num? ?? 0).toDouble(),
      lowestSleepScore: (json['minScore'] as num? ?? 0).toDouble(),
      consecutiveRecordingDays: json['streakDays'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageSleepScore': averageSleepScore,
      'highestSleepScore': highestSleepScore,
      'lowestSleepScore': lowestSleepScore,
      'consecutiveRecordingDays': consecutiveRecordingDays,
    };
  }
}

class FriendSleepScore {
  final String sleepRecordId;
  final DateTime date;
  final double sleepScore;
  final int totalSleepDurationMinutes;
  final int deepSleepDurationMinutes;
  final int remSleepDurationMinutes;
  final String? sleepNotes;

  FriendSleepScore({
    required this.sleepRecordId,
    required this.date,
    required this.sleepScore,
    required this.totalSleepDurationMinutes,
    required this.deepSleepDurationMinutes,
    required this.remSleepDurationMinutes,
    this.sleepNotes,
  });

  factory FriendSleepScore.fromJson(Map<String, dynamic> json) {
    return FriendSleepScore(
      sleepRecordId: json['sleepRecordId'] as String,
      date: DateTime.parse(json['date'] as String),
      sleepScore: (json['sleepScore'] as num).toDouble(),
      totalSleepDurationMinutes: json['totalSleepDurationMinutes'] as int,
      deepSleepDurationMinutes: json['deepSleepDurationMinutes'] as int,
      remSleepDurationMinutes: json['remSleepDurationMinutes'] as int,
      sleepNotes: json['sleepNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleepRecordId': sleepRecordId,
      'date': date.toIso8601String(),
      'sleepScore': sleepScore,
      'totalSleepDurationMinutes': totalSleepDurationMinutes,
      'deepSleepDurationMinutes': deepSleepDurationMinutes,
      'remSleepDurationMinutes': remSleepDurationMinutes,
      'sleepNotes': sleepNotes,
    };
  }
}