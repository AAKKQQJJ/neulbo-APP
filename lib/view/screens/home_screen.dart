import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../const/design_constants.dart';
import '../../models/sleep_data.dart';
import '../../models/sleep_recording_data.dart';
import '../../services/api_service.dart';
import '../../services/health_service.dart';
import '../../services/sleep_data_service.dart';
import '../../services/sleep_data_storage_service.dart';
import '../../services/user_service.dart';
import 'friend_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  bool hasHealthPermission = false;
  bool isLoading = true;
  SleepData? todaySleepData;
  List<HealthDataPoint> rawSleepDataPoints = []; // HealthKit 데이터 (워치 모드)
  SleepAnalysisResult? mlAnalysisResult; // ML 분석 결과 (디바이스 모드)
  String userNickname = '사용자';
  String _sleepMeasurementDevice = 'device'; // 'device' 또는 'watch'
  String _previousDevice = 'device'; // 이전 디바이스 설정 추적

  final HealthService _healthService = HealthService();
  final SleepDataService _sleepDataService = SleepDataService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('HomeScreen - 배경 이미지 경로: ${DesignConstants.defaultBackgroundPath}');
    _loadUserInfo();
    _loadSleepMeasurementDevice();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 포그라운드로 돌아올 때 설정 재확인
    if (state == AppLifecycleState.resumed) {
      checkAndReloadIfDeviceChanged();
    }
  }

  /// 디바이스 설정이 변경되었는지 확인하고 재로드 (public 메서드)
  Future<void> checkAndReloadIfDeviceChanged() async {
    try {
      final device = await _storage.read(key: 'sleep_measurement_device');
      final currentDevice = device ?? 'device';

      if (currentDevice != _previousDevice) {
        print('🔄 HomeScreen - 디바이스 설정 변경 감지: $_previousDevice → $currentDevice');

        // 🔥 중요: 디바이스 변경 시 이전 데이터 초기화
        setState(() {
          _sleepMeasurementDevice = currentDevice;
          _previousDevice = currentDevice;
          todaySleepData = null; // 이전 데이터 삭제
          rawSleepDataPoints = []; // 이전 raw 데이터 삭제
          hasHealthPermission = false; // 권한 상태 초기화
        });

        print('🗑️ 이전 수면 데이터 초기화 완료');

        // 데이터 재로드
        await _checkPermissionAndLoadData();
      }
    } catch (e) {
      print('⚠️ 디바이스 설정 재확인 실패: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      await UserService.loadUserInfo();
      setState(() {
        userNickname = UserService.getUserNickname();
        if (userNickname.isEmpty) {
          userNickname = '사용자';
        }
      });
      print('사용자 닉네임 로드됨: $userNickname');
    } catch (e) {
      print('사용자 정보 로드 실패: $e');
      setState(() {
        userNickname = '사용자';
      });
    }
  }

  /// 수면 측정 디바이스 설정 로드
  Future<void> _loadSleepMeasurementDevice() async {
    try {
      final device = await _storage.read(key: 'sleep_measurement_device');
      final prefs = await SharedPreferences.getInstance();
      final hasSeenDeviceSetup = prefs.getBool('has_seen_device_setup') ?? false;

      final currentDevice = device ?? 'device';
      setState(() {
        _sleepMeasurementDevice = currentDevice;
        _previousDevice = currentDevice; // 초기값 저장
      });
      print('✅ HomeScreen - 수면 측정 디바이스: $_sleepMeasurementDevice');

      // 초기 로그인 시 디바이스 설정 안내 팝업 (한 번만)
      if (!hasSeenDeviceSetup && device == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showDeviceSetupDialog();
        });
      }

      // 디바이스 설정 로드 후 데이터 로드
      await _checkPermissionAndLoadData();
    } catch (e) {
      print('⚠️ 수면 측정 디바이스 로드 실패: $e');
      // 실패해도 기본값(device)으로 데이터 로드
      await _checkPermissionAndLoadData();
    }
  }

  /// 초기 로그인 시 디바이스 설정 권장 팝업
  Future<void> _showDeviceSetupDialog() async {
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Color(0xFF2D1B69), size: 28),
            SizedBox(width: 12),
            Text('환영합니다! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
              '수면 데이터를 측정하는 방법을 선택해주세요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildDeviceSetupOption(
              icon: Icons.smartphone,
              title: '📱 디바이스로 측정',
              description: '스마트폰의 센서로 수면을 측정하고\nAI가 분석합니다.',
              value: 'device',
            ),
            const SizedBox(height: 16),
            _buildDeviceSetupOption(
              icon: Icons.watch,
              title: '⌚ 워치 데이터',
              description: 'Apple Watch 등 웨어러블 기기의\n수면 데이터를 사용합니다.',
              value: 'watch',
            ),
            const SizedBox(height: 16),
                const Text(
              '💡 언제든지 내 정보에서 변경할 수 있습니다',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await _storage.write(key: 'sleep_measurement_device', value: selected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_device_setup', true);

      setState(() {
        _sleepMeasurementDevice = selected;
      });

      print('✅ 초기 디바이스 설정 완료: $selected');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected == 'device' ? '📱 디바이스로 측정이 설정되었습니다' : '⌚ 워치 데이터가 설정되었습니다',
            ),
            backgroundColor: const Color(0xFF2D1B69),
          ),
        );
      }

      // 재로드
      await _checkPermissionAndLoadData();
    }
  }

  /// 디바이스 설정 옵션 위젯
  Widget _buildDeviceSetupOption({
    required IconData icon,
    required String title,
    required String description,
    required String value,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B69),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                              style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시간대별 인사말을 반환하는 메서드
  Map<String, String> _getTimeBasedGreeting() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 4 && hour < 11) {
      // 아침 (AM 04:00 ~ AM 11:00)
      return {'greeting': '좋은 아침이에요! ☀️', 'subtext': '상쾌하게 하루를 시작해볼까요?'};
    } else if (hour >= 11 && hour < 17) {
      // 점심 (AM 11:00 ~ PM 05:00)
      return {'greeting': '점심시간이 찾아왔어요. 🍽️', 'subtext': '잠시 쉬어가며 에너지 가득 채워보세요!'};
    } else {
      // 저녁 (PM 05:00 ~ AM 04:00)
      return {'greeting': '평화로운 저녁이에요. 🌙', 'subtext': '하루의 피로를 내려놓고 편히 쉬어요.'};
    }
  }

  Future<void> _checkPermissionAndLoadData() async {
    setState(() {
      isLoading = true;
    });

    print('HomeScreen - 선택된 측정 방식: $_sleepMeasurementDevice');

    if (_sleepMeasurementDevice == 'watch') {
      // 워치 데이터 (HealthKit) 사용
      final bool hasPermission = await _healthService.isHealthAppAvailable();
      setState(() {
        hasHealthPermission = hasPermission;
      });
      if (hasPermission) {
        await _loadTodaySleepData();
      }
    } else {
      // 디바이스로 측정 (로컬 저장된 센서 데이터) 사용
      await _loadDeviceSleepData();
    }

    setState(() {
      isLoading = false;
    });
  }

  /// 디바이스로 측정한 수면 데이터 로드
  Future<void> _loadDeviceSleepData() async {
    try {
      print('📱 HomeScreen - 디바이스 수면 데이터 로드 시작');

      // 로컬에 저장된 수면 데이터 불러오기
      final savedDataList = await SleepDataStorageService.getSavedDataList();
      print('📱 HomeScreen - 저장된 수면 데이터 수: ${savedDataList.length}');

      if (savedDataList.isEmpty) {
        print('📱 HomeScreen - 저장된 수면 데이터 없음');
        setState(() {
          todaySleepData = null;
        });
        return;
      }

      // 가장 최근 데이터 가져오기 (첫 번째 요소)
      final latestData = savedDataList.first;
      final sessionId = latestData['sessionId'] as String;
      final filePath = latestData['filePath'] as String;
      print('📱 HomeScreen - 최근 수면 데이터: $sessionId');

      // 상세 데이터 로드
      final recordingData = await SleepDataStorageService.loadSleepData(filePath);

      // ML 분석 결과가 있는지 확인
      final hasAnalysisResult = recordingData.analysisResult != null;
      
      print('');
      print('═══════════════════════════════════════════════════');
      print('🔍 디바이스 수면 데이터 로드 분석');
      print('═══════════════════════════════════════════════════');
      print('📱 파일 경로: $filePath');
      print('🆔 세션 ID: ${recordingData.sessionId}');
      print('⏰ 측정 시간: ${recordingData.startTime} ~ ${recordingData.endTime}');
      print('📊 ML 분석 결과: ${hasAnalysisResult ? "✅ 있음" : "❌ 없음"}');
      
      if (hasAnalysisResult) {
        final analysis = recordingData.analysisResult!;
        print('   └─ 분석 ID: ${analysis.analysisId}');
        print('   └─ Stage Intervals: ${analysis.stageIntervals.length}개');
        print('   └─ 총 수면시간: ${analysis.summaryStatistics.totalSleepTime}분');
      } else {
        print('⚠️ ML 분석이 필요합니다!');
        print('   💡 "오늘 수면 분석하기" 버튼을 눌러주세요.');
      }
      print('═══════════════════════════════════════════════════');
      print('');

      // SleepRecordingData를 SleepData 형식으로 변환
      final now = DateTime.now();
      SleepData convertedSleepData;
      
      if (hasAnalysisResult) {
        // ML 분석 결과가 있는 경우 - 상세한 수면 단계 정보 사용
        final analysis = recordingData.analysisResult!;
        final stats = analysis.summaryStatistics;
        
        convertedSleepData = SleepData(
          id: recordingData.sessionId,
          sleepDate: DateTime(
            recordingData.startTime.year,
            recordingData.startTime.month,
            recordingData.startTime.day,
          ),
          bedTime: recordingData.startTime,
          sleepTime: recordingData.startTime,
          wakeTime: recordingData.endTime,
          totalSleepDuration: Duration(minutes: stats.totalSleepTime),
          deepSleepDuration: Duration(minutes: stats.n3Time),
          lightSleepDuration: Duration(minutes: stats.n1Time + stats.n2Time),
          remSleepDuration: Duration(minutes: stats.remTime),
          awakeTimeDuration: Duration(minutes: stats.wakeTime),
          sleepQualityScore: stats.sleepEfficiency,
          sourceId: 'device_ml_analyzed',
          recordedAt: now,
        );
        
        print('✅ ML 분석 결과로 변환 완료: 총 ${stats.totalSleepTime}분');
      } else {
        // ML 분석 결과가 없는 경우 - 기본값 설정
        convertedSleepData = SleepData(
          id: recordingData.sessionId,
          sleepDate: DateTime(
            recordingData.startTime.year,
            recordingData.startTime.month,
            recordingData.startTime.day,
          ),
          bedTime: recordingData.startTime,
          sleepTime: recordingData.startTime,
          wakeTime: recordingData.endTime,
          totalSleepDuration: Duration(seconds: recordingData.duration.toInt()),
          // 디바이스 데이터는 수면 단계 정보가 없으므로 기본값 설정
          deepSleepDuration: const Duration(minutes: 0),
          lightSleepDuration: const Duration(minutes: 0),
          remSleepDuration: const Duration(minutes: 0),
          awakeTimeDuration: const Duration(minutes: 0),
          sleepQualityScore: recordingData.dataQuality.contains('양호') ? 85.0 : 70.0,
          sourceId: 'device_sensor',
          recordedAt: now,
        );
        
        print('⚠️ ML 분석 결과 없음 - 기본값으로 변환');
      }

      setState(() {
        todaySleepData = convertedSleepData;
        // rawSleepDataPoints는 HealthKit 전용이므로 비워둠
        rawSleepDataPoints = [];
        // ML 분석 결과 설정
        mlAnalysisResult = recordingData.analysisResult;
      });

      print('');
      print('🎨 UI 업데이트 완료:');
      print('   └─ todaySleepData: ${todaySleepData != null ? "✅" : "❌"}');
      print('   └─ rawSleepDataPoints: ${rawSleepDataPoints.length}개 (워치 전용)');
      print('   └─ mlAnalysisResult: ${mlAnalysisResult != null ? "✅ 있음" : "❌ 없음"}');
      
      if (mlAnalysisResult != null) {
        print('   └─ stageIntervals: ${mlAnalysisResult!.stageIntervals.length}개');
      }
      
      print('✅ 디바이스 수면 데이터 변환 완료: ${convertedSleepData.totalSleepDuration.inHours}시간 ${convertedSleepData.totalSleepDuration.inMinutes % 60}분');
      print('');
    } catch (e) {
      print('❌ 디바이스 수면 데이터 로드 실패: $e');
      setState(() {
        todaySleepData = null;
      });
    }
  }

  Future<void> _loadTodaySleepData() async {
    try {
      final DateTime now = DateTime.now();
      final DateTime twoDaysAgo = now.subtract(const Duration(days: 2));
      print('HomeScreen - 수면 데이터 조회 기간: ${twoDaysAgo.toString()} ~ ${now.toString()}');
      final List<HealthDataPoint> rawData = await _healthService.getSleepData(
        startDate: twoDaysAgo,
        endDate: now,
      );
      print('HomeScreen - 원시 데이터 포인트 수: ${rawData.length}');
      final List<SleepData> sleepDataList = await _sleepDataService.fetchAndConvertSleepData(
        startDate: twoDaysAgo,
        endDate: now,
      );
      print('HomeScreen - 변환된 수면 데이터 수: ${sleepDataList.length}');
      if (sleepDataList.isNotEmpty) {
        sleepDataList.sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
        final SleepData mostRecentSleep = sleepDataList.first;
        print(
            'HomeScreen - 가장 최근 수면: 취침 ${mostRecentSleep.bedTime}, 기상 ${mostRecentSleep.wakeTime}');
        final List<HealthDataPoint> relevantRawData = rawData.where((point) {
          return point.dateFrom
                  .isAfter(mostRecentSleep.bedTime.subtract(const Duration(hours: 1))) &&
              point.dateTo.isBefore(mostRecentSleep.wakeTime.add(const Duration(hours: 1)));
        }).toList();
        print('HomeScreen - 관련 원시 데이터 포인트 수: ${relevantRawData.length}');
        setState(() {
          todaySleepData = mostRecentSleep;
          rawSleepDataPoints = relevantRawData;
          mlAnalysisResult = null; // 워치 모드에서는 ML 분석 결과 없음
        });
      }
    } catch (error) {
      print('HomeScreen - 수면 데이터 로드 실패: $error');
    }
  }

  Future<void> _requestPermission() async {
    final bool granted = await _sleepDataService.initializeHealthKit();
    if (granted) {
      await _checkPermissionAndLoadData();
    }
  }

  /// 오늘 수면 분석하기 (디바이스 모드 전용)
  Future<void> _analyzeTodaySleep() async {
    try {
      setState(() {
        isLoading = true;
      });

      print('🔍 오늘 수면 분석 시작...');

      // 1. 로컬에서 가장 최근 수면 데이터 로드
      final savedDataList = await SleepDataStorageService.getSavedDataList();

      if (savedDataList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장된 수면 데이터가 없습니다.\n수면 측정을 먼저 진행해주세요.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 2. 가장 최근 데이터 가져오기
      final latestData = savedDataList.first;
      final filePath = latestData['filePath'] as String;
      final sessionId = latestData['sessionId'] as String;

      print('📱 최근 수면 데이터 로드: $sessionId');

      // 3. 상세 데이터 로드
      final recordingData = await SleepDataStorageService.loadSleepData(filePath);

      // 4. ML 서버로 분석 요청
      print('🤖 ML 서버로 분석 요청 전송 중...');

      final analysisResult = await ApiService.analyzeSleepData(recordingData);

      print('✅ ML 분석 완료!');
      print('📊 분석 결과: $analysisResult');
      
      // 5. ML 분석 결과를 로컬 파일에 저장 (다음번 로드 시 사용)
      try {
        print('💾 ML 분석 결과를 로컬에 저장 중...');
        final updatedRecordingData = recordingData.withAnalysisResult(analysisResult);
        await SleepDataStorageService.saveSleepData(updatedRecordingData);
        print('✅ ML 분석 결과 로컬 저장 완료');
      } catch (saveError) {
        print('⚠️ ML 분석 결과 저장 실패 (무시): $saveError');
      }

      // 6. 분석 결과를 SleepData 형식으로 변환
      final now = DateTime.now();
      final stats = analysisResult.summaryStatistics;

      final analyzedSleepData = SleepData(
        id: recordingData.sessionId,
        sleepDate: DateTime(
          recordingData.startTime.year,
          recordingData.startTime.month,
          recordingData.startTime.day,
        ),
        bedTime: recordingData.startTime,
        sleepTime: recordingData.startTime,
        wakeTime: recordingData.endTime,
        totalSleepDuration: Duration(minutes: stats.totalSleepTime),
        // ML 분석 결과에서 수면 단계 정보 추출
        deepSleepDuration: Duration(minutes: stats.n3Time), // N3 = 깊은 수면
        lightSleepDuration: Duration(minutes: stats.n1Time + stats.n2Time), // N1+N2 = 얕은 수면
        remSleepDuration: Duration(minutes: stats.remTime), // REM 수면
        awakeTimeDuration: Duration(minutes: stats.wakeTime), // 깸
        sleepQualityScore: stats.sleepEfficiency, // 수면 효율을 점수로 사용
        sourceId: 'device_ml_analyzed',
        recordedAt: now,
      );

      // 7. UI 업데이트
      setState(() {
        todaySleepData = analyzedSleepData;
        rawSleepDataPoints = []; // 디바이스 모드에서는 HealthKit 데이터 없음
        mlAnalysisResult = analysisResult; // ML 분석 결과 저장 (그래프 그리기용)
        isLoading = false;
      });

      print('🎉 수면 데이터 분석 및 UI 업데이트 완료');

      // 8. 성공 다이얼로그 + 결과 화면 이동
      if (mounted) {
        // 분석 결과 다이얼로그 표시
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2D1B69),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFFAF99FF).withOpacity(0.5),
                  width: 2,
                ),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFFAF99FF), size: 28),
                  SizedBox(width: 12),
                  Text(
                    '수면 분석 완료!',
                    style: TextStyle(
                      color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'suit',
                              ),
                            ),
                          ],
                        ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnalysisResultRow('총 수면시간', '${stats.totalSleepTime}분'),
                  const SizedBox(height: 8),
                  _buildAnalysisResultRow('수면 효율', '${stats.sleepEfficiency.toStringAsFixed(1)}%'),
                  const SizedBox(height: 8),
                  _buildAnalysisResultRow('깊은 수면', '${stats.n3Time}분'),
                  const SizedBox(height: 8),
                  _buildAnalysisResultRow('REM 수면', '${stats.remTime}분'),
                        const SizedBox(height: 12),
                        const Text(
                    '상세 분석 결과를 확인하시겠습니까?',
                          style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                            fontFamily: 'suit',
                          ),
                        ),
                ],
              ),
              actions: [
                TextButton(
                            onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // 다이얼로그 닫은 후 화면 새로고침 보장
                    if (mounted) {
                      setState(() {
                        // 명시적으로 리빌드 트리거
                      });
                    }
                  },
                  child: const Text(
                    '나중에',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'suit',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // 상세 결과 화면으로 이동
                              context.push('/sleep-data-demo');
                            },
                            style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFAF99FF),
                    foregroundColor: const Color(0xFF2D1B69),
                              shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                    '상세 보기',
                              style: TextStyle(
                      fontWeight: FontWeight.bold,
                                fontFamily: 'suit',
                              ),
                            ),
                          ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('❌ 수면 분석 실패: $e');

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수면 분석에 실패했습니다.\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 상태바 배경을 투명하게
        statusBarIconBrightness: Brightness.light, // 아이콘을 밝게 (흰색)
        statusBarBrightness: Brightness.dark, // iOS용 설정
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 반응형 배경 이미지
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(DesignConstants.defaultBackgroundPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    onError: (exception, stackTrace) {
                      print('배경 이미지 로드 실패: $exception');
                      print('이미지 경로: ${DesignConstants.defaultBackgroundPath}');
                      print('대신 homeScreenImagePath 사용: ${DesignConstants.homeScreenImagePath}');
                    },
                  ),
                  // 이미지가 작을 경우를 대비한 fallback 색상
                  color: const Color(0xFF2D1B69),
                ),
                child: Container(
                  // 이미지 위에 약간의 오버레이 (선택사항)
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 콘텐츠
            SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildGreeting(),
                      const SizedBox(height: 24),
                      isLoading
                          ? _buildLoadingCard()
                          : _buildSleepDataCardOrPermission(screenWidth),
                      const SizedBox(height: 32),
                      _buildWeeklyFriendsSection(),
                      const SizedBox(height: 32),
                      _buildChallengesSection(),
                      const SizedBox(height: 32),
                      _buildTodayLettersSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final greetingData = _getTimeBasedGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${userNickname}님,',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'malang',
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          greetingData['greeting']!,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'malang',
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          greetingData['subtext']!,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'suit',
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF7B68B8).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildPermissionRequestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF7B68B8).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
            '수면 정보를 연동해서 쿨쿨과 함께해요 🛌',
            textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'suit',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // 디바이스 모드에 따라 다른 버튼 표시
          if (_sleepMeasurementDevice == 'watch')
            OutlinedButton.icon(
              onPressed: _requestPermission,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.watch, size: 20),
              label: const Text(
                '수면 정보 불러오기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'suit',
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _analyzeTodaySleep,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.analytics, size: 20),
              label: const Text(
                '오늘 수면 분석하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'suit',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 수면 데이터 카드 또는 권한 요청 카드 (모드에 따라 자동 선택)
  Widget _buildSleepDataCardOrPermission(double screenWidth) {
    // 디바이스 모드: 수면 데이터가 있으면 카드 표시, 없으면 분석 안내
    if (_sleepMeasurementDevice == 'device') {
      return _buildSleepDataCard(screenWidth);
    }

    // 워치 모드: HealthKit 권한 체크
    if (hasHealthPermission) {
      return _buildSleepDataCard(screenWidth);
    } else {
      return _buildPermissionRequestCard();
    }
  }

  Widget _buildSleepDataCard(double screenWidth) {
    // 🔍 디버깅: 현재 상태 출력
    print('');
    print('🎨 _buildSleepDataCard 호출됨:');
    print('   └─ todaySleepData: ${todaySleepData != null ? "✅ 있음" : "❌ 없음"}');
    print('   └─ rawSleepDataPoints: ${rawSleepDataPoints.length}개');
    print('   └─ mlAnalysisResult: ${mlAnalysisResult != null ? "✅ 있음 (${mlAnalysisResult!.stageIntervals.length}개 intervals)" : "❌ 없음"}');
    print('   └─ _sleepMeasurementDevice: $_sleepMeasurementDevice');
    
    // 🚨 디바이스 모드인데 ML 분석 결과가 없는 경우 체크
    if (_sleepMeasurementDevice == 'device' && todaySleepData != null && mlAnalysisResult == null) {
      print('⚠️ 디바이스 데이터는 있지만 ML 분석 결과가 없음 → 분석 버튼 표시 필요!');
    }
    print('');
    
    if (todaySleepData == null) {
      // 각 모드에 맞는 안내 메시지
      final String title;
      final String subtitle;
      final IconData icon;

      if (_sleepMeasurementDevice == 'watch') {
        // 워치 모드
        title = '수면 데이터가 없습니다';
        subtitle = '아래 "수면 정보 불러오기" 버튼으로\n건강 앱 데이터를 가져오세요';
        icon = Icons.watch;
      } else {
        // 디바이스 모드
        title = '분석할 수면 데이터가 없습니다';
        subtitle = '수면 측정 후 "오늘 수면 분석하기"\n버튼을 눌러주세요';
        icon = Icons.analytics;
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: const Color(0xFF7B68B8).withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'suit',
                color: Colors.white70,
                height: 1.5,
                  ),
                ),
              ],
            ),
      );
    }
    final int qualityScore = todaySleepData!.sleepQualityScore.round();
    final Duration actualSleepDuration =
        todaySleepData!.wakeTime.difference(todaySleepData!.bedTime);
    final int hours = actualSleepDuration.inHours;
    final int minutes = actualSleepDuration.inMinutes % 60;
    final String totalSleepTime = '${hours}시간 ${minutes}분';
    final String bedTimeStr = _formatTime(todaySleepData!.bedTime);
    final String wakeTimeStr = _formatTime(todaySleepData!.wakeTime);
    print('HomeScreen - 수면 시간 계산: ${actualSleepDuration.inMinutes}분 = ${hours}시간 ${minutes}분');
    
    // 디바이스 모드인데 ML 분석 결과가 없는 경우 → 분석 필요 안내
    final bool needsAnalysis = _sleepMeasurementDevice == 'device' && mlAnalysisResult == null;
    
    return GestureDetector(
      onTap: needsAnalysis ? null : () {
        context.push('/sleep-data-demo');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: const Color(0xFF6B5B95).withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFB8A3E8),
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${qualityScore}점',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'suit',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalSleepTime,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'suit',
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '취침 $bedTimeStr | 기상 $wakeTimeStr',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'suit',
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.6),
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ML 분석이 필요한 경우 → 분석 버튼 표시
            if (needsAnalysis)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFAF99FF).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: Colors.white.withOpacity(0.7),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI 분석으로 상세한 수면 그래프를 확인하세요',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'suit',
                        color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _analyzeTodaySleep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFAF99FF),
                        foregroundColor: const Color(0xFF2D1B69),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.analytics, size: 18),
                      label: const Text(
                        '수면 분석하기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'suit',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // ML 분석 결과가 있는 경우 → 그래프 표시
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: CustomPaint(
                    painter: SleepStageGraphPainter(
                      sleepData: todaySleepData,
                      rawDataPoints: rawSleepDataPoints,
                      mlAnalysisResult: mlAnalysisResult,
                    ),
                    child: Container(),
                  ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 분석 결과 행 위젯 (다이얼로그용)
  Widget _buildAnalysisResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: 'suit',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFAF99FF),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'suit',
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyFriendsSection() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FriendManagementScreen(),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '주간 쿨쿨 프렌즈',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'suit',
                  color: Colors.white,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.6),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFF6B5B95).withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFriendAvatar('👧🏻', '1등\n짱채원', true),
                _buildFriendAvatar('👨🏻', '2등\n김쿨쿨', false),
                _buildFriendAvatar('👩', '3등\n쿨냥이', false),
                _buildFriendAvatar('👩🏻', '4등\n나사나사나', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendAvatar(String emoji, String name, bool isFirst) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFirst ? const Color(0xFFE8D9FF) : const Color(0xFF8B7DB8),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
          Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'suit',
            color: Colors.white.withOpacity(0.9),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildChallengesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '진행 중인 쿨쿨 챌린지',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'suit',
                color: Colors.white,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.6),
              size: 28,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: const Color(0xFF6B5B95).withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildChallengeItem(
                '🌍',
                '7일 연속 8시간 이상 꿀잠 자기',
                4,
                '4일째 도전 중 💪',
                50,
              ),
              const SizedBox(height: 20),
              _buildChallengeItem(
                '⭐',
                '5일 연속 20분 낮잠 자기',
                1,
                '1일째 도전 중 💪',
                30,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeItem(
    String emoji,
    String title,
    int daysCompleted,
    String status,
    int points,
  ) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
            emoji,
              style: const TextStyle(fontSize: 32),
          ),
          ),
        ),
        const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                  fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'suit',
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: daysCompleted / 7,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB8A3E8)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text(
                    status,
                    style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'suit',
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    '성공 시 ${points}P',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'suit',
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
                ),
              ],
            ),
          ),
        ],
    );
  }

  Widget _buildTodayLettersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '오늘의 쿨쿨 레터',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'suit',
                color: Colors.white,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.6),
              size: 28,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildLetterCard(
                '수면일기,\n정말 수면이 도움이 될까?',
                '🌙',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLetterCard(
                '대부분 모르는,\n\'하품하는 이유와 의미\'',
                '😮',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLetterCard(String title, String emoji) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF4A4060),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'suit',
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum SleepStage {
  awake,
  rem,
  core,
  deep,
}

class SleepSegment {
  final DateTime startTime;
  final DateTime endTime;
  final SleepStage stage;

  SleepSegment({
    required this.startTime,
    required this.endTime,
    required this.stage,
  });
}

class SleepStageGraphPainter extends CustomPainter {
  final SleepData? sleepData;
  final List<HealthDataPoint> rawDataPoints; // 워치 모드
  final SleepAnalysisResult? mlAnalysisResult; // 디바이스 모드

  SleepStageGraphPainter({
    this.sleepData,
    required this.rawDataPoints,
    this.mlAnalysisResult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      // 데이터 확인: HealthKit 또는 ML 분석 결과 중 하나라도 있어야 함
      if (sleepData == null) {
        print('🎨 SleepStageGraphPainter - sleepData가 null');
        _drawEmptyState(canvas, size);
        return;
      }

      // 워치 모드: HealthKit 데이터 필요
      // 디바이스 모드: ML 분석 결과 필요
      final bool hasWatchData = rawDataPoints.isNotEmpty;
      final bool hasDeviceData =
          mlAnalysisResult != null && mlAnalysisResult!.stageIntervals.isNotEmpty;

      print('');
      print('🎨 SleepStageGraphPainter.paint() 호출됨');
      print('   └─ sleepData: ✅');
      print('   └─ hasWatchData: ${hasWatchData ? "✅ ${rawDataPoints.length}개" : "❌"}');
      print('   └─ hasDeviceData: ${hasDeviceData ? "✅ ${mlAnalysisResult!.stageIntervals.length}개" : "❌"}');

      if (!hasWatchData && !hasDeviceData) {
        print('   └─ ⚠️ 그래프를 그릴 데이터 없음 → 빈 상태 표시');
        print('');
        _drawEmptyState(canvas, size);
        return;
      }
      
      final List<SleepSegment> segments = _processSleepData();
      print('   └─ segments: ${segments.length}개');
      
      if (segments.isEmpty) {
        print('   └─ ⚠️ 처리된 segments가 비어있음 → 빈 상태 표시');
        print('');
        _drawEmptyState(canvas, size);
        return;
      }
      
      print('   └─ ✅ 그래프 그리기 시작');
      print('');
      final DateTime startTime = sleepData!.bedTime;
      final DateTime endTime = sleepData!.wakeTime;
      final Duration totalDuration = endTime.difference(startTime);

      // 유효하지 않은 시간 데이터 처리
      if (totalDuration.inMinutes <= 0) {
        _drawEmptyState(canvas, size);
        return;
      }

      final double graphHeight = size.height * 0.6;
      final double graphBottom = size.height * 0.75;
      final double leftMargin = 60.0;
      final double rightMargin = 8.0;
      final double graphWidth = size.width - leftMargin - rightMargin;

      // 유효하지 않은 크기 처리
      if (graphWidth <= 0 || graphHeight <= 0) {
        _drawEmptyState(canvas, size);
        return;
      }

      _drawStageLabels(canvas, size, leftMargin, graphBottom, graphHeight);
      _drawSleepConnections(canvas, segments, startTime, totalDuration, leftMargin, graphWidth,
          graphBottom, graphHeight);
      _drawSleepBars(canvas, segments, startTime, totalDuration, leftMargin, graphWidth,
          graphBottom, graphHeight);
      _drawTimeLabels(canvas, size, startTime, endTime, leftMargin, graphWidth, graphBottom);
    } catch (e) {
      print('수면 그래프 그리기 실패: $e');
      _drawEmptyState(canvas, size);
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final TextPainter textPainter = TextPainter(
      text: const TextSpan(
        text: '수면 데이터 없음',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
          fontFamily: 'suit',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  List<SleepSegment> _processSleepData() {
    if (sleepData == null) return [];
    final DateTime bedTime = sleepData!.bedTime;
    final DateTime wakeTime = sleepData!.wakeTime;
    final List<SleepSegment> segments = [];

    print('');
    print('📊 _processSleepData() 호출됨');
    print('   └─ bedTime: $bedTime');
    print('   └─ wakeTime: $wakeTime');
    print('   └─ 총 수면 시간: ${wakeTime.difference(bedTime).inMinutes}분');

    // 디바이스 모드: ML 분석 결과 사용
    if (mlAnalysisResult != null && mlAnalysisResult!.stageIntervals.isNotEmpty) {
      print('   └─ ML 분석 결과 처리 시작 (${mlAnalysisResult!.stageIntervals.length}개)');
      
      // 🔍 전체 intervals의 시간 범위 확인
      if (mlAnalysisResult!.stageIntervals.isNotEmpty) {
        final firstInterval = mlAnalysisResult!.stageIntervals.first;
        final lastInterval = mlAnalysisResult!.stageIntervals.last;
        print('');
        print('   🕐 ML 서버가 분석한 전체 시간 범위:');
        print('      └─ 첫 interval: ${firstInterval.startTime}');
        print('      └─ 마지막 interval: ${lastInterval.endTime}');
        final mlStart = DateTime.parse(firstInterval.startTime).toLocal();
        final mlEnd = DateTime.parse(lastInterval.endTime).toLocal();
        print('      └─ 로컬 시간: $mlStart ~ $mlEnd');
        print('      └─ ML 분석 기간: ${mlEnd.difference(mlStart).inMinutes}분');
        print('');
      }
      
      int processedCount = 0;
      int skippedCount = 0;
      
      for (int i = 0; i < mlAnalysisResult!.stageIntervals.length; i++) {
        final StageInterval interval = mlAnalysisResult!.stageIntervals[i];
        
        SleepStage? stage;

        // ML 서버의 stage 값을 SleepStage enum으로 변환
        switch (interval.stage.toLowerCase()) {
          case 'wake':
            stage = SleepStage.awake;
            break;
          case 'rem':
            stage = SleepStage.rem;
            break;
          case 'n1':
          case 'n2':
            stage = SleepStage.core;
            break;
          case 'n3':
            stage = SleepStage.deep;
            break;
          default:
            continue;
        }

        // 🔧 UTC 시간을 로컬 시간으로 변환
        DateTime segmentStart = DateTime.parse(interval.startTime).toLocal();
        DateTime segmentEnd = DateTime.parse(interval.endTime).toLocal();

        // 🔍 처음 3개 interval만 상세 로그
        if (i < 3) {
          print('');
          print('   [$i] Interval 처리:');
          print('      └─ stage: ${interval.stage}');
          print('      └─ startTime (원본 UTC): ${interval.startTime}');
          print('      └─ endTime (원본 UTC): ${interval.endTime}');
          print('      └─ segmentStart (로컬 변환): $segmentStart');
          print('      └─ segmentEnd (로컬 변환): $segmentEnd');
          print('      └─ 기간: ${segmentEnd.difference(segmentStart).inMinutes}분');
        }

        // bedTime ~ wakeTime 범위 내로 제한
        if (segmentEnd.isBefore(bedTime) || segmentStart.isAfter(wakeTime)) {
          print('      └─ ⚠️ 범위 밖 - 스킵 (interval $i)');
          print('         segmentStart: $segmentStart');
          print('         segmentEnd: $segmentEnd');
          print('         bedTime: $bedTime');
          print('         wakeTime: $wakeTime');
          skippedCount++;
          continue;
        }
        if (segmentStart.isBefore(bedTime)) {
          segmentStart = bedTime;
        }
        if (segmentEnd.isAfter(wakeTime)) {
          segmentEnd = wakeTime;
        }

        if (segmentEnd.difference(segmentStart).inMinutes >= 1) {
          segments.add(SleepSegment(
            startTime: segmentStart,
            endTime: segmentEnd,
            stage: stage,
          ));
          processedCount++;
          
          if (i < 3) {
            print('      └─ ✅ segments에 추가됨');
          }
        } else {
          if (i < 3) {
            print('      └─ ⚠️ 기간이 너무 짧음 - 스킵');
          }
          skippedCount++;
        }
      }
      
      print('');
      print('   └─ 처리 완료: ${processedCount}개 추가, ${skippedCount}개 스킵');
      
      if (segments.isNotEmpty) {
        print('');
        print('   📊 추가된 segments 요약:');
        print('      └─ 첫 segment: ${segments.first.startTime} (${segments.first.stage})');
        print('      └─ 마지막 segment: ${segments.last.endTime} (${segments.last.stage})');
        
        // 전체 시간 범위 계산
        final totalCoverage = segments.last.endTime.difference(segments.first.startTime);
        print('      └─ segments가 커버하는 시간: ${totalCoverage.inMinutes}분');
        print('      └─ 실제 수면 시간: ${wakeTime.difference(bedTime).inMinutes}분');
      }
      print('');
    } 
    // 워치 모드: HealthKit 데이터 사용
    else if (rawDataPoints.isNotEmpty) {
      for (final HealthDataPoint point in rawDataPoints) {
        SleepStage? stage;
        switch (point.type) {
          case HealthDataType.SLEEP_AWAKE:
          case HealthDataType.SLEEP_AWAKE_IN_BED:
            stage = SleepStage.awake;
            break;
          case HealthDataType.SLEEP_REM:
            stage = SleepStage.rem;
            break;
          case HealthDataType.SLEEP_LIGHT:
          case HealthDataType.SLEEP_ASLEEP:
            stage = SleepStage.core;
            break;
          case HealthDataType.SLEEP_DEEP:
            stage = SleepStage.deep;
            break;
          default:
            continue;
        }
        DateTime segmentStart = point.dateFrom;
        DateTime segmentEnd = point.dateTo;
        if (segmentEnd.isBefore(bedTime) || segmentStart.isAfter(wakeTime)) {
          continue;
        }
        if (segmentStart.isBefore(bedTime)) {
          segmentStart = bedTime;
        }
        if (segmentEnd.isAfter(wakeTime)) {
          segmentEnd = wakeTime;
        }
        if (segmentEnd.difference(segmentStart).inMinutes >= 1) {
          segments.add(SleepSegment(
            startTime: segmentStart,
            endTime: segmentEnd,
            stage: stage,
          ));
        }
      }
    }

    segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    return segments;
  }

  void _drawStageLabels(
      Canvas canvas, Size size, double leftMargin, double graphBottom, double graphHeight) {
    final List<String> labels = ['깊은 수면', '코어 수면', 'REM 수면', '비수면'];
    final double stageHeight = graphHeight / 4;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (int i = 0; i < labels.length; i++) {
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 9,
          fontFamily: 'suit',
        ),
      );
      textPainter.layout();
      final double y = graphBottom -
          graphHeight +
          (i * stageHeight) +
          (stageHeight / 2) -
          (textPainter.height / 2);
      textPainter.paint(canvas, Offset(4, y));
    }
  }

  void _drawSleepConnections(
    Canvas canvas,
    List<SleepSegment> segments,
    DateTime startTime,
    Duration totalDuration,
    double leftMargin,
    double graphWidth,
    double graphBottom,
    double graphHeight,
  ) {
    if (segments.isEmpty) return;
    final double stageHeight = (graphHeight / 4) - 2;
    final Paint connectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < segments.length - 1; i++) {
      final SleepSegment current = segments[i];
      final SleepSegment next = segments[i + 1];
      final Duration currentOffset = current.endTime.difference(startTime);
      final Duration nextOffset = next.startTime.difference(startTime);
      final double currentProgress = currentOffset.inMinutes / totalDuration.inMinutes;
      final double nextProgress = nextOffset.inMinutes / totalDuration.inMinutes;
      final double currentX = leftMargin + (currentProgress * graphWidth);
      final double nextX = leftMargin + (nextProgress * graphWidth);
      final double currentY =
          _getStageY(current.stage, graphBottom, graphHeight, stageHeight) + stageHeight / 2;
      final double nextY =
          _getStageY(next.stage, graphBottom, graphHeight, stageHeight) + stageHeight / 2;
      if ((nextX - currentX).abs() < 10) {
        canvas.drawLine(Offset(currentX, currentY), Offset(nextX, nextY), connectionPaint);
      }
    }
  }

  double _getStageY(SleepStage stage, double graphBottom, double graphHeight, double stageHeight) {
    switch (stage) {
      case SleepStage.deep:
        return graphBottom - graphHeight + 1;
      case SleepStage.core:
        return graphBottom - graphHeight + stageHeight + 3;
      case SleepStage.rem:
        return graphBottom - graphHeight + (stageHeight * 2) + 5;
      case SleepStage.awake:
        return graphBottom - graphHeight + (stageHeight * 3) + 7;
    }
  }

  void _drawSleepBars(
    Canvas canvas,
    List<SleepSegment> segments,
    DateTime startTime,
    Duration totalDuration,
    double leftMargin,
    double graphWidth,
    double graphBottom,
    double graphHeight,
  ) {
    final double stageHeight = (graphHeight / 4) - 2;
    final Map<SleepStage, List<SleepSegment>> groupedSegments = {
      SleepStage.deep: [],
      SleepStage.core: [],
      SleepStage.rem: [],
      SleepStage.awake: [],
    };
    for (final segment in segments) {
      groupedSegments[segment.stage]?.add(segment);
    }
    for (final stage in SleepStage.values) {
      final List<SleepSegment> stageSegments = groupedSegments[stage] ?? [];
      if (stageSegments.isEmpty) continue;
      double stageY;
      Color color;
      switch (stage) {
        case SleepStage.deep:
          stageY = graphBottom - graphHeight + 1;
          color = const Color(0xFF3D5AFE);
          break;
        case SleepStage.core:
          stageY = graphBottom - graphHeight + stageHeight + 3;
          color = const Color(0xFF2196F3);
          break;
        case SleepStage.rem:
          stageY = graphBottom - graphHeight + (stageHeight * 2) + 5;
          color = const Color(0xFF64B5F6);
          break;
        case SleepStage.awake:
          stageY = graphBottom - graphHeight + (stageHeight * 3) + 7;
          color = const Color(0xFF90CAF9).withOpacity(0.6);
          break;
      }
      final Paint barPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (final segment in stageSegments) {
        try {
          final Duration offsetFromStart = segment.startTime.difference(startTime);
          final Duration segmentDuration = segment.endTime.difference(segment.startTime);

          // 유효하지 않은 시간 데이터 건너뛰기
          if (segmentDuration.inMinutes <= 0 || totalDuration.inMinutes <= 0) {
            continue;
          }

          final double progressStart = offsetFromStart.inMinutes / totalDuration.inMinutes;
          final double progressEnd =
              (offsetFromStart.inMinutes + segmentDuration.inMinutes) / totalDuration.inMinutes;

          // 진행률이 유효한 범위에 있는지 확인
          if (progressStart < 0 || progressStart > 1 || progressEnd < 0 || progressEnd > 1) {
            continue;
          }

          final double startX = leftMargin + (progressStart * graphWidth);
          final double endX = leftMargin + (progressEnd * graphWidth);

          // 좌표가 유효한지 확인
          if (startX.isNaN || endX.isNaN || startX < 0 || endX < 0) {
            continue;
          }

          final double rawWidth = endX - startX;
          final double availableWidth = graphWidth - (startX - leftMargin);
          final double minWidth = 2.0;
          final double maxWidth = availableWidth > minWidth ? availableWidth : minWidth;
          final double width = rawWidth.clamp(minWidth, maxWidth);

          // 최종 검증
          if (width.isNaN || width <= 0 || stageY.isNaN || stageHeight.isNaN) {
            continue;
          }

          final RRect rRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(startX, stageY, width, stageHeight),
            const Radius.circular(6),
          );
          canvas.drawRRect(rRect, barPaint);
        } catch (e) {
          // 개별 세그먼트 그리기 실패 시 건너뛰기
          print('수면 세그먼트 그리기 실패: $e');
          continue;
        }
      }
    }
  }

  void _drawTimeLabels(
    Canvas canvas,
    Size size,
    DateTime startTime,
    DateTime endTime,
    double leftMargin,
    double graphWidth,
    double graphBottom,
  ) {
    final Duration totalDuration = endTime.difference(startTime);
    final int totalMinutes = totalDuration.inMinutes;
    final int totalHours = totalDuration.inHours;
    final int intervalMinutes = totalHours <= 4 ? 60 : 120;
    final int labelCount = (totalMinutes / intervalMinutes).floor();
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (int i = 0; i <= labelCount; i++) {
      final int minutesOffset = i * intervalMinutes;
      final DateTime time = startTime.add(Duration(minutes: minutesOffset));
      final String timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      textPainter.text = TextSpan(
        text: timeStr,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 9,
          fontFamily: 'suit',
        ),
      );
      textPainter.layout();
      final double progress = minutesOffset / totalMinutes;
      final double x = leftMargin + (graphWidth * progress) - (textPainter.width / 2);
      final double y = graphBottom + 2;
      if (x >= 0 && x + textPainter.width <= size.width) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is SleepStageGraphPainter) {
      return oldDelegate.sleepData != sleepData || oldDelegate.rawDataPoints != rawDataPoints;
    }
    return true;
  }
}
