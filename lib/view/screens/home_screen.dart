import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';

import '../../const/design_constants.dart';
import '../../models/sleep_data.dart';
import '../../services/health_service.dart';
import '../../services/sleep_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasHealthPermission = false;
  bool isLoading = true;
  SleepData? todaySleepData;
  List<HealthDataPoint> rawSleepDataPoints = [];
  final HealthService _healthService = HealthService();
  final SleepDataService _sleepDataService = SleepDataService();

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoadData();
  }

  Future<void> _checkPermissionAndLoadData() async {
    setState(() {
      isLoading = true;
    });
    final bool hasPermission = await _healthService.isHealthAppAvailable();
    setState(() {
      hasHealthPermission = hasPermission;
    });
    if (hasPermission) {
      await _loadTodaySleepData();
    }
    setState(() {
      isLoading = false;
    });
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
        print('HomeScreen - 가장 최근 수면: 취침 ${mostRecentSleep.bedTime}, 기상 ${mostRecentSleep.wakeTime}');
        final List<HealthDataPoint> relevantRawData = rawData.where((point) {
          return point.dateFrom.isAfter(mostRecentSleep.bedTime.subtract(const Duration(hours: 1))) &&
                 point.dateTo.isBefore(mostRecentSleep.wakeTime.add(const Duration(hours: 1)));
        }).toList();
        print('HomeScreen - 관련 원시 데이터 포인트 수: ${relevantRawData.length}');
        setState(() {
          todaySleepData = mostRecentSleep;
          rawSleepDataPoints = relevantRawData;
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(DesignConstants.homeScreenImagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                      : hasHealthPermission 
                          ? _buildSleepDataCard(screenWidth)
                          : _buildPermissionRequestCard(),
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
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '채원님,',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'malang',
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '좋은 아침이에요! ☀️',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'malang',
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '상쾌하게 하루를 시작해볼까요?',
          style: TextStyle(
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
            '수면 정보를 연동해서 클클과 함께해요 🛌',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'suit',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
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
            icon: const Icon(Icons.ios_share, size: 20),
            label: const Text(
              '수면 정보 불러오기',
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

  Widget _buildSleepDataCard(double screenWidth) {
    if (todaySleepData == null) {
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bedtime_outlined,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              '오늘의 수면 데이터가 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '수면 후 데이터가 자동으로 동기화됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'suit',
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }
    final int qualityScore = todaySleepData!.sleepQualityScore.round();
    final Duration actualSleepDuration = todaySleepData!.wakeTime.difference(todaySleepData!.bedTime);
    final int hours = actualSleepDuration.inHours;
    final int minutes = actualSleepDuration.inMinutes % 60;
    final String totalSleepTime = '${hours}시간 ${minutes}분';
    final String bedTimeStr = _formatTime(todaySleepData!.bedTime);
    final String wakeTimeStr = _formatTime(todaySleepData!.wakeTime);
    print('HomeScreen - 수면 시간 계산: ${actualSleepDuration.inMinutes}분 = ${hours}시간 ${minutes}분');
    return GestureDetector(
      onTap: () {
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

  Widget _buildWeeklyFriendsSection() {
    return Column(
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
              '진행 중인 클클 챌린지',
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
              '오늘의 클클 레터',
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
  final List<HealthDataPoint> rawDataPoints;

  SleepStageGraphPainter({
    this.sleepData,
    required this.rawDataPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sleepData == null || rawDataPoints.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }
    final List<SleepSegment> segments = _processSleepData();
    if (segments.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }
    final DateTime startTime = sleepData!.bedTime;
    final DateTime endTime = sleepData!.wakeTime;
    final Duration totalDuration = endTime.difference(startTime);
    final double graphHeight = size.height * 0.6;
    final double graphBottom = size.height * 0.75;
    final double leftMargin = 60.0;
    final double rightMargin = 8.0;
    final double graphWidth = size.width - leftMargin - rightMargin;
    _drawStageLabels(canvas, size, leftMargin, graphBottom, graphHeight);
    _drawSleepConnections(canvas, segments, startTime, totalDuration, leftMargin, graphWidth, graphBottom, graphHeight);
    _drawSleepBars(canvas, segments, startTime, totalDuration, leftMargin, graphWidth, graphBottom, graphHeight);
    _drawTimeLabels(canvas, size, startTime, endTime, leftMargin, graphWidth, graphBottom);
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
    segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    return segments;
  }

  void _drawStageLabels(Canvas canvas, Size size, double leftMargin, double graphBottom, double graphHeight) {
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
      final double y = graphBottom - graphHeight + (i * stageHeight) + (stageHeight / 2) - (textPainter.height / 2);
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
      final double currentY = _getStageY(current.stage, graphBottom, graphHeight, stageHeight) + stageHeight / 2;
      final double nextY = _getStageY(next.stage, graphBottom, graphHeight, stageHeight) + stageHeight / 2;
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
        final Duration offsetFromStart = segment.startTime.difference(startTime);
        final Duration segmentDuration = segment.endTime.difference(segment.startTime);
        final double progressStart = offsetFromStart.inMinutes / totalDuration.inMinutes;
        final double progressEnd = (offsetFromStart.inMinutes + segmentDuration.inMinutes) / totalDuration.inMinutes;
        final double startX = leftMargin + (progressStart * graphWidth);
        final double endX = leftMargin + (progressEnd * graphWidth);
        final double width = (endX - startX).clamp(2.0, graphWidth - (startX - leftMargin));
        final RRect rRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, stageY, width, stageHeight),
          const Radius.circular(6),
        );
        canvas.drawRRect(rRect, barPaint);
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
      final String timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
