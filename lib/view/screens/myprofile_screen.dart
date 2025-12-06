import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../const/design_constants.dart';
import '../../services/oauth_service.dart';
import '../../services/user_service.dart';
import 'sleep_data_management_screen.dart';

class MyprofileScreen extends StatefulWidget {
  const MyprofileScreen({super.key});

  @override
  State<MyprofileScreen> createState() => _MyprofileScreenState();
}

class _MyprofileScreenState extends State<MyprofileScreen> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  String _nickname = '사용자';
  String _email = '';
  String _profileImageUrl = '';
  bool _isMicrophoneGranted = false;
  String _sleepMeasurementDevice = 'device'; // 'device' 또는 'watch'
  int _sleepGoalHours = 7; // 수면 목표 시간 (기본값: 7시간)

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkMicrophonePermission();
    _loadSleepMeasurementDevice();
    _loadSleepGoal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 보여질 때마다 권한 상태와 디바이스 설정 재확인
    _checkMicrophonePermission();
    _loadSleepMeasurementDevice();
    _loadSleepGoal();
  }

  Future<void> _loadUserInfo() async {
    await UserService.loadUserInfo();
    setState(() {
      _nickname = UserService.getUserNickname();
      _email = UserService.getUserEmail();
      _profileImageUrl = UserService.getUserProfileImageUrl();
    });
  }

  /// 마이크 권한 상태 확인
  Future<void> _checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    setState(() {
      _isMicrophoneGranted = status.isGranted;
    });
  }

  /// Keychain 데이터 삭제
  Future<void> _clearKeychain() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Keychain 데이터 삭제'),
        content: const Text(
          '저장된 모든 데이터가 삭제됩니다:\n'
          '• JWT 토큰\n'
          '• 사용자 정보\n'
          '• 알람 설정\n\n'
          '이 작업은 되돌릴 수 없습니다.\n'
          '계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OAuthService.clearAllStoredData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Keychain 데이터가 삭제되었습니다. 앱을 재시작해주세요.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // 로그아웃 처리
      await _handleLogout();
    }
  }

  /// 마이크 권한 요청
  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      _showPermissionGrantedDialog();
      return;
    }

    if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog();
      return;
    }

    // 권한 요청
    final result = await Permission.microphone.request();
    
    setState(() {
      _isMicrophoneGranted = result.isGranted;
    });

    if (result.isGranted) {
      _showPermissionGrantedDialog();
    } else if (result.isPermanentlyDenied) {
      _showOpenSettingsDialog();
    } else {
      _showPermissionDeniedSnackBar();
    }
  }

  /// 권한 허용됨 다이얼로그
  void _showPermissionGrantedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이크 권한 허용됨'),
        content: const Text('수면 품질 측정을 위한 마이크 권한이 허용되었습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 설정 화면 열기 다이얼로그
  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이크 권한 설정'),
        content: const Text(
          '마이크 권한이 거부되었습니다.\n'
          '수면 품질 측정을 위해 설정에서 마이크 권한을 허용해주세요.\n\n'
          '※ 오디오 파일은 저장되지 않으며, dB 레벨만 측정됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
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

  /// 권한 거부 스낵바
  void _showPermissionDeniedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('마이크 권한이 거부되었습니다'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: '설정',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  /// 수면 측정 디바이스 설정 로드
  Future<void> _loadSleepMeasurementDevice() async {
    try {
      final device = await _storage.read(key: 'sleep_measurement_device');
      setState(() {
        _sleepMeasurementDevice = device ?? 'device';
      });
      print('✅ 수면 측정 디바이스 로드: $_sleepMeasurementDevice');
    } catch (e) {
      print('⚠️ 수면 측정 디바이스 로드 실패: $e');
    }
  }

  /// 수면 측정 디바이스 설정 저장
  Future<void> _saveSleepMeasurementDevice(String device) async {
    try {
      await _storage.write(key: 'sleep_measurement_device', value: device);
      setState(() {
        _sleepMeasurementDevice = device;
      });
      print('✅ 수면 측정 디바이스 저장: $device');
    } catch (e) {
      print('⚠️ 수면 측정 디바이스 저장 실패: $e');
    }
  }

  /// 수면 목표 시간 로드
  Future<void> _loadSleepGoal() async {
    try {
      final goalString = await _storage.read(key: 'sleep_goal_hours');
      if (goalString != null) {
        final hours = int.tryParse(goalString);
        if (hours != null && hours >= 4 && hours <= 12) {
          setState(() {
            _sleepGoalHours = hours;
          });
          print('✅ 수면 목표 로드: $_sleepGoalHours시간');
        }
      }
    } catch (e) {
      print('⚠️ 수면 목표 로드 실패: $e');
    }
  }

  /// 수면 목표 시간 저장
  Future<void> _saveSleepGoal(int hours) async {
    try {
      await _storage.write(key: 'sleep_goal_hours', value: hours.toString());
      setState(() {
        _sleepGoalHours = hours;
      });
      print('✅ 수면 목표 저장: $hours시간');
    } catch (e) {
      print('⚠️ 수면 목표 저장 실패: $e');
    }
  }

  /// 수면 측정 디바이스 선택 다이얼로그
  Future<void> _showSleepMeasurementDeviceDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.devices, color: Color(0xFF2D1B69)),
            SizedBox(width: 12),
            Text('수면 측정 디바이스'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '수면 데이터를 어떻게 측정하시겠습니까?',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            _buildDeviceOption(
              value: 'device',
              icon: Icons.smartphone,
              title: '디바이스로 측정',
              description: '스마트폰의 센서를 사용하여\n수면을 측정합니다.',
              isSelected: _sleepMeasurementDevice == 'device',
            ),
            const SizedBox(height: 16),
            _buildDeviceOption(
              value: 'watch',
              icon: Icons.watch,
              title: '워치 데이터',
              description: 'Apple Watch 등 웨어러블\n기기의 HealthKit 데이터를 사용합니다.',
              isSelected: _sleepMeasurementDevice == 'watch',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (selected != null && selected != _sleepMeasurementDevice) {
      await _saveSleepMeasurementDevice(selected);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected == 'device'
                  ? '✅ 디바이스로 측정이 선택되었습니다'
                  : '✅ 워치 데이터가 선택되었습니다',
            ),
            backgroundColor: const Color(0xFF2D1B69),
          ),
        );
      }
    }
  }

  /// 수면 목표 선택 다이얼로그
  Future<void> _showSleepGoalDialog() async {
    int tempSelectedHours = _sleepGoalHours; // 임시 선택값

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D1B69),
                  Color(0xFF1A0E3F),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.nightlight_round,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '수면 목표 설정',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'suit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '하루에 몇 시간 수면을 목표로 하시나요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontFamily: 'suit',
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 시간 선택 리스트
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 9, // 4시간 ~ 12시간
                      itemBuilder: (context, index) {
                        final hours = 4 + index;
                        return _buildSleepGoalOptionWithCheck(
                          hours: hours,
                          isSelected: hours == tempSelectedHours,
                          onTap: () {
                            setDialogState(() {
                              tempSelectedHours = hours;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                
                // 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'suit',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2D1B69),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'suit',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && tempSelectedHours != _sleepGoalHours) {
      await _saveSleepGoal(tempSelectedHours);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ 수면 목표가 하루 $tempSelectedHours시간으로 설정되었습니다',
              style: const TextStyle(fontFamily: 'suit'),
            ),
            backgroundColor: const Color(0xFF2D1B69),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// 수면 목표 시간 옵션 위젯 (체크 선택 방식)
  Widget _buildSleepGoalOptionWithCheck({
    required int hours,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    String getRecommendation() {
      if (hours < 6) return '너무 짧아요 😴';
      if (hours >= 6 && hours <= 8) return '권장 수면 시간 ✨';
      if (hours > 8 && hours <= 10) return '충분한 휴식 😊';
      return '긴 수면 시간 💤';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
            ? Colors.white.withOpacity(0.25) 
            : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected 
              ? Colors.white.withOpacity(0.6) 
              : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 시간 표시
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFE8E8FF)],
                    )
                  : null,
                color: isSelected ? null : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                    ? Colors.white.withOpacity(0.5) 
                    : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$hours',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected 
                      ? const Color(0xFF2D1B69) 
                      : Colors.white,
                    fontFamily: 'suit',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            
            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$hours시간',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                        ? Colors.white 
                        : Colors.white.withOpacity(0.9),
                      fontFamily: 'suit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    getRecommendation(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.6),
                      fontFamily: 'suit',
                    ),
                  ),
                ],
              ),
            ),
            
            // 체크 아이콘
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                  ? Colors.white 
                  : Colors.transparent,
                border: Border.all(
                  color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Color(0xFF2D1B69),
                    size: 18,
                  )
                : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 디바이스 선택 옵션 위젯
  Widget _buildDeviceOption({
    required String value,
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D1B69).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D1B69) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2D1B69) : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF2D1B69) : Colors.black87,
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
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2D1B69),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await OAuthService.logout();
      await UserService.clearUserInfo();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print('로그아웃 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                      print('내 프로필 배경 이미지 로드 실패: $exception');
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // 최상단: 프로필 이미지 + 유저네임
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          backgroundImage:
                              _profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) : null,
                          child: _profileImageUrl.isEmpty
                              ? const Icon(Icons.person, size: 45, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nickname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'suit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 상단: 내 포인트, 내가 쓴 글, 고객센터
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTopButton(
                            icon: '💰',
                            label: '내 포인트',
                            onTap: () => _showComingSoon(context),
                          ),
                          _buildTopButton(
                            icon: '📝',
                            label: '내가 쓴 글',
                            onTap: () => _showComingSoon(context),
                          ),
                          _buildTopButton(
                            icon: '❓',
                            label: '고객센터',
                            onTap: () => _showComingSoon(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 중간: 메뉴 리스트
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _buildMenuItem(
                              icon: Icons.bar_chart_rounded,
                              title: '수면 데이터 확인하기',
                              subtitle: 'HealthKit & 디바이스 데이터 비교',
                              onTap: () {
                                context.push('/integrated-sleep-data');
                              },
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.nightlight_round,
                              title: '수면 목표',
                              subtitle: '하루 $_sleepGoalHours시간 😴',
                              onTap: _showSleepGoalDialog,
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.devices,
                              title: '수면 측정 디바이스',
                              subtitle: _sleepMeasurementDevice == 'device' 
                                ? '디바이스로 측정 📱' 
                                : '워치 데이터 ⌚',
                              onTap: _showSleepMeasurementDeviceDialog,
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.mic,
                              title: '마이크 권한',
                              subtitle: _isMicrophoneGranted ? '허용됨 ✅' : '거부됨 ❌',
                              onTap: _requestMicrophonePermission,
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.folder_outlined,
                              title: '수면 데이터 관리 (개발용)',
                              subtitle: '로컬 저장된 수면 데이터 보기',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SleepDataManagementScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.delete_sweep,
                              title: 'Keychain 데이터 삭제 (디버그)',
                              subtitle: '테스트용 - 앱 재설치 시 자동 삭제됨',
                              onTap: _clearKeychain,
                              isDestructive: true,
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.logout,
                              title: '로그아웃',
                              onTap: _handleLogout,
                              isDestructive: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 버튼 (내 포인트, 내가 쓴 글, 고객센터)
  Widget _buildTopButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 메뉴 아이템
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red.shade300 : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red.shade300 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'suit',
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontFamily: 'suit',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive ? Colors.red.shade300 : Colors.white.withOpacity(0.7),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // 구분선
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withOpacity(0.1),
      ),
    );
  }

  // "추후 개발 예정입니다" 메시지
  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '추후 개발 예정입니다',
          style: TextStyle(fontFamily: 'suit'),
        ),
        backgroundColor: Colors.deepPurple.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
