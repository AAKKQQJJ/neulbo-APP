import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../const/design_constants.dart';
import '../../services/user_service.dart';
import 'sleep_tracking_screen.dart';

class SleepmodeScreen extends StatefulWidget {
  const SleepmodeScreen({super.key});

  @override
  State<SleepmodeScreen> createState() => _SleepmodeScreenState();
}

class _SleepmodeScreenState extends State<SleepmodeScreen> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  static const String _alarmTimeKey = 'alarm_time';

  TimeOfDay? _alarmTime;
  String _userName = '사용자';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAlarmTime();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    await UserService.loadUserInfo();
    final nickname = UserService.getUserNickname();

    setState(() {
      _userName = nickname;
      _isLoading = false;
    });
  }

  Future<void> _loadAlarmTime() async {
    try {
      final savedTime = await _storage.read(key: _alarmTimeKey);
      if (savedTime != null) {
        final parts = savedTime.split(':');
        if (parts.length == 2) {
          setState(() {
            _alarmTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          });
        }
      }
    } catch (e) {
      print('알람 시간 로드 실패: $e');
    }
  }

  Future<void> _saveAlarmTime(TimeOfDay time) async {
    try {
      await _storage.write(
        key: _alarmTimeKey,
        value: '${time.hour}:${time.minute}',
      );
      setState(() {
        _alarmTime = time;
      });
    } catch (e) {
      print('알람 시간 저장 실패: $e');
    }
  }

  Future<void> _selectAlarmTime(BuildContext context) async {
    final now = DateTime.now();
    DateTime initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _alarmTime?.hour ?? now.hour,
      _alarmTime?.minute ?? now.minute,
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        DateTime tempPickedDate = initialDateTime;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: 380,
            decoration: const BoxDecoration(
              color: Color(0xFF2D1B69),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontFamily: 'suit',
                          ),
                        ),
                      ),
                      const Text(
                        '알람 시간',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'suit',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final pickedTime = TimeOfDay(
                            hour: tempPickedDate.hour,
                            minute: tempPickedDate.minute,
                          );
                          _saveAlarmTime(pickedTime);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            color: Color(0xFFD4C5F9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'suit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // CupertinoDatePicker
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontFamily: 'suit',
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialDateTime,
                      use24hFormat: true,
                      backgroundColor: const Color(0xFF2D1B69),
                      onDateTimeChanged: (DateTime newDateTime) {
                        tempPickedDate = newDateTime;
                      },
                    ),
                  ),
                ),
                // 하단 여백
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour : $minute';
  }

  Future<void> _startSleep() async {
    if (_alarmTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알람 시간을 먼저 설정해주세요'),
          backgroundColor: Color(0xFF2D1B69),
        ),
      );
      return;
    }

    // 수면 추적 화면으로 이동 (바텀 네비게이션 바 없이)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SleepTrackingScreen(alarmTime: _alarmTime!),
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 반응형 배경 이미지
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
            // 콘텐츠
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // 사용자 이름 표시
                    Text(
                      '${_userName}님',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'suit',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 안내 메시지
                    const Text(
                      '이제 잘 시간이에요.\n몇 시에 깨워드릴까요? ⏰',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'suit',
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    // 알람 시간 표시 영역 (클릭 가능)
                    GestureDetector(
                      onTap: () => _selectAlarmTime(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
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
                            // 시계 아이콘
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.access_time,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 20),
                            // 시간 표시
                            Expanded(
                              child: Text(
                                _alarmTime != null ? _formatTime(_alarmTime!) : '-- : -- --',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'suit',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 수면 시작 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startSleep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4C5F9),
                          foregroundColor: const Color(0xFF2D1B69),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '수면 시작하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'suit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
