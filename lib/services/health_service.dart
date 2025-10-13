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
