import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/sleep_data_storage_service.dart';
import '../../services/api_service.dart';
import '../../models/sleep_recording_data.dart';

/// 로컬에 저장된 수면 데이터를 관리하는 화면 (개발용)
class SleepDataManagementScreen extends StatefulWidget {
  const SleepDataManagementScreen({super.key});

  @override
  State<SleepDataManagementScreen> createState() =>
      _SleepDataManagementScreenState();
}

class _SleepDataManagementScreenState extends State<SleepDataManagementScreen> {
  List<Map<String, dynamic>> _dataList = [];
  bool _isLoading = true;
  int _totalStorageSize = 0;

  @override
  void initState() {
    super.initState();
    _loadDataList();
  }

  /// 저장된 데이터 목록 로드
  Future<void> _loadDataList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dataList = await SleepDataStorageService.getSavedDataList();
      final totalSize = await SleepDataStorageService.getTotalStorageSize();

      setState(() {
        _dataList = dataList;
        _totalStorageSize = totalSize;
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 목록 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 데이터 상세 보기
  Future<void> _showDataDetail(Map<String, dynamic> dataInfo) async {
    try {
      final data = await SleepDataStorageService.loadSleepData(
        dataInfo['filePath'] as String,
      );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildDataDetailSheet(data, dataInfo),
      );
    } catch (e) {
      _showErrorSnackBar('데이터 로드 실패: $e');
    }
  }

  /// 데이터 상세 정보 시트
  Widget _buildDataDetailSheet(
    SleepRecordingData data,
    Map<String, dynamic> dataInfo,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 제목
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '수면 데이터 상세',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard(
                    title: '기본 정보',
                    children: [
                      _buildInfoRow('세션 ID', data.sessionId),
                      _buildInfoRow(
                        '시작 시간',
                        DateFormat('yyyy-MM-dd HH:mm:ss').format(data.startTime),
                      ),
                      _buildInfoRow(
                        '종료 시간',
                        DateFormat('yyyy-MM-dd HH:mm:ss').format(data.endTime),
                      ),
                      _buildInfoRow(
                        '지속 시간',
                        '${(data.duration / 60).toStringAsFixed(1)}분',
                      ),
                      _buildInfoRow('데이터 품질', data.dataQuality),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: '센서 데이터',
                    children: [
                      _buildInfoRow(
                        '가속도계',
                        '${data.accelerometerData.length}개 포인트',
                      ),
                      _buildInfoRow(
                        '오디오',
                        '${data.audioData.length}개 포인트',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: '파일 정보',
                    children: [
                      _buildInfoRow(
                        '파일 크기',
                        '${(dataInfo['fileSize'] / 1024).toStringAsFixed(2)} KB',
                      ),
                      _buildInfoRow(
                        '수정 날짜',
                        DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(dataInfo['modifiedDate'] as DateTime),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 액션 버튼들
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _resendToApi(data, dataInfo);
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('API 재전송'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(dataInfo);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 정보 카드 위젯
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// API 재전송
  Future<void> _resendToApi(
    SleepRecordingData data,
    Map<String, dynamic> dataInfo,
  ) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await ApiService.analyzeSleepData(data);

      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      // 성공 다이얼로그
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('✅ 전송 성공'),
          content: Text(
            'API 전송이 완료되었습니다.\n\n'
            '분석 ID: ${result.analysisId}\n'
            '데이터 품질 점수: ${result.dataQualityScore}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      // 실패 다이얼로그
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('❌ 전송 실패'),
          content: Text('API 전송에 실패했습니다.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  /// 삭제 확인
  Future<void> _confirmDelete(Map<String, dynamic> dataInfo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 삭제 확인'),
        content: const Text('이 수면 데이터를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
      await _deleteData(dataInfo);
    }
  }

  /// 데이터 삭제
  Future<void> _deleteData(Map<String, dynamic> dataInfo) async {
    try {
      await SleepDataStorageService.deleteSleepData(
        dataInfo['filePath'] as String,
      );
      _showSuccessSnackBar('수면 데이터가 삭제되었습니다.');
      await _loadDataList(); // 목록 새로고침
    } catch (e) {
      _showErrorSnackBar('삭제 실패: $e');
    }
  }

  /// 전체 삭제 확인
  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 전체 삭제'),
        content: const Text('모든 수면 데이터를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAllData();
    }
  }

  /// 전체 데이터 삭제
  Future<void> _deleteAllData() async {
    try {
      await SleepDataStorageService.deleteAllSleepData();
      _showSuccessSnackBar('모든 수면 데이터가 삭제되었습니다.');
      await _loadDataList(); // 목록 새로고침
    } catch (e) {
      _showErrorSnackBar('전체 삭제 실패: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '수면 데이터 관리',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_dataList.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: _confirmDeleteAll,
                tooltip: '전체 삭제',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _dataList.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      // 요약 정보
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              icon: Icons.folder,
                              label: '데이터 수',
                              value: '${_dataList.length}개',
                            ),
                            _buildSummaryItem(
                              icon: Icons.storage,
                              label: '총 용량',
                              value: '${(_totalStorageSize / 1024).toStringAsFixed(2)} KB',
                            ),
                          ],
                        ),
                      ),
                      // 데이터 목록
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadDataList,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _dataList.length,
                            itemBuilder: (context, index) {
                              final dataInfo = _dataList[index];
                              return _buildDataItem(dataInfo);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// 요약 정보 항목
  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '저장된 수면 데이터가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '수면 측정을 시작하면 데이터가 자동으로 저장됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 데이터 항목 위젯
  Widget _buildDataItem(Map<String, dynamic> dataInfo) {
    final sessionId = dataInfo['sessionId'] as String;
    final modifiedDate = dataInfo['modifiedDate'] as DateTime;
    final fileSize = dataInfo['fileSize'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showDataDetail(dataInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.nights_stay,
                      color: Colors.purple[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionId.length > 25
                              ? '${sessionId.substring(0, 25)}...'
                              : sessionId,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(modifiedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(fileSize / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

