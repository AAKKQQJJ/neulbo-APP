import 'dart:math';

// MARK: - 움직임 데이터 (가속도계)
class AccelerometerData {
  final DateTime timestamp;                // 측정 시점
  final double relativeTime;               // 수면 시작 대비 상대 시간 (초)
  final double x;                          // X축 가속도 (g)
  final double y;                          // Y축 가속도 (g)
  final double z;                          // Z축 가속도 (g)

  const AccelerometerData({
    required this.timestamp,
    required this.relativeTime,
    required this.x,
    required this.y,
    required this.z,
  });

  /// 팩토리 생성자: 수면 시작 시간을 기준으로 상대 시간 자동 계산
  factory AccelerometerData.fromSleepStart({
    required DateTime timestamp,
    required DateTime sleepStartTime,
    required double x,
    required double y,
    required double z,
  }) {
    return AccelerometerData(
      timestamp: timestamp,
      relativeTime: timestamp.difference(sleepStartTime).inSeconds.toDouble(),
      x: x,
      y: y,
      z: z,
    );
  }

  /// 움직임 크기 계산 (magnitude)
  double get magnitude => sqrt(x * x + y * y + z * z);

  /// API 전송용 JSON (API 명세서 필드명 사용)
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'x': x,
      'y': y,
      'z': z,
    };
  }

  /// 로컬 저장용 JSON (모든 필드 포함)
  Map<String, dynamic> toFullJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'relativeTime': relativeTime,
      'x': x,
      'y': y,
      'z': z,
    };
  }

  /// JSON에서 복원
  factory AccelerometerData.fromJson(Map<String, dynamic> json) {
    return AccelerometerData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      relativeTime: (json['relativeTime'] as num?)?.toDouble() ?? 0.0,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }
}

// MARK: - 소리 데이터 (오디오) - Swift SoundData와 동일
class AudioData {
  final DateTime timestamp;                // 측정 시점
  final double relativeTime;               // 수면 시작 대비 상대 시간 (초)
  final double amplitude;                  // 진폭 (0.0 ~ 1.0)
  final List<double> frequencyBands;       // 주파수 대역 (8개)

  const AudioData({
    required this.timestamp,
    required this.relativeTime,
    required this.amplitude,
    required this.frequencyBands,
  });

  /// dB 레벨 계산 (로컬 저장용)
  double get decibelLevel {
    if (amplitude <= 0) return -80.0;
    // amplitude (0.0-1.0)를 dB로 변환
    return 20 * (amplitude * 100).clamp(0.1, 100).toDouble();
  }

  /// 팩토리 생성자: 수면 시작 시간을 기준으로 상대 시간 자동 계산
  factory AudioData.fromSleepStart({
    required DateTime timestamp,
    required DateTime sleepStartTime,
    required double amplitude,
    required List<double> frequencyBands,
  }) {
    return AudioData(
      timestamp: timestamp,
      relativeTime: timestamp.difference(sleepStartTime).inSeconds.toDouble(),
      amplitude: amplitude,
      frequencyBands: frequencyBands,
    );
  }

