import '../models/sleep_data.dart';
import 'api_service.dart';
import 'health_service.dart';
import 'package:health/health.dart';

/// 수면 데이터를 HealthKit에서 가져와 서버로 전송하는 통합 서비스
class SleepDataService {
  static final SleepDataService _instance = SleepDataService._internal();
  factory SleepDataService() => _instance;
  SleepDataService._internal();

  final HealthService _healthService = HealthService();

  /// 초기 설정 - HealthKit 권한 요청
  Future<bool> initializeHealthKit() async {
    try {
      final bool hasPermissions = await _healthService.requestHealthPermissions();
      
      if (hasPermissions) {
        // 서버에 HealthKit 연동 상태 업데이트
        await ApiService.updateHealthKitStatus(true);
        print('SleepDataService - HealthKit 초기화 완료');
        return true;
      } else {
        await ApiService.updateHealthKitStatus(false);
        print('SleepDataService - HealthKit 권한 거부됨');
        return false;
      }
    } catch (error) {
      print('SleepDataService - HealthKit 초기화 실패: $error');
      await ApiService.updateHealthKitStatus(false);
      return false;
    }
  }

  /// HealthKit에서 수면 데이터를 가져와 SleepData 객체로 변환
  Future<List<SleepData>> fetchAndConvertSleepData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // HealthKit에서 원시 수면 데이터 가져오기
      final List<HealthDataPoint> rawSleepData = await _healthService.getSleepData(
        startDate: startDate,
        endDate: endDate,
      );

      if (rawSleepData.isEmpty) {
        print('SleepDataService - 해당 기간에 수면 데이터가 없습니다.');
        return [];
      }

      // 날짜별로 수면 데이터 그룹핑
      final Map<DateTime, List<HealthDataPoint>> groupedByDate = {};
      
      for (final HealthDataPoint dataPoint in rawSleepData) {
        final DateTime sleepDate = DateTime(
          dataPoint.dateFrom.year,
          dataPoint.dateFrom.month,
          dataPoint.dateFrom.day,
        );
        
        if (!groupedByDate.containsKey(sleepDate)) {
          groupedByDate[sleepDate] = [];
        }
        groupedByDate[sleepDate]!.add(dataPoint);
      }

      // 각 날짜별로 SleepData 객체 생성
      final List<SleepData> sleepDataList = [];
      
      for (final MapEntry<DateTime, List<HealthDataPoint>> entry in groupedByDate.entries) {
        final SleepData? sleepData = _convertToSleepData(entry.key, entry.value);
        if (sleepData != null) {
          sleepDataList.add(sleepData);
        }
      }

