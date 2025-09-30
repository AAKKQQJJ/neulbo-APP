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

  /// 권한 요청 및 설정
  Future<bool> requestHealthPermissions() async {
    try {
      // 건강 앱이 사용 가능한지 확인
      final bool isAvailable = await Health().hasPermissions(_healthDataTypes) ?? false;
      
      if (!isAvailable) {
        // 권한 요청
        final bool isAuthorized = await Health().requestAuthorization(_healthDataTypes);
        return isAuthorized;
      }
      
      return true;
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
      // 권한 확인
      final bool hasPermissions = await Health().hasPermissions(_healthDataTypes) ?? false;
      
      if (!hasPermissions) {
        print('HealthService - 건강 데이터 접근 권한이 없습니다.');
        return [];
      }

      // 수면 데이터 조회
      final List<HealthDataPoint> healthData = await Health().getHealthDataFromTypes(
        types: _healthDataTypes,
        startTime: startDate,
        endTime: endDate,
      );

      // 중복 제거 및 정렬
      List<HealthDataPoint> filteredData = Health().removeDuplicates(healthData);
      
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

  /// 수면 품질 점수 계산 (간단한 예시)
  double calculateSleepQualityScore(List<HealthDataPoint> sleepData) {
    if (sleepData.isEmpty) return 0.0;

    // 깊은 잠과 REM 수면 비율을 기반으로 점수 계산
    final List<HealthDataPoint> deepSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_DEEP)
        .toList();
    
    final List<HealthDataPoint> remSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_REM)
        .toList();

    final List<HealthDataPoint> totalSleep = sleepData
        .where((data) => data.type == HealthDataType.SLEEP_ASLEEP)
        .toList();

    if (totalSleep.isEmpty) return 0.0;

    // 총 수면 시간 계산 (분 단위)
    double totalSleepMinutes = 0;
    for (final sleep in totalSleep) {
      totalSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    // 깊은 잠 시간 계산
    double deepSleepMinutes = 0;
    for (final sleep in deepSleep) {
      deepSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    // REM 수면 시간 계산
    double remSleepMinutes = 0;
    for (final sleep in remSleep) {
      remSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
    }

    // 점수 계산 (0-100)
    final double deepSleepRatio = deepSleepMinutes / totalSleepMinutes;
    final double remSleepRatio = remSleepMinutes / totalSleepMinutes;
    
    // 이상적인 비율: 깊은 잠 15-20%, REM 20-25%
    final double deepScore = (deepSleepRatio * 100).clamp(0, 100);
    final double remScore = (remSleepRatio * 100).clamp(0, 100);
    
    return ((deepScore + remScore) / 2).clamp(0, 100);
  }

  /// 건강 앱 연결 상태 확인
  Future<bool> isHealthAppAvailable() async {
    try {
      return await Health().hasPermissions(_healthDataTypes) ?? false;
    } catch (error) {
      print('HealthService - 건강 앱 연결 상태 확인 실패: $error');
      return false;
    }
  }
}
