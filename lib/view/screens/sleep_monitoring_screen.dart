import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';
// import 'package:wakelock_plus/wakelock_plus.dart'; // 화면 자동 꺼짐 위해 제거

import '../../const/design_constants.dart';
import '../../services/sleep_recording_service.dart';

class SleepMonitoringScreen extends StatefulWidget {
  final TimeOfDay alarmTime;
  final Map<String, dynamic> sleepConditions;

  const SleepMonitoringScreen({
    super.key,
    required this.alarmTime,
    required this.sleepConditions,
  });

  @override
  State<SleepMonitoringScreen> createState() => _SleepMonitoringScreenState();
}

class _SleepMonitoringScreenState extends State<SleepMonitoringScreen> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  final SleepRecordingService _recordingService = SleepRecordingService();

  int? _selectedMusicIndex;
  bool _isSleepStarted = false;
  bool _isRecording = false;

  // 화면 밝기 관리 (배터리 절약)
  double? _originalBrightness;
  final ScreenBrightness _screenBrightness = ScreenBrightness();

  // 시간 업데이트 타이머
  Timer? _timeUpdateTimer;

  final List<Map<String, dynamic>> _musicList = [
    {
      'title': '숲의 정령이 머무는 곳',
      'icon': '🌱',
      'tags': ['숲소리', '잠파리는'],
    },
    {
      'title': '시골 마을에 누워 든는 흙벌레 소리',
      'icon': '🌿',
      'tags': ['숲소리', '귀뚜라미', '실교테'],
    },
    {
      'title': '별빛이 내려앉은 숲속 집터',
      'icon': '🎄',
      'tags': ['숲소리', '귀뚜라미', '목책문음'],
    },
    {
      'title': '잔잔한 파도와 별빛 가득한 바다',
      'icon': '🌊',
      'tags': ['숲소리', '명덕', '바드'],
    },
  ];

  final String _featuredMusic = '타닥타닥, 여름밤의 모닥불 옆에서';
  final String _featuredIcon = '🔥';

  Future<void> _startSleepMonitoring() async {
    print('🎤 ========================================');
    print('🎤 _startSleepMonitoring 호출됨');
    print('🎤 ========================================');

    // 먼저 마이크 권한 확인
    print('🎤 [1/5] 마이크 권한 상태 확인 중...');
    final microphoneStatus = await Permission.microphone.status;
    print('🎤 ✓ 현재 권한 상태: $microphoneStatus');
    print('🎤   - isGranted: ${microphoneStatus.isGranted}');
    print('🎤   - isDenied: ${microphoneStatus.isDenied}');
    print('🎤   - isPermanentlyDenied: ${microphoneStatus.isPermanentlyDenied}');
    print('🎤   - isRestricted: ${microphoneStatus.isRestricted}');
    print('🎤   - isLimited: ${microphoneStatus.isLimited}');

    // 권한이 허용되지 않은 경우 (notDetermined, denied, permanentlyDenied)
    if (!microphoneStatus.isGranted) {
      print('🎤 [2/5] 권한 미허용 - 앱 다이얼로그 표시');
      final shouldRequest = await _showPermissionDialog();
      print('🎤 ✓ 사용자 선택: ${shouldRequest == true ? "권한 요청 진행" : "취소"}');

      if (shouldRequest != true) {
        print('🎤 ❌ 사용자가 권한 요청 취소함');
        return;
      }

      // 권한 요청
      print('🎤 [3/5] iOS 시스템 권한 다이얼로그 호출 시작...');
      print('🎤 ⏳ Permission.microphone.request() 실행 중...');

      final newStatus = await Permission.microphone.request();

      print('🎤 [4/5] iOS 시스템 응답 수신');
      print('🎤 ✓ 권한 요청 결과: $newStatus');
      print('🎤   - isGranted: ${newStatus.isGranted}');
      print('🎤   - isDenied: ${newStatus.isDenied}');
      print('🎤   - isPermanentlyDenied: ${newStatus.isPermanentlyDenied}');

      if (!newStatus.isGranted) {
        print('🎤 ❌ 권한 거부됨 - 설정 안내 표시');
        _showPermissionDeniedDialog();
        return;
      }

      print('🎤 ✅ 권한 허용됨!');
    } else {
      print('🎤 ✅ 이미 권한이 허용되어 있음 - 바로 진행');
    }

    print('🎤 [5/5] 수면 모니터링 시작...');
    print('🎤 ========================================');

    try {
      setState(() {
        _isSleepStarted = true;
        _isRecording = true;
      });

      // 수면 녹음 시작 (가속도계 + 오디오)
      await _recordingService.startRecording();

      // TODO: 선택한 음악 재생
      if (_selectedMusicIndex != null) {
        print('음악 재생: ${_musicList[_selectedMusicIndex!]['title']}');
      }

      final sleepData = {
        'alarmTime': '${widget.alarmTime.hour}:${widget.alarmTime.minute}',
        'conditions': widget.sleepConditions,
        'selectedMusic':
            _selectedMusicIndex != null ? _musicList[_selectedMusicIndex!]['title'] : null,
        'startTime': DateTime.now().toIso8601String(),
      };

      print('수면 모니터링 시작: $sleepData');

      // 🔅 화면 밝기를 최소로 낮추고 wakelock 활성화 (배터리 절약)
      await _dimScreenForSleep();

      // ⏰ 시간 업데이트 타이머 시작 (1분마다)
      _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });

      // 사용자에게 화면 끄기 안내
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D1B69),
            title: const Row(
              children: [
                Icon(Icons.nightlight_round, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  '수면 측정 시작',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '수면 측정이 시작되었습니다.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildInstructionRow(
                  icon: Icons.power_settings_new,
                  title: '1. 전원 버튼을 눌러 화면을 끄세요',
                  description: 'iPhone 측면의 전원 버튼을 한 번 누르면 됩니다.',
                ),
                const SizedBox(height: 16),
                _buildInstructionRow(
                  icon: Icons.battery_charging_full,
                  title: '2. 충전기에 연결하세요 (권장)',
                  description: '밤새 측정 시 배터리 방전을 방지합니다.',
                ),
                const SizedBox(height: 16),
                _buildInstructionRow(
                  icon: Icons.sensors,
                  title: '3. 센서는 백그라운드에서 작동',
                  description: '화면이 꺼져도 소리와 움직임을 계속 측정합니다.',
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '수면 종료 시: 화면을 켜고\n이 앱으로 돌아와서\n"수면 종료하기" 버튼을 누르세요.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // TODO: 수면 중 화면으로 전환
      // Navigator.pushReplacement(...)
    } catch (e) {
      print('수면 모니터링 시작 실패: $e');
      setState(() {
        _isSleepStarted = false;
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('수면 모니터링 시작 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopSleepMonitoring() async {
    try {
      // 타이머 취소
      _timeUpdateTimer?.cancel();

      // 수면 녹음 중지
      await _recordingService.stopRecording();

      // 🔆 화면 밝기 복원
      await _restoreScreenBrightness();

      setState(() {
        _isRecording = false;
      });

      // 수면 데이터 분석 시작
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('수면 데이터 분석 중...'),
          backgroundColor: Color(0xFF2D1B69),
          duration: Duration(seconds: 3),
        ),
      );

      final result = await _recordingService.analyzeSleepData();

      print('수면 분석 완료:');
      print('  - 분석 ID: ${result.analysisId}');
      print('  - 총 수면 시간: ${result.summaryStatistics.totalSleepTime}분');
      print('  - 수면 효율: ${result.summaryStatistics.sleepEfficiency}');
      print('  - 데이터 품질: ${result.dataQualityScore}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ 수면 분석 완료!\n총 수면시간: ${result.summaryStatistics.totalSleepTime}분',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // TODO: 분석 결과 화면으로 이동
      // Navigator.pushReplacement(context, MaterialPageRoute(...))
    } catch (e) {
      print('수면 분석 실패: $e');

      // 401 에러 (토큰 만료) 확인
      final isTokenError = e.toString().contains('401') || 
                          e.toString().contains('토큰') ||
                          e.toString().contains('인증');

      if (mounted && isTokenError) {
        // 토큰 만료 시 명확한 안내
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D1B69),
            title: const Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text(
                  '로그인 세션 만료',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: const Text(
              '밤새 수면 측정 중 로그인 세션이 만료되었습니다.\n\n'
              '✅ 수면 데이터는 안전하게 저장되었습니다!\n\n'
              '다음 단계:\n'
              '1. 이 창을 닫고 로그아웃\n'
              '2. 다시 로그인\n'
              '3. 내 정보 > 수면 데이터 관리\n'
              '4. 저장된 데이터를 API로 재전송\n\n'
              '💡 데이터는 절대 손실되지 않았습니다!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (mounted) {
        // 기타 에러
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수면 분석 실패: $e\n\n데이터는 로컬에 저장되었습니다.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 화면을 완전히 끄고 백그라운드 모드 활성화 (최대 배터리 절약)
  Future<void> _dimScreenForSleep() async {
    try {
      // 현재 밝기 저장
      _originalBrightness = await _screenBrightness.current;
      print('🔅 원래 화면 밝기: $_originalBrightness');

      // 밝기를 완전히 0으로 설정
      await _screenBrightness.setScreenBrightness(0.0);
      print('🔅 화면 밝기를 완전히 꺼졌습니다 (0.0)');

      // 화면이 자동으로 꺼지도록 허용 (Wakelock 사용 안 함)
      // iOS는 백그라운드에서도 오디오/센서 작업을 계속할 수 있습니다
      print('📴 화면 자동 꺼짐 허용 - 사용자가 전원 버튼으로 화면을 끌 수 있습니다');
      print('🎤 오디오 녹음은 백그라운드에서 계속됩니다 (UIBackgroundModes: audio)');
      print('📱 센서 데이터도 백그라운드에서 계속 수집됩니다');
      
      // 시스템 UI 숨기기 (상태바, 네비게이션 바)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      print('📱 시스템 UI 숨김 - 전체 화면 모드');
    } catch (e) {
      print('⚠️ 화면 설정 실패: $e');
    }
  }

  /// 화면 밝기를 원래대로 복원하고 wakelock 비활성화
  Future<void> _restoreScreenBrightness() async {
    try {
      // 시스템 UI 복원
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      print('📱 시스템 UI 복원');

      if (_originalBrightness != null) {
        await _screenBrightness.setScreenBrightness(_originalBrightness!);
        print('🔆 화면 밝기 복원: $_originalBrightness');
      } else {
        // 기본값으로 복원
        await _screenBrightness.resetScreenBrightness();
        print('🔆 화면 밝기를 시스템 기본값으로 복원');
      }

      print('✅ 화면 설정 복원 완료');
    } catch (e) {
      print('⚠️ 화면 밝기 복원 실패: $e');
    }
  }

  @override
  void dispose() {
    // 타이머 취소
    _timeUpdateTimer?.cancel();

    // 화면 밝기 복원
    _restoreScreenBrightness();

    // async dispose이므로 unawaited로 호출
    _recordingService.dispose().then((_) {
      print('SleepMonitoringScreen - 녹음 서비스 정리 완료');
    }).catchError((error) {
      print('SleepMonitoringScreen - 녹음 서비스 정리 실패: $error');
    });
    super.dispose();
  }

  /// 권한 요청 다이얼로그
  Future<bool?> _showPermissionDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('마이크 권한 필요'),
        content: const Text(
          '수면 중 소리를 분석하여 수면 품질을 측정합니다.\n'
          '마이크 권한을 허용해주세요.\n\n'
          '※ 오디오 파일은 저장되지 않으며, dB 레벨만 측정됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D1B69),
              foregroundColor: Colors.white,
            ),
            child: const Text('허용'),
          ),
        ],
      ),
    );
  }

  /// 권한 거부 시 설정 화면으로 이동 안내
  Future<void> _showPermissionDeniedDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이크 권한 필요'),
        content: const Text(
          '마이크 권한이 거부되었습니다.\n'
          '수면 품질 측정을 위해 마이크 권한이 필요합니다.\n\n'
          '설정에서 마이크 권한을 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings(); // 설정 화면으로 이동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D1B69),
              foregroundColor: Colors.white,
            ),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showScheduleSettings() async {
    // TODO: 하루일 설정 다이얼로그 또는 화면 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('하루일 설정 기능은 개발 중입니다'),
        backgroundColor: Color(0xFF2D1B69),
      ),
    );
  }

  void _playMusic(int index) {
    setState(() {
      if (_selectedMusicIndex == index) {
        _selectedMusicIndex = null; // 같은 음악을 다시 누르면 중지
      } else {
        _selectedMusicIndex = index;
      }
    });

    // TODO: 음악 재생/중지 로직
    if (_selectedMusicIndex != null) {
      print('음악 재생: ${_musicList[index]['title']}');
    } else {
      print('음악 중지');
    }
  }

  /// 현재 시간을 문자열로 반환 (HH:MM 형식)
  String _getCurrentTimeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// 안내 사항 행 위젯
  Widget _buildInstructionRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMusicCard({
    required String title,
    required String icon,
    required List<String> tags,
    required int index,
    required bool isPlaying,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          // 제목과 태그
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'suit',
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4BA1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'suit',
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 재생 버튼
          GestureDetector(
            onTap: () => _playMusic(index),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPlaying ? const Color(0xFFD4C5F9) : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: isPlaying ? const Color(0xFF2D1B69) : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _isRecording ? Colors.black : const Color(0xFF2D1B69),
        body: Stack(
          children: [
            // 배경 이미지 (수면 중이 아닐 때만 표시)
            if (!_isRecording)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(DesignConstants.sleepModeImagePath),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      onError: (exception, stackTrace) {
                        print('수면 모드 배경 이미지 로드 실패: $exception');
                      },
                    ),
                    color: const Color(0xFF2D1B69),
                  ),
                ),
              ),
            // 수면 중일 때 검은 배경 + 최소 UI
            if (_isRecording)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 현재 시간
                        Text(
                          _getCurrentTimeString(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // 알람 시간
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.alarm,
                              color: Colors.white.withOpacity(0.2),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '알람 ${widget.alarmTime.format(context)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                        // 수면 종료 버튼 (희미하게)
                        GestureDetector(
                          onTap: _stopSleepMonitoring,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '수면 종료하기',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 콘텐츠 (수면 시작 전에만 표시)
            if (!_isRecording)
              SafeArea(
                child: Column(
                  children: [
                    // 상단 헤더
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 스크롤 가능한 콘텐츠
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          // 제목
                          const Text(
                            '오늘도 수고 많았어요 🛌',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 부제목
                          const Text(
                            '깊은 잠이 곧 시작될 거에요.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 24),
                          // 허용앱 설정 버튼
                          Center(
                            child: GestureDetector(
                              onTap: _showScheduleSettings,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.schedule,
                                      color: Color(0xFF2D1B69),
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '허용앱 설정',
                                      style: TextStyle(
                                        color: Color(0xFF2D1B69),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'suit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // 음악 리스트
                          ..._musicList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final music = entry.value;
                            return _buildMusicCard(
                              title: music['title'],
                              icon: music['icon'],
                              tags: List<String>.from(music['tags']),
                              index: index,
                              isPlaying: _selectedMusicIndex == index,
                            );
                          }).toList(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 하단 고정 버튼 (수면 시작 전에만 표시)
            if (!_isRecording)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF2D1B69).withOpacity(0),
                      const Color(0xFF2D1B69).withOpacity(0.8),
                      const Color(0xFF2D1B69),
                    ],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRecording ? _stopSleepMonitoring : _startSleepMonitoring,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : const Color(0xFFD4C5F9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording ? Icons.stop : Icons.bedtime,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecording ? '수면 종료하기' : '수면 시작하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'suit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
