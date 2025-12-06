import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/friend_sleep_data.dart';
import '../../services/friend_service.dart';

class FriendSleepDetailScreen extends StatefulWidget {
  final String friendId;
  final String friendNickname;

  const FriendSleepDetailScreen({
    super.key,
    required this.friendId,
    required this.friendNickname,
  });

  @override
  State<FriendSleepDetailScreen> createState() => _FriendSleepDetailScreenState();
}

class _FriendSleepDetailScreenState extends State<FriendSleepDetailScreen> {
  FriendSleepData? _friendSleepData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriendSleepData();
  }

  Future<void> _loadFriendSleepData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // 최근 7일 데이터를 가져오기 위해 날짜 범위 설정
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 6)); // 7일 전부터 오늘까지

      final data = await FriendService.getFriendSleepScores(
        friendId: widget.friendId,
        startDate: DateFormat('yyyy-MM-dd').format(startDate),
        endDate: DateFormat('yyyy-MM-dd').format(endDate),
      );
      setState(() {
        _friendSleepData = data;
      });
    } catch (e) {
      print('❌ 친구 수면 데이터 로딩 에러: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours}시간 ${remainingMinutes}분';
    }
    return '${remainingMinutes}분';
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            '${widget.friendNickname}님의 수면 데이터',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '데이터 로딩 오류: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.withValues(alpha: 0.8), fontSize: 16),
                      ),
                    ),
                  )
                : _friendSleepData == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sentiment_dissatisfied,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${widget.friendNickname}님의 수면 데이터를 찾을 수 없습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '친구의 데이터가 비공개이거나 아직 기록되지 않았을 수 있습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFriendProfileSection(),
                            const SizedBox(height: 24),
                            _buildStatisticsSection(),
                            const SizedBox(height: 24),
                            _buildRecentScoresSection(),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildFriendProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFF6B46C1),
            backgroundImage: (_friendSleepData!.friendProfileImage != null && _friendSleepData!.friendProfileImage!.isNotEmpty)
                ? NetworkImage(_friendSleepData!.friendProfileImage!)
                : null,
            child: (_friendSleepData!.friendProfileImage == null || _friendSleepData!.friendProfileImage!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white, size: 35)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friendNickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '최근 7일 데이터 (${DateFormat('MM.dd').format(DateTime.now().subtract(const Duration(days: 6)))} - ${DateFormat('MM.dd').format(DateTime.now())})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final stats = _friendSleepData!.statistics;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '수면 통계',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('평균 수면 점수', '${stats.averageSleepScore.toStringAsFixed(1)}점'),
          _buildStatRow('최고 수면 점수', '${stats.highestSleepScore.toStringAsFixed(1)}점'),
          _buildStatRow('최저 수면 점수', '${stats.lowestSleepScore.toStringAsFixed(1)}점'),
          _buildStatRow('연속 기록일', '${stats.consecutiveRecordingDays}일'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScoresSection() {
    final privacy = _friendSleepData!.privacyInfo;
    final scores = _friendSleepData!.recentScores;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 수면 기록',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (scores.isEmpty)
            Center(
              child: Text(
                '아직 기록된 수면 데이터가 없습니다.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scores.length,
              itemBuilder: (context, index) {
                final score = scores[index];
                return _buildSleepScoreCard(score, privacy);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSleepScoreCard(FriendSleepScore score, FriendPrivacyInfo privacy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)').format(score.date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '수면 점수',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                Text(
                  '${score.sleepScore.toStringAsFixed(1)}점',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (privacy.canSeeDetailedScores) ...[
              const Divider(color: Colors.white30, height: 20),
              _buildDetailRow('총 수면 시간', _formatDuration(score.totalSleepDurationMinutes)),
              _buildDetailRow('깊은 잠', _formatDuration(score.deepSleepDurationMinutes)),
              _buildDetailRow('렘 수면', _formatDuration(score.remSleepDurationMinutes)),
            ] else ...[
              const Divider(color: Colors.white30, height: 20),
              Text(
                '상세 수면 데이터는 비공개입니다.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
              ),
            ],
            if (privacy.canSeeNotes && score.sleepNotes != null && score.sleepNotes!.isNotEmpty) ...[
              const Divider(color: Colors.white30, height: 20),
              Text(
                '수면 메모',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 4),
              Text(
                score.sleepNotes!,
                style: const TextStyle(color: Colors.white70),
              ),
            ] else if (!privacy.canSeeNotes) ...[
              const Divider(color: Colors.white30, height: 20),
              Text(
                '수면 메모는 비공개입니다.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}