import 'dart:io';
import 'package:health/health.dart';

/// iOS HealthKit과 연동하여 수면 데이터를 관리하는 서비스 클래스
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  /// Health 플러그인 인스턴스
  final Health _health = Health();

  /// 요청할 건강 데이터 타입 목록
  static const List<HealthDataType> _healthDataTypes = [
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  /// iOS 권한 체크에 사용할 최소 권한 타입 (하나만 승인되어도 수면 데이터 조회 가능)
  List<HealthDataType> _permissionTypes() {
    if (Platform.isIOS) {
      // iOS는 Sleep 하나의 권한 팝업으로 관리되므로 대표 타입 1개만 검사
      return const [HealthDataType.SLEEP_ASLEEP];
    }
    return _healthDataTypes;
  }

  /// 권한 요청 및 설정 (읽기 권한 명시)
  Future<bool> requestHealthPermissions() async {
    try {
      final List<HealthDataType> typesForPermission = _permissionTypes();
      final List<HealthDataAccess> permissions =
          List<HealthDataAccess>.filled(typesForPermission.length, HealthDataAccess.READ);

      final bool has =
          await _health.hasPermissions(typesForPermission, permissions: permissions) ?? false;

      if (has) {
        print('HealthService - ✅ 이미 권한이 존재합니다 (팝업 표시 안 함)');
        return true;
      }

      print('HealthService - 권한 팝업을 띄웁니다...');

      final bool authorized =
          await _health.requestAuthorization(typesForPermission, permissions: permissions);
      
      if (authorized) {
        print('HealthService - ✅ 권한 승인됨');
      } else {
        print('HealthService - ❌ 권한 거부되거나 미승인');
      }
      
      return authorized;
    } catch (error) {
      print('HealthService - 권한 요청 실패: $error');
      return false;
    }
  }

  /// 지정된 기간의 수면 데이터 가져오기
  Future<List<HealthDataPoint>> getSleepData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // 권한 체크 없이 바로 데이터 조회 시도
      // (권한 없으면 예외 발생, 있으면 데이터 반환)
      final List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: _healthDataTypes,
        startTime: startDate,
        endTime: endDate,
      );

      // 중복 제거 및 정렬
      List<HealthDataPoint> filteredData = _health.removeDuplicates(healthData);
      
      print('HealthService - 수면 데이터 조회 성공: ${filteredData.length}건');
      return filteredData;
    } catch (error) {
      print('HealthService - 수면 데이터 조회 실패: $error');
      return [];
    }
  }

  /// 오늘의 수면 데이터 가져오기
  Future<List<HealthDataPoint>> getTodaySleepData() async {
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final DateTime endOfToday = startOfToday.add(const Duration(days: 1));

    return await getSleepData(
      startDate: startOfToday,
      endDate: endOfToday,
    );
  }

  /// 최근 7일간의 수면 데이터 가져오기
  Future<List<HealthDataPoint>> getWeeklySleepData() async {
    final DateTime now = DateTime.now();
    final DateTime weekAgo = now.subtract(const Duration(days: 7));

    return await getSleepData(
      startDate: weekAgo,
      endDate: now,
    );
  }

  /// 수면 데이터를 서버 전송용 형태로 변환
  Map<String, dynamic> convertSleepDataToJson(List<HealthDataPoint> sleepData) {
    final Map<String, List<Map<String, dynamic>>> categorizedData = {};

    for (final HealthDataPoint dataPoint in sleepData) {
      final String typeKey = dataPoint.type.name;
      
      if (!categorizedData.containsKey(typeKey)) {
        categorizedData[typeKey] = [];
      }

      categorizedData[typeKey]!.add({
        'value': dataPoint.value.toString(),
        'unit': dataPoint.unit.name,
        'dateFrom': dataPoint.dateFrom.toIso8601String(),
        'dateTo': dataPoint.dateTo.toIso8601String(),
        'sourcePlatform': dataPoint.sourcePlatform.name,
        'sourceId': dataPoint.sourceId,
      });
    }

    return {
      'sleepData': categorizedData,
      'recordedAt': DateTime.now().toIso8601String(),
      'dataCount': sleepData.length,
    };
  }

  /// 수면 품질 점수 계산 (100점 만점)
  /// - 수면 시간: 50점 (총 수면 시간이 권장량과 얼마나 가까운지)
  /// - 수면 깊이: 25점 (깊은 수면 N3 및 REM 수면의 비율)
  /// - 수면 회복: 25점 (수면 중 각성 빈도 및 안정성)
  double calculateSleepQualityScore(List<HealthDataPoint> sleepData) {
    if (sleepData.isEmpty) return 0.0;

    // 각 수면 단계별 데이터 분류
    final List<HealthDataPoint> deepSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_DEEP)
        .toList();
    
    final List<HealthDataPoint> lightSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_LIGHT)
        .toList();
    
    final List<HealthDataPoint> remSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_REM)
        .toList();

    final List<HealthDataPoint> asleepSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_ASLEEP)
        .toList();

    final List<HealthDataPoint> awakeSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_AWAKE)
        .toList();

    // 각 수면 단계별 시간 계산 (분 단위)
    double deepSleepMinutes = 0;
    for (final sleep in deepSleep) {
      deepSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    double lightSleepMinutes = 0;
    for (final sleep in lightSleep) {
      lightSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    double remSleepMinutes = 0;
    for (final sleep in remSleep) {
      remSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    double asleepSleepMinutes = 0;
    for (final sleep in asleepSleep) {
      asleepSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    double awakeMinutes = 0;
    for (final sleep in awakeSleep) {
      awakeMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    // 총 수면 시간 계산 (ASLEEP + DEEP + LIGHT + REM)
    double totalSleepMinutes = deepSleepMinutes + lightSleepMinutes + remSleepMinutes + asleepSleepMinutes;

    if (totalSleepMinutes == 0) return 0.0;

    // ============================================
    // 1. 수면 시간 점수 (50점 만점)
    // ============================================
    // 권장 수면 시간: 7-9시간 (420-540분)
    double timeScore = 0;
    final double totalSleepHours = totalSleepMinutes / 60;
    
    if (totalSleepHours >= 7 && totalSleepHours <= 9) {
      // 이상적인 범위: 만점
      timeScore = 50;
    } else if (totalSleepHours >= 6 && totalSleepHours < 7) {
      // 6-7시간: 40-50점 (선형 보간)
      timeScore = 40 + ((totalSleepHours - 6) * 10);
    } else if (totalSleepHours > 9 && totalSleepHours <= 10) {
      // 9-10시간: 40-50점 (선형 보간)
      timeScore = 50 - ((totalSleepHours - 9) * 10);
    } else if (totalSleepHours >= 5 && totalSleepHours < 6) {
      // 5-6시간: 25-40점
      timeScore = 25 + ((totalSleepHours - 5) * 15);
    } else if (totalSleepHours > 10 && totalSleepHours <= 11) {
      // 10-11시간: 25-40점
      timeScore = 40 - ((totalSleepHours - 10) * 15);
    } else if (totalSleepHours >= 4 && totalSleepHours < 5) {
      // 4-5시간: 10-25점
      timeScore = 10 + ((totalSleepHours - 4) * 15);
    } else if (totalSleepHours < 4) {
      // 4시간 미만: 0-10점
      timeScore = (totalSleepHours / 4) * 10;
    } else {
      // 11시간 초과: 10-25점
      timeScore = 25 - ((totalSleepHours - 11).clamp(0, 2) * 7.5);
    }

    // ============================================
    // 2. 수면 깊이 점수 (25점 만점)
    // ============================================
    // 깊은 수면(N3) 비율: 13-23% 이상적 (평균 15-20%)
    // REM 수면 비율: 20-25% 이상적
    double depthScore = 0;
    
    final double deepSleepRatio = (deepSleepMinutes / totalSleepMinutes) * 100;
    final double remSleepRatio = (remSleepMinutes / totalSleepMinutes) * 100;

    // 깊은 수면 점수 (12.5점 만점)
    double deepScore = 0;
    if (deepSleepRatio >= 15 && deepSleepRatio <= 20) {
      deepScore = 12.5;
    } else if (deepSleepRatio >= 13 && deepSleepRatio < 15) {
      deepScore = 10 + ((deepSleepRatio - 13) / 2 * 2.5);
    } else if (deepSleepRatio > 20 && deepSleepRatio <= 23) {
      deepScore = 12.5 - ((deepSleepRatio - 20) / 3 * 2.5);
    } else if (deepSleepRatio >= 10 && deepSleepRatio < 13) {
      deepScore = 5 + ((deepSleepRatio - 10) / 3 * 5);
    } else if (deepSleepRatio < 10) {
      deepScore = (deepSleepRatio / 10) * 5;
    } else {
      deepScore = 5;
    }

    // REM 수면 점수 (12.5점 만점)
    double remScore = 0;
    if (remSleepRatio >= 20 && remSleepRatio <= 25) {
      remScore = 12.5;
    } else if (remSleepRatio >= 15 && remSleepRatio < 20) {
      remScore = 10 + ((remSleepRatio - 15) / 5 * 2.5);
    } else if (remSleepRatio > 25 && remSleepRatio <= 30) {
      remScore = 12.5 - ((remSleepRatio - 25) / 5 * 2.5);
    } else if (remSleepRatio >= 10 && remSleepRatio < 15) {
      remScore = 5 + ((remSleepRatio - 10) / 5 * 5);
    } else if (remSleepRatio < 10) {
      remScore = (remSleepRatio / 10) * 5;
    } else {
      remScore = 5;
    }

    depthScore = deepScore + remScore;

    // ============================================
    // 3. 수면 회복 점수 (25점 만점)
    // ============================================
    // 수면 중 각성 시간과 빈도를 기반으로 평가
    double restorationScore = 0;
    
    // 각성 시간 비율
    final double awakeRatio = (awakeMinutes / (totalSleepMinutes + awakeMinutes)) * 100;
    
    // 각성 빈도 (각성 세그먼트 개수)
    final int awakeCount = awakeSleep.length;

    // 각성 시간 비율 점수 (15점 만점)
    double awakeTimeScore = 0;
    if (awakeRatio <= 5) {
      // 5% 이하: 이상적
      awakeTimeScore = 15;
    } else if (awakeRatio <= 10) {
      // 5-10%: 양호
      awakeTimeScore = 15 - ((awakeRatio - 5) * 1);
    } else if (awakeRatio <= 15) {
      // 10-15%: 보통
      awakeTimeScore = 10 - ((awakeRatio - 10) * 1);
    } else if (awakeRatio <= 20) {
      // 15-20%: 나쁨
      awakeTimeScore = 5 - ((awakeRatio - 15) * 0.5);
    } else {
      // 20% 초과: 매우 나쁨
      awakeTimeScore = 0;
    }

    // 각성 빈도 점수 (10점 만점)
    double awakeFrequencyScore = 0;
    if (awakeCount == 0) {
      awakeFrequencyScore = 10;
    } else if (awakeCount <= 2) {
      awakeFrequencyScore = 10 - (awakeCount * 1);
    } else if (awakeCount <= 5) {
      awakeFrequencyScore = 8 - ((awakeCount - 2) * 1.5);
    } else if (awakeCount <= 10) {
      awakeFrequencyScore = 3 - ((awakeCount - 5) * 0.4);
    } else {
      awakeFrequencyScore = 0;
    }

    restorationScore = awakeTimeScore + awakeFrequencyScore;

    // ============================================
    // 최종 점수 계산
    // ============================================
    final double finalScore = (timeScore + depthScore + restorationScore).clamp(0, 100);

    return finalScore;
  }

  /// 건강 앱 연결 상태 확인 (실제 데이터 조회로 확인)
  Future<bool> isHealthAppAvailable() async {
    try {
      // hasPermissions는 iOS에서 정확하지 않을 수 있으므로
      // 실제 데이터 조회 시도로 권한 여부를 판단
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      
      try {
        final List<HealthDataPoint> testData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP],
          startTime: yesterday,
          endTime: now,
        );
        
        // 데이터 조회가 성공하면 권한 있음 (데이터 없어도 조회 자체는 성공)
        print('HealthService - ✅ 권한 있음 (데이터 조회 성공, ${testData.length}건)');
        return true;
      } catch (e) {
        // 권한 없으면 예외 발생
        print('HealthService - ❌ 권한 없음 (데이터 조회 실패: $e)');
        return false;
      }
    } catch (error) {
      print('HealthService - 건강 앱 연결 상태 확인 실패: $error');
      return false;
    }
  }
}
