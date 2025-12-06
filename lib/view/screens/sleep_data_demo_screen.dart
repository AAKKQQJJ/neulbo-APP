import 'package:flutter/material.dart';
import '../../services/sleep_data_service.dart';
import '../../models/sleep_data.dart';

/// iOS HealthKit 수면 데이터 연동 데모 화면
class SleepDataDemoScreen extends StatefulWidget {
  const SleepDataDemoScreen({super.key});

  @override
  State<SleepDataDemoScreen> createState() => _SleepDataDemoScreenState();
}

class _SleepDataDemoScreenState extends State<SleepDataDemoScreen> {
  final SleepDataService _sleepDataService = SleepDataService();
  
  bool _isLoading = false;
  bool _hasHealthKitPermission = false;
  String _statusMessage = '상태 확인 중...';
  List<SleepData> _sleepDataList = [];
  Map<String, dynamic>? _healthKitStatus;

  @override
  void initState() {
    super.initState();
    _checkHealthKitStatus();
  }

  /// HealthKit 상태 확인
  Future<void> _checkHealthKitStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'HealthKit 상태 확인 중...';
    });

    try {
      final Map<String, dynamic> status = await _sleepDataService.checkSleepDataStatus();
      
      setState(() {
        _healthKitStatus = status;
        _hasHealthKitPermission = status['hasPermissions'] ?? false;
        _statusMessage = status['message'] ?? '상태 불명';
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'HealthKit 상태 확인 실패: $error';
        _isLoading = false;
      });
    }
  }

  /// HealthKit 권한 요청
  Future<void> _requestHealthKitPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'HealthKit 권한 요청 중...';
    });

    try {
      final bool success = await _sleepDataService.initializeHealthKit();
      
      if (success) {
        setState(() {
          _hasHealthKitPermission = true;
          _statusMessage = 'HealthKit 권한 허용됨';
        });
        
        // 권한 허용 후 상태 다시 확인
        await _checkHealthKitStatus();
      } else {
        setState(() {
          _statusMessage = 'HealthKit 권한이 거부되었습니다.';
        });
      }
    } catch (error) {
      setState(() {
        _statusMessage = 'HealthKit 권한 요청 실패: $error';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 수면 데이터 가져오기 (최근 7일)
  Future<void> _fetchSleepData() async {
    if (!_hasHealthKitPermission) {
      _showSnackBar('먼저 HealthKit 권한을 허용해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '수면 데이터 가져오는 중...';
    });

    try {
      final DateTime now = DateTime.now();
      final DateTime weekAgo = now.subtract(const Duration(days: 7));
      
      final List<SleepData> sleepData = await _sleepDataService.fetchAndConvertSleepData(
        startDate: weekAgo,
        endDate: now,
      );

      setState(() {
        _sleepDataList = sleepData;
        _statusMessage = '수면 데이터 ${sleepData.length}건 로드 완료';
        _isLoading = false;
      });

      if (sleepData.isEmpty) {
        _showSnackBar('최근 7일간 수면 데이터가 없습니다.');
      }
    } catch (error) {
      setState(() {
        _statusMessage = '수면 데이터 가져오기 실패: $error';
        _isLoading = false;
      });
      _showSnackBar('수면 데이터 가져오기 실패');
    }
  }

  /// 수면 데이터 서버 동기화
  Future<void> _syncWithServer() async {
    if (!_hasHealthKitPermission) {
      _showSnackBar('먼저 HealthKit 권한을 허용해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '서버와 동기화 중...';
    });

    try {
      final bool success = await _sleepDataService.syncWeeklySleepData();
      
      if (success) {
        setState(() {
          _statusMessage = '서버 동기화 완료';
        });
        _showSnackBar('수면 데이터가 서버와 동기화되었습니다.');
      } else {
        setState(() {
          _statusMessage = '서버 동기화 실패';
        });
        _showSnackBar('서버 동기화에 실패했습니다.');
      }
    } catch (error) {
      setState(() {
        _statusMessage = '서버 동기화 실패: $error';
      });
      _showSnackBar('서버 동기화 중 오류가 발생했습니다.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HealthKit 수면 데이터 연동',
          style: TextStyle(
            fontFamily: 'suit',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue[50],
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상태 표시 카드
          _buildStatusCard(),
          const SizedBox(height: 16),
          
          // 제어 버튼들
          _buildControlButtons(),
          const SizedBox(height: 16),
          
          // 수면 데이터 리스트
          Expanded(child: _buildSleepDataList()),
        ],
      ),
    );
  }

  /// 상태 표시 카드
  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HealthKit 연동 상태',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'suit',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _hasHealthKitPermission ? Icons.check_circle : Icons.error,
                  color: _hasHealthKitPermission ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontFamily: 'suit'),
                  ),
                ),
              ],
            ),
            if (_healthKitStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                '데이터 개수: ${_healthKitStatus!['dataCount'] ?? 0}건',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontFamily: 'suit',
                ),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  /// 제어 버튼들
  Widget _buildControlButtons() {
    return Column(
      children: [
        if (!_hasHealthKitPermission)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _requestHealthKitPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'HealthKit 권한 요청',
                style: TextStyle(fontFamily: 'suit'),
              ),
            ),
          ),
        
        if (_hasHealthKitPermission) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _fetchSleepData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    '수면 데이터 가져오기',
                    style: TextStyle(fontFamily: 'suit'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _syncWithServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    '서버 동기화',
                    style: TextStyle(fontFamily: 'suit'),
                  ),
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _checkHealthKitStatus,
            child: const Text(
              '상태 새로고침',
              style: TextStyle(fontFamily: 'suit'),
            ),
          ),
        ),
      ],
    );
  }

  /// 수면 데이터 리스트
  Widget _buildSleepDataList() {
    if (_sleepDataList.isEmpty) {
      return const Center(
        child: Text(
          '수면 데이터가 없습니다.\n"수면 데이터 가져오기" 버튼을 눌러주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontFamily: 'suit',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '수면 데이터 (${_sleepDataList.length}건)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'suit',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _sleepDataList.length,
            itemBuilder: (context, index) {
              final SleepData sleepData = _sleepDataList[index];
              return _buildSleepDataCard(sleepData);
            },
          ),
        ),
      ],
    );
  }

  /// 수면 데이터 카드
  Widget _buildSleepDataCard(SleepData sleepData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${sleepData.sleepDate.month}/${sleepData.sleepDate.day}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'suit',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getQualityColor(sleepData.sleepQualityScore),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sleepData.sleepQualityGrade} (${sleepData.sleepQualityScore.toStringAsFixed(1)})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'suit',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('총 수면시간', sleepData.formattedTotalSleepTime),
                ),
                Expanded(
                  child: _buildInfoItem('취침시간', sleepData.formattedBedTime),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('기상시간', sleepData.formattedWakeTime),
                ),
                Expanded(
                  child: _buildInfoItem('수면효율', '${sleepData.sleepEfficiency.toStringAsFixed(1)}%'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('깊은잠', '${sleepData.deepSleepPercentage.toStringAsFixed(1)}%'),
                ),
                Expanded(
                  child: _buildInfoItem('REM', '${sleepData.remSleepPercentage.toStringAsFixed(1)}%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // 수면 단계별 상세 시간
            Row(
              children: [
                Expanded(
                  child: _buildDetailedInfoItem(
                    '깊은잠 (N3)',
                    _formatDuration(sleepData.deepSleepDuration),
                    Colors.indigo,
                  ),
                ),
                Expanded(
                  child: _buildDetailedInfoItem(
                    '얕은잠 (N1-N2)',
                    _formatDuration(sleepData.lightSleepDuration),
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildDetailedInfoItem(
                    'REM 수면',
                    _formatDuration(sleepData.remSleepDuration),
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildDetailedInfoItem(
                    '각성 시간',
                    _formatDuration(sleepData.awakeTimeDuration),
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    } else {
      return '${minutes}분';
    }
  }

  Widget _buildDetailedInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'suit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'suit',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontFamily: 'suit',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'suit',
          ),
        ),
      ],
    );
  }

  Color _getQualityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