      return sleepDataList;
    } catch (error) {
      print('SleepDataService - 수면 데이터 변환 실패: $error');
      return [];
    }
  }

  /// HealthDataPoint 리스트를 SleepData 객체로 변환
  SleepData? _convertToSleepData(DateTime sleepDate, List<HealthDataPoint> dataPoints) {
    try {
      // 수면 타입별로 데이터 분리
      DateTime? bedTime;
      DateTime? sleepTime;
      DateTime? wakeTime;
      Duration totalSleepDuration = Duration.zero;
      Duration deepSleepDuration = Duration.zero;
      Duration lightSleepDuration = Duration.zero;
      Duration remSleepDuration = Duration.zero;
      Duration awakeTimeDuration = Duration.zero;

      for (final HealthDataPoint dataPoint in dataPoints) {
        final Duration duration = dataPoint.dateTo.difference(dataPoint.dateFrom);
        
        switch (dataPoint.type) {
          case HealthDataType.SLEEP_IN_BED:
            bedTime ??= dataPoint.dateFrom;
            wakeTime = dataPoint.dateTo;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            sleepTime ??= dataPoint.dateFrom;
            totalSleepDuration += duration;
            break;
          case HealthDataType.SLEEP_DEEP:
            deepSleepDuration += duration;
            break;
          case HealthDataType.SLEEP_LIGHT:
            lightSleepDuration += duration;
            break;
          case HealthDataType.SLEEP_REM:
            remSleepDuration += duration;
            break;
          case HealthDataType.SLEEP_AWAKE:
            awakeTimeDuration += duration;
            break;
          default:
            break;
        }
      }

      // 필수 데이터 확인
      if (bedTime == null || wakeTime == null || sleepTime == null) {
        print('SleepDataService - 필수 수면 데이터가 누락됨 (날짜: $sleepDate)');
        return null;
      }

      // 수면 품질 점수 계산
      final double qualityScore = _healthService.calculateSleepQualityScore(dataPoints);

      // 고유 ID 생성
      final String id = '${sleepDate.toIso8601String().split('T')[0]}_${DateTime.now().millisecondsSinceEpoch}';

      return SleepData(
        id: id,
        sleepDate: sleepDate,
        bedTime: bedTime,
        sleepTime: sleepTime,
        wakeTime: wakeTime,
        totalSleepDuration: totalSleepDuration,
        deepSleepDuration: deepSleepDuration,
        lightSleepDuration: lightSleepDuration,
        remSleepDuration: remSleepDuration,
        awakeTimeDuration: awakeTimeDuration,
        sleepQualityScore: qualityScore,
        sourceId: dataPoints.isNotEmpty ? dataPoints.first.sourceId : 'unknown',
        recordedAt: DateTime.now(),
      );
    } catch (error) {
      print('SleepDataService - SleepData 변환 실패: $error');
      return null;
    }
  }

  /// 수면 데이터를 서버에 업로드
  Future<bool> uploadSleepDataToServer(List<SleepData> sleepDataList) async {
    try {
      if (sleepDataList.isEmpty) {
        print('SleepDataService - 업로드할 수면 데이터가 없습니다.');
        return true;
      }

      if (sleepDataList.length == 1) {
        // 단일 데이터 업로드
        await ApiService.uploadSleepData(sleepDataList.first);
      } else {
        // 여러 데이터 일괄 업로드
        await ApiService.uploadMultipleSleepData(sleepDataList);
      }

      print('SleepDataService - 수면 데이터 업로드 완료 (${sleepDataList.length}건)');
      return true;
    } catch (error) {
      print('SleepDataService - 수면 데이터 업로드 실패: $error');
      return false;
    }
  }

  /// HealthKit에서 수면 데이터를 가져와 서버에 동기화 (전체 프로세스)
  Future<bool> syncSleepDataWithServer({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('SleepDataService - 수면 데이터 동기화 시작 (${startDate.toIso8601String()} ~ ${endDate.toIso8601String()})');

      // 1. HealthKit 권한 확인
      final bool hasPermissions = await _healthService.isHealthAppAvailable();
      if (!hasPermissions) {
        print('SleepDataService - HealthKit 권한이 없습니다.');
        return false;
      }

      // 2. HealthKit에서 수면 데이터 가져오기
      final List<SleepData> sleepDataList = await fetchAndConvertSleepData(
        startDate: startDate,
        endDate: endDate,
      );

      if (sleepDataList.isEmpty) {
        print('SleepDataService - 동기화할 수면 데이터가 없습니다.');
        return true;
      }

      // 3. 서버에 업로드
      final bool uploadSuccess = await uploadSleepDataToServer(sleepDataList);

      if (uploadSuccess) {
        print('SleepDataService - 수면 데이터 동기화 완료');
        return true;
      } else {
        print('SleepDataService - 수면 데이터 동기화 실패');
        return false;
      }
    } catch (error) {
      print('SleepDataService - 수면 데이터 동기화 중 오류 발생: $error');
      return false;
    }
  }

  /// 오늘의 수면 데이터 동기화
  Future<bool> syncTodaySleepData() async {
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final DateTime endOfToday = startOfToday.add(const Duration(days: 1));

    return await syncSleepDataWithServer(
      startDate: startOfToday,
      endDate: endOfToday,
    );
  }

  /// 최근 7일간의 수면 데이터 동기화
  Future<bool> syncWeeklySleepData() async {
    final DateTime now = DateTime.now();
    final DateTime weekAgo = now.subtract(const Duration(days: 7));

    return await syncSleepDataWithServer(
      startDate: weekAgo,
      endDate: now,
    );
  }

  /// 수면 데이터 상태 체크 (데모용)
  Future<Map<String, dynamic>> checkSleepDataStatus() async {
    try {
      final bool hasPermissions = await _healthService.isHealthAppAvailable();
      
      if (!hasPermissions) {
        return {
          'hasPermissions': false,
          'message': 'HealthKit 권한이 필요합니다.',
          'dataCount': 0,
        };
      }

      // 최근 7일간 데이터 확인
      final List<SleepData> recentData = await fetchAndConvertSleepData(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      );

      return {
        'hasPermissions': true,
        'message': 'HealthKit 연결됨',
        'dataCount': recentData.length,
        'lastSyncDate': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      return {
        'hasPermissions': false,
        'message': '상태 확인 실패: $error',
        'dataCount': 0,
      };
    }
  }
}