  /// API 전송용 JSON (API 명세서 필드명 사용)
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'amplitude': amplitude,
      'frequency_bands': frequencyBands,
    };
  }

  /// 로컬 저장용 JSON (모든 데이터 포함)
  Map<String, dynamic> toFullJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'relativeTime': relativeTime,
      'amplitude': amplitude,
      'frequency_bands': frequencyBands,
      'decibelLevel': decibelLevel, // 계산된 값
    };
  }

  /// JSON에서 복원 (이전 데이터 호환성 지원)
  factory AudioData.fromJson(Map<String, dynamic> json) {
    // 이전 데이터 형식 지원 (decibelLevel만 있는 경우)
    if (json.containsKey('decibelLevel') && !json.containsKey('amplitude')) {
      final decibelLevel = (json['decibelLevel'] as num).toDouble();
      // dB를 amplitude로 역변환 (대략적)
      final amplitude = (decibelLevel / 20.0 / 100.0).clamp(0.0, 1.0);
      // 기본 frequency_bands 생성
      final frequencyBands = List.generate(8, (i) => amplitude * (1.0 - i * 0.1));
      
      return AudioData(
        timestamp: DateTime.parse(json['timestamp'] as String),
        relativeTime: (json['relativeTime'] as num?)?.toDouble() ?? 0.0,
        amplitude: amplitude,
        frequencyBands: frequencyBands,
      );
    }
    
    // 새 데이터 형식 (amplitude와 frequency_bands 있는 경우)
    return AudioData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      relativeTime: (json['relativeTime'] as num?)?.toDouble() ?? 0.0,
      amplitude: (json['amplitude'] as num).toDouble(),
      frequencyBands: (json['frequency_bands'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

// MARK: - 수면 녹음 데이터 (전체 세션)
class SleepRecordingData {
  final String sessionId;                  // 세션 구분용 ID
  final DateTime startTime;                // 수면 시작 시간
  final DateTime endTime;                  // 수면 종료 시간
  final double duration;                   // 총 수면 시간 (초)
  final List<AccelerometerData> accelerometerData;  // 움직임 데이터
  final List<AudioData> audioData;         // 소리 데이터
  final SleepAnalysisResult? analysisResult;  // ML 분석 결과 (선택적)

  const SleepRecordingData({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.accelerometerData,
    required this.audioData,
    this.analysisResult,
  });

  /// 팩토리 생성자: 시작/종료 시간으로부터 자동 계산
  factory SleepRecordingData.create({
    required DateTime startTime,
    required DateTime endTime,
    required List<AccelerometerData> accelerometerData,
    required List<AudioData> audioData,
    SleepAnalysisResult? analysisResult,
  }) {
    return SleepRecordingData(
      sessionId: _generateSessionId(),
      startTime: startTime,
      endTime: endTime,
      duration: endTime.difference(startTime).inSeconds.toDouble(),
      accelerometerData: accelerometerData,
      audioData: audioData,
      analysisResult: analysisResult,
    );
  }

  /// 세션 ID 생성
  static String _generateSessionId() {
    final now = DateTime.now();
    return 'sleep_${now.millisecondsSinceEpoch}_${now.microsecond}';
  }

  /// 데이터 유효성 검사
  bool get isValid {
    return duration > 60 && 
           accelerometerData.isNotEmpty && 
           audioData.isNotEmpty;
  }

  /// 데이터 품질 점수 계산
  String get dataQuality {
    if (!isValid) return '❌ 데이터 부족';

    final motionDensity = accelerometerData.length / duration;
    final soundDensity = audioData.length / duration;

    if (motionDensity > 0.1 && soundDensity > 0.5) {
      return '✅ 양질의 데이터';
    } else if (motionDensity > 0.05 && soundDensity > 0.2) {
      return '⚠️ 보통 품질';
    } else {
      return '⚠️ 데이터 밀도 부족';
    }
  }

  /// 데이터 요약 정보
  String get summary {
    final hours = (duration / 3600).floor();
    final minutes = ((duration % 3600) / 60).floor();

    final motionMagnitudes = accelerometerData.map((d) => d.magnitude).toList();
    final avgMotion = motionMagnitudes.isEmpty
        ? 0.0
        : motionMagnitudes.reduce((a, b) => a + b) / motionMagnitudes.length;
    final maxMotion = motionMagnitudes.isEmpty ? 0.0 : motionMagnitudes.reduce((a, b) => a > b ? a : b);

    final decibelLevels = audioData.map((d) => d.decibelLevel).toList();
    final avgSound = decibelLevels.isEmpty
        ? 0.0
        : decibelLevels.reduce((a, b) => a + b) / decibelLevels.length;
    final maxSound = decibelLevels.isEmpty ? 0.0 : decibelLevels.reduce((a, b) => a > b ? a : b);

    return '''
📊 수면 데이터 요약
═══════════════════════════════════════
🆔 세션 ID: $sessionId
⏰ 수면 시간: ${hours}시간 ${minutes}분
📅 시작: ${_formatDateTime(startTime)}
📅 종료: ${_formatDateTime(endTime)}

📱 움직임 데이터: ${accelerometerData.length}개 포인트
📊 평균 움직임: ${avgMotion.toStringAsFixed(3)}g
📊 최대 움직임: ${maxMotion.toStringAsFixed(3)}g

🔊 소리 데이터: ${audioData.length}개 포인트
📊 평균 소음: ${avgSound.toStringAsFixed(1)}dB
📊 최대 소음: ${maxSound.toStringAsFixed(1)}dB

📈 데이터 품질: $dataQuality
═══════════════════════════════════════
    ''';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// API 전송용 JSON (API 명세서 필드명)
  /// 
  /// [userId]를 선택적으로 받아서 포함시킵니다.
  /// API 명세서 v3에서는 JWT에서 자동 추출되어야 하지만,
  /// 백엔드가 업데이트 전까지는 명시적으로 전달해야 합니다.
  Map<String, dynamic> toJson({String? userId}) {
    final Map<String, dynamic> json = {
      'recording_start': startTime.toUtc().toIso8601String(),
      'recording_end': endTime.toUtc().toIso8601String(),
      'accelerometer_data': accelerometerData.map((d) => d.toJson()).toList(),
      'audio_data': audioData.map((d) => d.toJson()).toList(),
    };
    
    // user_id가 제공된 경우에만 추가
    if (userId != null && userId.isNotEmpty) {
      json['user_id'] = userId;
    }
    
    return json;
  }

  /// 로컬 저장용 JSON (모든 필드 포함)
  Map<String, dynamic> toFullJson() {
    final Map<String, dynamic> json = {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': duration,
      'accelerometerData': accelerometerData.map((d) => d.toFullJson()).toList(),
      'audioData': audioData.map((d) => d.toFullJson()).toList(),
    };
    
    // ML 분석 결과가 있으면 함께 저장
    if (analysisResult != null) {
      json['analysisResult'] = analysisResult!.toJson();
    }
    
    return json;
  }

  /// JSON에서 복원
  factory SleepRecordingData.fromJson(Map<String, dynamic> json) {
    SleepAnalysisResult? analysisResult;
    
    // ML 분석 결과가 저장되어 있으면 복원
    if (json.containsKey('analysisResult') && json['analysisResult'] != null) {
      try {
        analysisResult = SleepAnalysisResult.fromJson(
          json['analysisResult'] as Map<String, dynamic>,
        );
      } catch (e) {
        print('⚠️ ML 분석 결과 복원 실패: $e');
      }
    }
    
    return SleepRecordingData(
      sessionId: json['sessionId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      duration: (json['duration'] as num).toDouble(),
      accelerometerData: (json['accelerometerData'] as List)
          .map((e) => AccelerometerData.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioData: (json['audioData'] as List)
          .map((e) => AudioData.fromJson(e as Map<String, dynamic>))
          .toList(),
      analysisResult: analysisResult,
    );
  }
  
  /// ML 분석 결과를 추가한 새로운 SleepRecordingData 생성
  SleepRecordingData withAnalysisResult(SleepAnalysisResult result) {
    return SleepRecordingData(
      sessionId: sessionId,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      accelerometerData: accelerometerData,
      audioData: audioData,
      analysisResult: result,
    );
  }
}

class SleepAnalysisResult {
  final String userId;
  final String analysisId;
  final String analysisTimestamp;
  final String recordingStart;
  final String recordingEnd;
  final List<StageInterval> stageIntervals;
  final SummaryStatistics summaryStatistics;
  final String modelVersion;
  final double dataQualityScore;

  const SleepAnalysisResult({
    required this.userId,
    required this.analysisId,
    required this.analysisTimestamp,
    required this.recordingStart,
    required this.recordingEnd,
    required this.stageIntervals,
    required this.summaryStatistics,
    required this.modelVersion,
    required this.dataQualityScore,
  });

  factory SleepAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SleepAnalysisResult(
      userId: json['user_id'] as String,
      analysisId: json['analysis_id'] as String,
      analysisTimestamp: json['analysis_timestamp'] as String,
      recordingStart: json['recording_start'] as String,
      recordingEnd: json['recording_end'] as String,
      stageIntervals: (json['stage_intervals'] as List)
          .map((e) => StageInterval.fromJson(e as Map<String, dynamic>))
          .toList(),
      summaryStatistics: SummaryStatistics.fromJson(
        json['summary_statistics'] as Map<String, dynamic>,
      ),
      modelVersion: json['model_version'] as String,
      dataQualityScore: (json['data_quality_score'] as num).toDouble(),
    );
  }
  
  /// JSON 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'analysis_id': analysisId,
      'analysis_timestamp': analysisTimestamp,
      'recording_start': recordingStart,
      'recording_end': recordingEnd,
      'stage_intervals': stageIntervals.map((e) => e.toJson()).toList(),
      'summary_statistics': summaryStatistics.toJson(),
      'model_version': modelVersion,
      'data_quality_score': dataQualityScore,
    };
  }
}

class StageInterval {
  final String startTime;
  final String endTime;
  final String stage;
  final double confidence;

  const StageInterval({
    required this.startTime,
    required this.endTime,
    required this.stage,
    required this.confidence,
  });

  factory StageInterval.fromJson(Map<String, dynamic> json) {
    return StageInterval(
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      stage: json['stage'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime,
      'end_time': endTime,
      'stage': stage,
      'confidence': confidence,
    };
  }
}

class SummaryStatistics {
  final int totalSleepTime;
  final double sleepEfficiency;
  final int sleepOnsetLatency;
  final int wakeAfterSleepOnset;
  final int wakeTime;
  final int n1Time;
  final int n2Time;
  final int n3Time;
  final int remTime;
  final double wakePercentage;
  final double n1Percentage;
  final double n2Percentage;
  final double n3Percentage;
  final double remPercentage;

  const SummaryStatistics({
    required this.totalSleepTime,
    required this.sleepEfficiency,
    required this.sleepOnsetLatency,
    required this.wakeAfterSleepOnset,
    required this.wakeTime,
    required this.n1Time,
    required this.n2Time,
    required this.n3Time,
    required this.remTime,
    required this.wakePercentage,
    required this.n1Percentage,
    required this.n2Percentage,
    required this.n3Percentage,
    required this.remPercentage,
  });

  factory SummaryStatistics.fromJson(Map<String, dynamic> json) {
    return SummaryStatistics(
      totalSleepTime: json['total_sleep_time'] as int,
      sleepEfficiency: (json['sleep_efficiency'] as num).toDouble(),
      sleepOnsetLatency: json['sleep_onset_latency'] as int,
      wakeAfterSleepOnset: json['wake_after_sleep_onset'] as int,
      wakeTime: json['wake_time'] as int,
      n1Time: json['n1_time'] as int,
      n2Time: json['n2_time'] as int,
      n3Time: json['n3_time'] as int,
      remTime: json['rem_time'] as int,
      wakePercentage: (json['wake_percentage'] as num).toDouble(),
      n1Percentage: (json['n1_percentage'] as num).toDouble(),
      n2Percentage: (json['n2_percentage'] as num).toDouble(),
      n3Percentage: (json['n3_percentage'] as num).toDouble(),
      remPercentage: (json['rem_percentage'] as num).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'total_sleep_time': totalSleepTime,
      'sleep_efficiency': sleepEfficiency,
      'sleep_onset_latency': sleepOnsetLatency,
      'wake_after_sleep_onset': wakeAfterSleepOnset,
      'wake_time': wakeTime,
      'n1_time': n1Time,
      'n2_time': n2Time,
      'n3_time': n3Time,
      'rem_time': remTime,
      'wake_percentage': wakePercentage,
      'n1_percentage': n1Percentage,
      'n2_percentage': n2Percentage,
      'n3_percentage': n3Percentage,
      'rem_percentage': remPercentage,
    };
  }
}

