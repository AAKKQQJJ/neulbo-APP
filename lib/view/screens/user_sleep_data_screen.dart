import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/sleep_data.dart';
// import '../../services/sleep_data_service.dart'; // 임시 비활성화

class UserSleepDataScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserSleepDataScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserSleepDataScreen> createState() => _UserSleepDataScreenState();
}

class _UserSleepDataScreenState extends State<UserSleepDataScreen> {
  // final SleepDataService _sleepDataService = SleepDataService(); // 임시 비활성화
  SleepData? _sleepData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSleepData();
  }

  /// 더미 수면 데이터 생성 (실제 구현 시 API에서 가져와야 함)
  SleepData _createDummySleepData(DateTime date) {
    final bedTime = DateTime(date.year, date.month, date.day, 23, 30);
    final sleepTime = DateTime(date.year, date.month, date.day + 1, 0, 15);
    final wakeTime = DateTime(date.year, date.month, date.day + 1, 7, 30);
    
    return SleepData(
      id: 'dummy_${date.millisecondsSinceEpoch}',
      sleepDate: date,
      bedTime: bedTime,
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      totalSleepDuration: const Duration(hours: 7, minutes: 15),
      deepSleepDuration: const Duration(hours: 1, minutes: 45),
      lightSleepDuration: const Duration(hours: 4, minutes: 30),
      remSleepDuration: const Duration(hours: 1, minutes: 0),
      awakeTimeDuration: const Duration(minutes: 15),
      sleepQualityScore: 82.5,
      sourceId: 'apple_watch_dummy',
      recordedAt: DateTime.now(),
    );
  }

  Future<void> _loadSleepData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 전날 수면 데이터 조회 (어제 날짜)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      // 임시로 더미 데이터 사용 (실제 구현 시 API 연동 필요)
      final sleepData = _createDummySleepData(yesterday);
      
      setState(() {
        _sleepData = sleepData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      // 더미 데이터로 대체 (개발용)
      _loadDummySleepData();
    }
  }

  void _loadDummySleepData() {
    setState(() {
      _sleepData = SleepData(
        id: 'dummy_sleep_data',
        sleepDate: DateTime.now().subtract(const Duration(days: 1)),
        bedTime: DateTime.now().subtract(const Duration(days: 1, hours: 14)),
        sleepTime: DateTime.now().subtract(const Duration(days: 1, hours: 13, minutes: 30)),
        wakeTime: DateTime.now().subtract(const Duration(hours: 2)),
        totalSleepDuration: const Duration(hours: 7, minutes: 30),
        deepSleepDuration: const Duration(hours: 2, minutes: 15),
        remSleepDuration: const Duration(hours: 1, minutes: 45),
        lightSleepDuration: const Duration(hours: 3, minutes: 30),
        awakeTimeDuration: const Duration(minutes: 30),
        sleepQualityScore: 78.0,
        sourceId: 'apple_watch_dummy',
        recordedAt: DateTime.now(),
      );
      _isLoading = false;
    });
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            '${widget.userName}의 수면 데이터',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : _sleepData != null
                      ? _buildSleepDataContent()
                      : _buildNoDataWidget(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            '데이터를 불러올 수 없습니다',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadSleepData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2D1B69),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bedtime_outlined,
            color: Colors.white,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            '수면 데이터가 없습니다',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '전날 수면 데이터를 찾을 수 없습니다',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepDataContent() {
    final sleepData = _sleepData!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 수면 점수 카드
          _buildSleepScoreCard(sleepData),
          
          const SizedBox(height: 16),
          
          // 수면 시간 정보
          _buildSleepTimeCard(sleepData),
          
          const SizedBox(height: 16),
          
          // 수면 단계 분석
          _buildSleepStagesCard(sleepData),
          
          const SizedBox(height: 16),
          
          // 심박수 정보
          _buildHeartRateCard(sleepData),
        ],
      ),
    );
  }

  Widget _buildSleepScoreCard(SleepData sleepData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '수면 점수',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D1B69),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: sleepData.sleepQualityScore / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getSleepScoreColor(sleepData.sleepQualityScore.toInt()),
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${sleepData.sleepQualityScore.toInt()}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D1B69),
                    ),
                  ),
                  const Text(
                    '점',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2D1B69),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            _getSleepScoreDescription(sleepData.sleepQualityScore.toInt()),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTimeCard(SleepData sleepData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수면 시간',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D1B69),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  '취침 시간',
                  _formatTime(sleepData.bedTime),
                  Icons.bedtime,
                ),
              ),
              Expanded(
                child: _buildTimeInfo(
                  '기상 시간',
                  _formatTime(sleepData.wakeTime),
                  Icons.wb_sunny,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  '총 수면 시간',
                  _formatDuration(sleepData.totalSleepDuration),
                  Icons.schedule,
                ),
              ),
              Expanded(
                child: _buildTimeInfo(
                  '수면 효율',
                  '${sleepData.sleepEfficiency.toStringAsFixed(1)}%',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF6B46C1),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D1B69),
          ),
        ),
      ],
    );
  }

  Widget _buildSleepStagesCard(SleepData sleepData) {
    final totalMinutes = sleepData.totalSleepDuration.inMinutes;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수면 단계 분석',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D1B69),
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildSleepStageBar(sleepData, totalMinutes),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStageInfo(
                  '깊은 잠',
                  _formatDuration(sleepData.deepSleepDuration),
                  const Color(0xFF1E40AF),
                ),
              ),
              Expanded(
                child: _buildStageInfo(
                  'REM 수면',
                  _formatDuration(sleepData.remSleepDuration),
                  const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStageInfo(
                  '얕은 잠',
                  _formatDuration(sleepData.lightSleepDuration),
                  const Color(0xFF06B6D4),
                ),
              ),
              Expanded(
                child: _buildStageInfo(
                  '깨어있음',
                  _formatDuration(sleepData.awakeTimeDuration),
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepStageBar(SleepData sleepData, int totalMinutes) {
    final deepPercent = sleepData.deepSleepDuration.inMinutes / totalMinutes;
    final remPercent = sleepData.remSleepDuration.inMinutes / totalMinutes;
    final lightPercent = sleepData.lightSleepDuration.inMinutes / totalMinutes;
    final awakePercent = sleepData.awakeTimeDuration.inMinutes / totalMinutes;
    
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (deepPercent > 0)
            Expanded(
              flex: (deepPercent * 100).round(),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E40AF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
          if (remPercent > 0)
            Expanded(
              flex: (remPercent * 100).round(),
              child: Container(
                color: const Color(0xFF7C3AED),
              ),
            ),
          if (lightPercent > 0)
            Expanded(
              flex: (lightPercent * 100).round(),
              child: Container(
                color: const Color(0xFF06B6D4),
              ),
            ),
          if (awakePercent > 0)
            Expanded(
              flex: (awakePercent * 100).round(),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStageInfo(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D1B69),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateCard(SleepData sleepData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '심박수',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D1B69),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildHeartRateInfo(
                  '평균',
                  '72 bpm', // 임시 하드코딩 (실제 구현 시 API에서 가져와야 함)
                  Icons.favorite,
                  const Color(0xFFEF4444),
                ),
              ),
              Expanded(
                child: _buildHeartRateInfo(
                  '최소',
                  '58 bpm', // 임시 하드코딩
                  Icons.trending_down,
                  const Color(0xFF06B6D4),
                ),
              ),
              Expanded(
                child: _buildHeartRateInfo(
                  '최대',
                  '85 bpm', // 임시 하드코딩
                  Icons.trending_up,
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateInfo(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D1B69),
          ),
        ),
      ],
    );
  }

  Color _getSleepScoreColor(int score) {
    if (score >= 80) {
      return const Color(0xFF10B981); // 녹색
    } else if (score >= 60) {
      return const Color(0xFFF59E0B); // 주황색
    } else {
      return const Color(0xFFEF4444); // 빨간색
    }
  }

  String _getSleepScoreDescription(int score) {
    if (score >= 80) {
      return '훌륭한 수면이었습니다!';
    } else if (score >= 60) {
      return '괜찮은 수면이었습니다.';
    } else {
      return '수면의 질을 개선해보세요.';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours시간 $minutes분';
  }
}
