import '../models/sleep_data.dart';
import 'api_service.dart';
import 'health_service.dart';
import 'oauth_service.dart';
import 'sleep_analysis_service.dart';
import 'user_service.dart';
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
        // 서버에 HealthKit 연동 상태 업데이트 (로그인 된 경우에만)
        await _notifyBackendHealthKitStatus(true);
        print('SleepDataService - HealthKit 초기화 완료');
        return true;
      } else {
        await _notifyBackendHealthKitStatus(false);
        print('SleepDataService - HealthKit 권한 거부됨');
        return false;
      }
    } catch (error) {
      print('SleepDataService - HealthKit 초기화 실패: $error');
      await _notifyBackendHealthKitStatus(false);
      return false;
    }
  }

  /// JWT가 있을 때만 백엔드에 HealthKit 상태를 통지
  Future<void> _notifyBackendHealthKitStatus(bool isConnected) async {
    try {
      final String? token = await OAuthService.getJwtToken();
      if (token == null || token.isEmpty) {
        // 미로그인 상태에서는 서버 호출을 생략
        return;
      }
      await ApiService.updateHealthKitStatus(isConnected);
    } catch (_) {
      // 서버 통지는 실패하더라도 앱 플로우를 막지 않음
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
      if (dataPoints.isEmpty) {
        return null;
      }

      // 수면 타입별로 데이터 분리
      DateTime? bedTime;
      DateTime? sleepTime;
      DateTime? wakeTime;
      Duration totalSleepDuration = Duration.zero;
      Duration deepSleepDuration = Duration.zero;
      Duration lightSleepDuration = Duration.zero;
      Duration remSleepDuration = Duration.zero;
      Duration awakeTimeDuration = Duration.zero;

      // 전체 데이터에서 시작/종료 시간 추출
      DateTime? overallStartTime;
      DateTime? overallEndTime;
      
      // 실제 수면 단계(ASLEEP, DEEP, LIGHT, REM)의 첫 시작 시간
      DateTime? firstActualSleepTime;

      for (final HealthDataPoint dataPoint in dataPoints) {
        final Duration duration = dataPoint.dateTo.difference(dataPoint.dateFrom);
        
        // 전체 시작/종료 시간 추적
        if (overallStartTime == null || dataPoint.dateFrom.isBefore(overallStartTime)) {
          overallStartTime = dataPoint.dateFrom;
        }
        if (overallEndTime == null || dataPoint.dateTo.isAfter(overallEndTime)) {
          overallEndTime = dataPoint.dateTo;
        }
        
        switch (dataPoint.type) {
          case HealthDataType.SLEEP_IN_BED:
            bedTime ??= dataPoint.dateFrom;
            wakeTime = dataPoint.dateTo;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            sleepTime ??= dataPoint.dateFrom;
            if (firstActualSleepTime == null || dataPoint.dateFrom.isBefore(firstActualSleepTime)) {
              firstActualSleepTime = dataPoint.dateFrom;
            }
            totalSleepDuration += duration;
            break;
          case HealthDataType.SLEEP_DEEP:
            if (firstActualSleepTime == null || dataPoint.dateFrom.isBefore(firstActualSleepTime)) {
              firstActualSleepTime = dataPoint.dateFrom;
            }
            deepSleepDuration += duration;
            totalSleepDuration += duration; // 깊은 수면도 총 수면 시간에 포함
            break;
          case HealthDataType.SLEEP_LIGHT:
            if (firstActualSleepTime == null || dataPoint.dateFrom.isBefore(firstActualSleepTime)) {
              firstActualSleepTime = dataPoint.dateFrom;
            }
            lightSleepDuration += duration;
            totalSleepDuration += duration; // 얕은 수면도 총 수면 시간에 포함
            break;
          case HealthDataType.SLEEP_REM:
            if (firstActualSleepTime == null || dataPoint.dateFrom.isBefore(firstActualSleepTime)) {
              firstActualSleepTime = dataPoint.dateFrom;
            }
            remSleepDuration += duration;
            totalSleepDuration += duration; // REM 수면도 총 수면 시간에 포함
            break;
          case HealthDataType.SLEEP_AWAKE:
            awakeTimeDuration += duration;
            break;
          default:
            break;
        }
      }

      // 취침 시간 결정 우선순위:
      // 1. SLEEP_IN_BED의 시작 시간 (침대에 누운 시간)
      // 2. 실제 수면 단계의 첫 시작 시간 (처음 잠든 시간)
      // 3. 전체 데이터의 시작 시간
      bedTime ??= firstActualSleepTime ?? overallStartTime;
      
      // 기상 시간: SLEEP_IN_BED의 종료 시간 또는 전체 데이터의 종료 시간
      wakeTime ??= overallEndTime;
      
      // 실제 잠든 시간: 실제 수면 단계의 첫 시작 시간 또는 취침 시간
      sleepTime ??= firstActualSleepTime ?? bedTime;

      // 최소한의 필수 데이터 확인 (모두 non-null이어야 함)
      if (bedTime == null || wakeTime == null || sleepTime == null) {
        print('SleepDataService - 필수 수면 데이터가 누락됨 (날짜: $sleepDate) - 타입: ${dataPoints.map((d) => d.type.name).toSet().join(", ")}');
        return null;
      }

      // 총 수면 시간 검증 (3시간 이하는 제외)
      const Duration minimumSleepDuration = Duration(hours: 3);
      if (totalSleepDuration < minimumSleepDuration) {
        final int hours = totalSleepDuration.inHours;
        final int minutes = totalSleepDuration.inMinutes.remainder(60);
        print('SleepDataService - 수면 시간이 너무 짧아 제외됨 (날짜: $sleepDate, 총 수면시간: ${hours}시간 ${minutes}분)');
        return null;
      }

      // 수면 품질 점수 계산
      final double qualityScore = _healthService.calculateSleepQualityScore(dataPoints);

      // 고유 ID 생성
      final String id = '${sleepDate.toIso8601String().split('T')[0]}_${DateTime.now().millisecondsSinceEpoch}';

      return SleepData(
        id: id,
        sleepDate: sleepDate,
        bedTime: bedTime, // 이제 non-null 보장
        sleepTime: sleepTime, // 이제 non-null 보장
        wakeTime: wakeTime, // 이제 non-null 보장
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

  /// 수면 데이터를 웨어러블 수면 분석 API로 업로드
  Future<bool> uploadSleepDataToServer(List<SleepData> sleepDataList) async {
    try {
      print('\n========================================');
      print('📤 수면 데이터 서버 업로드 시작');
      print('========================================');
      
      if (sleepDataList.isEmpty) {
        print('⚠️ 업로드할 수면 데이터가 없습니다.');
        print('========================================\n');
        return true;
      }

      print('📊 총 ${sleepDataList.length}건의 수면 데이터 전송 예정');
      
      int successCount = 0;
      int failCount = 0;

      // 각 수면 데이터를 웨어러블 API 형식으로 변환하여 전송
      for (int i = 0; i < sleepDataList.length; i++) {
        final SleepData sleepData = sleepDataList[i];
        print('\n--- [${i + 1}/${sleepDataList.length}] 데이터 전송 시작 ---');
        print('📅 날짜: ${sleepData.sleepDate}');
        
        try {
          await _uploadSleepDataAsWearable(sleepData);
          successCount++;
          print('✅ 전송 성공');
        } catch (error) {
          failCount++;
          print('❌ 전송 실패: $error');
        }
      }

      print('\n========================================');
      print('📊 업로드 결과 요약');
      print('  - 성공: $successCount건');
      print('  - 실패: $failCount건');
      print('  - 전체: ${sleepDataList.length}건');
      print('========================================\n');

      return failCount == 0;
    } catch (error) {
      print('\n❌ 수면 데이터 업로드 중 치명적 오류 발생: $error');
      print('========================================\n');
      return false;
    }
  }

  /// SleepData를 웨어러블 API 형식으로 변환하여 전송
  Future<void> _uploadSleepDataAsWearable(SleepData sleepData) async {
    try {
      print('  🔄 웨어러블 API 형식으로 변환 중...');
      
      // 수면 단계별 데이터 생성
      final List<Map<String, dynamic>> sleepStages = [];

      // 1. InBed 단계 (취침 ~ 수면 시작)
      if (sleepData.bedTime.isBefore(sleepData.sleepTime)) {
        sleepStages.add({
          'start_time': sleepData.bedTime.toUtc().toIso8601String(),
          'end_time': sleepData.sleepTime.toUtc().toIso8601String(),
          'sleep_stage': 'inbed',
        });
      }

      // 2. 실제 수면 단계들 (비율 기반으로 시간 분배)
      DateTime currentTime = sleepData.sleepTime;
      
      // Deep Sleep (N3)
      if (sleepData.deepSleepDuration.inMinutes > 0) {
        final DateTime endTime = currentTime.add(sleepData.deepSleepDuration);
        sleepStages.add({
          'start_time': currentTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'sleep_stage': 'deep',
        });
        currentTime = endTime;
      }

      // Light Sleep (N1-N2, Core)
      if (sleepData.lightSleepDuration.inMinutes > 0) {
        final DateTime endTime = currentTime.add(sleepData.lightSleepDuration);
        sleepStages.add({
          'start_time': currentTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'sleep_stage': 'core',
        });
        currentTime = endTime;
      }

      // REM Sleep
      if (sleepData.remSleepDuration.inMinutes > 0) {
        final DateTime endTime = currentTime.add(sleepData.remSleepDuration);
        sleepStages.add({
          'start_time': currentTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'sleep_stage': 'rem',
        });
        currentTime = endTime;
      }

      // 3. Awake 시간 (중간 각성)
      if (sleepData.awakeTimeDuration.inMinutes > 0) {
        final DateTime endTime = currentTime.add(sleepData.awakeTimeDuration);
        sleepStages.add({
          'start_time': currentTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'sleep_stage': 'awake',
        });
      }

      // 메타데이터 생성
      final Map<String, dynamic> metadata = {
        'source': 'apple_watch',
        'device_model': 'Apple Watch',
        'sleep_quality_score': sleepData.sleepQualityScore,
        'sleep_efficiency': sleepData.sleepEfficiency,
        'recorded_at': sleepData.recordedAt.toIso8601String(),
      };

      // 로그인된 사용자 ID 가져오기
      String? userId = UserService.getUserId();
      
      // 사용자 ID가 없으면 에러 처리
      if (userId == null) {
        print('  ⚠️ 로그인되지 않은 상태입니다.');
        print('  💡 해결방법: 먼저 로그인을 진행해주세요.');
        throw Exception('User not logged in. Cannot upload sleep data.');
      }

      print('  👤 사용자 ID: $userId');
      print('  📱 기기 타입: apple_watch');
      print('  🛌 취침 시간: ${sleepData.bedTime}');
      print('  🌅 기상 시간: ${sleepData.wakeTime}');
      print('  📊 수면 단계: ${sleepStages.length}개');
      print('  ⏱️  총 수면: ${sleepData.totalSleepDuration.inHours}시간 ${sleepData.totalSleepDuration.inMinutes % 60}분');

      // 웨어러블 수면 분석 API 호출
      print('  🚀 ML 서버로 데이터 전송 중... (https://neulbo1.com/api/ml/wearable/analyze)');
      
      final response = await ApiService.analyzeWearableSleepData(
        userId: userId,
        deviceType: 'apple_watch',
        sleepStart: sleepData.bedTime,
        sleepEnd: sleepData.wakeTime,
        sleepStages: sleepStages,
        sleepAnalysisMetadata: metadata,
        deviceId: sleepData.sourceId,
      );

      print('  ✅ ML 서버 응답 수신: ${response.statusCode}');
      print('  📦 응답 데이터: ${response.data}');

      // 분석 ID 저장 (LLM 피드백에 사용)
      if (response.data != null && response.data['analysis_id'] != null) {
        final String analysisId = response.data['analysis_id'];
        final String? summary = response.data['calculated_metrics'] != null
            ? '총 수면시간: ${response.data['calculated_metrics']['total_sleep_time']}분, 수면효율: ${response.data['calculated_metrics']['sleep_efficiency']}%'
            : null;

        await SleepAnalysisService.saveLastAnalysisId(
          analysisId: analysisId,
          summary: summary,
        );
        print('  💾 분석 ID 저장 완료: $analysisId');
      }
    } catch (error) {
      print('  ❌ 웨어러블 API 전송 실패: $error');
      rethrow;
    }
  }

  /// HealthKit에서 수면 데이터를 가져와 서버에 동기화 (전체 프로세스)
  Future<bool> syncSleepDataWithServer({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('\n╔════════════════════════════════════════════════╗');
      print('║     🌙 수면 데이터 동기화 프로세스 시작        ║');
      print('╚════════════════════════════════════════════════╝');
      print('📅 기간: ${startDate.toLocal().toString().split(' ')[0]} ~ ${endDate.toLocal().toString().split(' ')[0]}');

      // 1. HealthKit 권한 확인
      print('\n[1/3] HealthKit 권한 확인 중...');
      final bool hasPermissions = await _healthService.isHealthAppAvailable();
      if (!hasPermissions) {
        print('❌ HealthKit 권한이 없습니다.');
        print('💡 해결방법: "HealthKit 권한 요청하기" 버튼을 눌러주세요.\n');
        return false;
      }
      print('✅ HealthKit 권한 확인 완료');

      // 2. HealthKit에서 수면 데이터 가져오기
      print('\n[2/3] HealthKit에서 수면 데이터 가져오는 중...');
      final List<SleepData> sleepDataList = await fetchAndConvertSleepData(
        startDate: startDate,
        endDate: endDate,
      );

      if (sleepDataList.isEmpty) {
        print('⚠️ 해당 기간에 수면 데이터가 없습니다.');
        print('💡 건강 앱에 수면 데이터가 기록되어 있는지 확인해주세요.\n');
        return true;
      }
      print('✅ ${sleepDataList.length}건의 수면 데이터 로드 완료');

      // 3. 서버에 업로드
      print('\n[3/3] 서버에 업로드 중...');
      final bool uploadSuccess = await uploadSleepDataToServer(sleepDataList);

      if (uploadSuccess) {
        print('\n╔════════════════════════════════════════════════╗');
        print('║     ✅ 수면 데이터 동기화 성공!               ║');
        print('╚════════════════════════════════════════════════╝\n');
        return true;
      } else {
        print('\n╔════════════════════════════════════════════════╗');
        print('║     ❌ 수면 데이터 동기화 실패                ║');
        print('╚════════════════════════════════════════════════╝\n');
        return false;
      }
    } catch (error) {
      print('\n╔════════════════════════════════════════════════╗');
      print('║     ❌ 동기화 중 오류 발생                    ║');
      print('╚════════════════════════════════════════════════╝');
      print('오류 내용: $error\n');
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
