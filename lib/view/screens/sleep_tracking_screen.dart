import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../const/design_constants.dart';
import 'sleep_monitoring_screen.dart';

class SleepTrackingScreen extends StatefulWidget {
  final TimeOfDay alarmTime;

  const SleepTrackingScreen({
    super.key,
    required this.alarmTime,
  });

  @override
  State<SleepTrackingScreen> createState() => _SleepTrackingScreenState();
}

class _SleepTrackingScreenState extends State<SleepTrackingScreen> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final Set<String> _selectedMoods = {};
  final Set<String> _selectedActivities = {};
  final Set<String> _selectedConditions = {};

  Future<void> _continueSleep() async {
    final sleepConditions = {
      'moods': _selectedMoods.toList(),
      'activities': _selectedActivities.toList(),
      'conditions': _selectedConditions.toList(),
    };

    // 수면 모니터링 화면으로 이동
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SleepMonitoringScreen(
          alarmTime: widget.alarmTime,
          sleepConditions: sleepConditions,
        ),
      ),
    );
  }

  Widget _buildMoodChip({
    required String label,
    required String emoji,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedMoods.remove(value);
          } else {
            _selectedMoods.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2D1B69) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChip({
    required String label,
    required String emoji,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedActivities.remove(value);
          } else {
            _selectedActivities.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2D1B69) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionChip({
    required String label,
    required String emoji,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedConditions.remove(value);
          } else {
            _selectedConditions.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2D1B69) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
              ),
            ),
          ],
        ),
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
        backgroundColor: const Color(0xFF2D1B69),
        body: Stack(
          children: [
            // 배경 이미지
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
                          const SizedBox(height: 8),
                          // 제목
                          const Text(
                            '오늘은 어떤 하루였나요?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 설명
                          const Text(
                            '들려주시면 수면 분석에 도움이 될 거예요 ☁️',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 32),
                          // 기분 섹션
                          const Text(
                            '기분',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMoodChip(
                                label: '편안',
                                emoji: '😌',
                                value: 'peaceful',
                                isSelected: _selectedMoods.contains('peaceful'),
                              ),
                              _buildMoodChip(
                                label: '피곤',
                                emoji: '😩',
                                value: 'tired',
                                isSelected: _selectedMoods.contains('tired'),
                              ),
                              _buildMoodChip(
                                label: '불안',
                                emoji: '😰',
                                value: 'anxious',
                                isSelected: _selectedMoods.contains('anxious'),
                              ),
                              _buildMoodChip(
                                label: '우울',
                                emoji: '😔',
                                value: 'depressed',
                                isSelected: _selectedMoods.contains('depressed'),
                              ),
                              _buildMoodChip(
                                label: '긴장',
                                emoji: '😬',
                                value: 'tense',
                                isSelected: _selectedMoods.contains('tense'),
                              ),
                              _buildMoodChip(
                                label: '슬픔',
                                emoji: '😢',
                                value: 'sad',
                                isSelected: _selectedMoods.contains('sad'),
                              ),
                              _buildMoodChip(
                                label: '스트레스',
                                emoji: '😵',
                                value: 'stressed',
                                isSelected: _selectedMoods.contains('stressed'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // 취침 전 활동 섹션
                          const Text(
                            '취침 전 활동',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildActivityChip(
                                label: '커피',
                                emoji: '☕️',
                                value: 'coffee',
                                isSelected: _selectedActivities.contains('coffee'),
                              ),
                              _buildActivityChip(
                                label: '야식',
                                emoji: '🍕',
                                value: 'lateSnack',
                                isSelected: _selectedActivities.contains('lateSnack'),
                              ),
                              _buildActivityChip(
                                label: '낮잠',
                                emoji: '💤',
                                value: 'nap',
                                isSelected: _selectedActivities.contains('nap'),
                              ),
                              _buildActivityChip(
                                label: '독서',
                                emoji: '📚',
                                value: 'reading',
                                isSelected: _selectedActivities.contains('reading'),
                              ),
                              _buildActivityChip(
                                label: '공부',
                                emoji: '✏️',
                                value: 'studying',
                                isSelected: _selectedActivities.contains('studying'),
                              ),
                              _buildActivityChip(
                                label: '운동',
                                emoji: '🏃',
                                value: 'exercise',
                                isSelected: _selectedActivities.contains('exercise'),
                              ),
                              _buildActivityChip(
                                label: '핸드폰',
                                emoji: '📱',
                                value: 'phone',
                                isSelected: _selectedActivities.contains('phone'),
                              ),
                              _buildActivityChip(
                                label: '사워',
                                emoji: '🛀',
                                value: 'shower',
                                isSelected: _selectedActivities.contains('shower'),
                              ),
                              _buildActivityChip(
                                label: '스트레칭',
                                emoji: '🧘',
                                value: 'stretching',
                                isSelected: _selectedActivities.contains('stretching'),
                              ),
                              _buildActivityChip(
                                label: '음주',
                                emoji: '🍺',
                                value: 'alcohol',
                                isSelected: _selectedActivities.contains('alcohol'),
                              ),
                              _buildActivityChip(
                                label: '흡연',
                                emoji: '🚬',
                                value: 'smoking',
                                isSelected: _selectedActivities.contains('smoking'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // 상태 섹션
                          const Text(
                            '상태',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'suit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildConditionChip(
                                label: '두통',
                                emoji: '🤕',
                                value: 'headache',
                                isSelected: _selectedConditions.contains('headache'),
                              ),
                              _buildConditionChip(
                                label: '감기',
                                emoji: '🤧',
                                value: 'cold',
                                isSelected: _selectedConditions.contains('cold'),
                              ),
                              _buildConditionChip(
                                label: '열',
                                emoji: '🤒',
                                value: 'fever',
                                isSelected: _selectedConditions.contains('fever'),
                              ),
                              _buildConditionChip(
                                label: '소화불량',
                                emoji: '💨',
                                value: 'indigestion',
                                isSelected: _selectedConditions.contains('indigestion'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 하단 고정 버튼
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
                    onPressed: _continueSleep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4C5F9),
                      foregroundColor: const Color(0xFF2D1B69),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '계속하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'suit',
                      ),
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
