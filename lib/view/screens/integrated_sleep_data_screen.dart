import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/sleep_data.dart';
import '../../models/sleep_recording_data.dart';
import '../../services/api_service.dart';
import '../../services/health_service.dart';
import '../../services/sleep_data_service.dart';
import '../../services/sleep_data_storage_service.dart';
import 'home_screen.dart'; // SleepStageGraphPainter 사용을 위해 import

class IntegratedSleepDataScreen extends StatefulWidget {
  const IntegratedSleepDataScreen({super.key});

  @override
  State<IntegratedSleepDataScreen> createState() => _IntegratedSleepDataScreenState();
}

class _IntegratedSleepDataScreenState extends State<IntegratedSleepDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<SleepData> _healthKitData = [];
  List<SleepData> _deviceData = [];
  Map<String, List<HealthDataPoint>> _healthKitRawDataMap = {}; // SleepData ID를 키로 하는 원시 데이터 맵
  Map<String, SleepAnalysisResult> _deviceAnalysisResultMap = {}; // 디바이스 데이터의 ML 분석 결과 맵
  bool _isLoading = true;
  String _errorMessage = '';
  
  final HealthService _healthService = HealthService();
  
  // 선택된 날짜 (기본값: 어제)
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2개 탭으로 변경
    _loadSleepData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSleepData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 선택된 날짜의 시작과 끝 시간 계산
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endDate = startDate.add(const Duration(days: 1));

      // HealthKit 원시 데이터 로드 (그래프 그리기용)
      final rawHealthData = await _healthService.getSleepData(
        startDate: startDate,
        endDate: endDate,
      );

      // HealthKit 데이터 로드 (변환된 SleepData)
      final healthKitData = await SleepDataService().fetchAndConvertSleepData(
        startDate: startDate,
        endDate: endDate,
      );

      // 각 SleepData에 해당하는 원시 데이터 매핑
      final Map<String, List<HealthDataPoint>> rawDataMap = {};
      for (final sleepData in healthKitData) {
        // 해당 수면 데이터의 시간 범위에 맞는 원시 데이터 필터링
        final relevantRawData = rawHealthData.where((point) {
          return point.dateFrom.isAfter(sleepData.bedTime.subtract(const Duration(hours: 1))) &&
              point.dateTo.isBefore(sleepData.wakeTime.add(const Duration(hours: 1)));
        }).toList();
        rawDataMap[sleepData.id] = relevantRawData;
      }

      // 디바이스 측정 데이터 로드 (서버 + 로컬)
      final deviceDataList = await _loadDeviceData(startDate, endDate);

      if (mounted) {
        setState(() {
          _healthKitData = healthKitData;
          _deviceData = deviceDataList;
          _healthKitRawDataMap = rawDataMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '데이터 로드 실패: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 디바이스 측정 데이터 로드 (서버 + 로컬)
  Future<List<SleepData>> _loadDeviceData(DateTime startDate, DateTime endDate) async {
    try {
      print('📱 디바이스 수면 데이터 로드 시작...');
      
      final List<SleepData> deviceDataList = [];
      final Map<String, SleepAnalysisResult> analysisResultMap = {};

      // 1. 서버에서 수면 분석 이력 조회 (최근 30일)
      // 주의: 현재 /api/ml/sleep/history는 스마트폰 센서 데이터만 조회
      // 웨어러블 데이터 조회 API(/api/ml/wearable/history)는 아직 구현되지 않음
      try {
        print('🌐 서버에서 수면 분석 이력 조회 중...');
        print('⚠️ 주의: 현재는 스마트폰 센서 데이터만 조회됩니다');
        print('⚠️ 웨어러블 데이터 조회 API는 백엔드 개발 중입니다');
        
        final response = await ApiService.getSleepAnalysisHistory(
          page: 1,
          pageSize: 30,
        );

        print('📦 서버 응답 데이터: ${response.data}');

        // API 명세서에 따르면 'analyses' 필드에 데이터가 있음
        if (response.data != null && response.data['analyses'] != null) {
          final List<dynamic> analyses = response.data['analyses'] as List<dynamic>;
          print('✅ 서버에서 ${analyses.length}개의 수면 분석 데이터 조회됨');

          for (final analysis in analyses) {
            try {
              final analysisId = analysis['analysis_id'] as String;
              final recordingStart = DateTime.parse(analysis['recording_start'] as String);
              final recordingEnd = DateTime.parse(analysis['recording_end'] as String);

              // 선택된 날짜 범위에 해당하는 데이터만 필터링
              if (recordingStart.isAfter(startDate) && recordingStart.isBefore(endDate)) {
                print('📊 분석 ID: $analysisId (${recordingStart.toLocal()})');

                // 상세 분석 결과 조회
                final analysisResult = await ApiService.getSleepAnalysisResult(analysisId);
                
                // SleepData 객체로 변환
                final sleepData = _convertAnalysisResultToSleepData(analysisResult);
                deviceDataList.add(sleepData);
                analysisResultMap[sleepData.id] = analysisResult;

                print('✅ 분석 데이터 변환 완료: ${sleepData.id}');
              }
            } catch (itemError) {
              print('⚠️ 개별 항목 처리 실패: $itemError');
              continue;
            }
          }
        } else {
          print('ℹ️ 서버 응답에 analyses 필드가 없거나 비어있습니다');
        }
      } catch (serverError) {
        // 404 에러는 데이터가 없는 정상 상황
        if (serverError.toString().contains('404')) {
          print('');
          print('ℹ️ ========================================');
          print('ℹ️ 서버에 스마트폰 센서 기반 수면 분석 데이터가 없습니다');
          print('ℹ️');
          print('ℹ️ 💡 웨어러블 데이터(Apple Watch) 조회 API는');
          print('ℹ️    백엔드 개발자에게 추가 요청 중입니다');
          print('ℹ️');
          print('ℹ️ 📄 자세한 내용: BACKEND_API_REQUEST.md 참조');
          print('ℹ️ ========================================');
          print('');
        } else {
          print('⚠️ 서버 조회 실패 (로컬 데이터로 대체): $serverError');
        }
      }

      // 2. 로컬 저장소에서 데이터 조회 (백업)
      try {
        print('💾 로컬 저장소에서 데이터 조회 중...');
        
        // 로컬 파일에서 직접 SleepRecordingData 로드하여 ML 분석 결과도 함께 가져오기
        final directory = await getApplicationDocumentsDirectory();
        final sleepDir = Directory('${directory.path}/sleep_data');

        if (await sleepDir.exists()) {
          final files = sleepDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.json'));

          for (final file in files) {
            try {
              final content = await file.readAsString();
              final jsonData = json.decode(content);
              final sleepRecordingData = SleepRecordingData.fromJson(jsonData);

              // 수면 시작 시간이 해당 날짜에 포함되는지 확인
              final sleepDate = DateTime(
                sleepRecordingData.startTime.year,
                sleepRecordingData.startTime.month,
                sleepRecordingData.startTime.day,
              );
              
              final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

              if (sleepDate == targetDate) {
                // SleepRecordingData를 SleepData로 변환
                final localData = await SleepDataStorageService().getSleepDataByDate(_selectedDate);
                
                if (localData != null) {
                  // 서버 데이터와 중복되지 않는 경우에만 추가
                  final isDuplicate = deviceDataList.any((data) => 
                    data.bedTime.difference(localData.bedTime).inMinutes.abs() < 10
                  );
                  
                  if (!isDuplicate) {
                    deviceDataList.add(localData);
                    
                    // ML 분석 결과가 있으면 맵에 추가
                    if (sleepRecordingData.analysisResult != null) {
                      analysisResultMap[localData.id] = sleepRecordingData.analysisResult!;
                      print('✅ 로컬 데이터 추가 (ML 분석 결과 포함): ${localData.id}');
                    } else {
                      print('✅ 로컬 데이터 추가 (ML 분석 결과 없음): ${localData.id}');
                    }
                  } else {
                    print('ℹ️ 로컬 데이터는 서버 데이터와 중복되어 제외됨');
                  }
                }
                break; // 해당 날짜 데이터를 찾았으므로 중단
              }
            } catch (e) {
              print('⚠️ 파일 파싱 실패: ${file.path} - $e');
              continue;
            }
          }
        }
      } catch (localError) {
        print('⚠️ 로컬 조회 실패: $localError');
      }

      // 3. 최신순으로 정렬
      deviceDataList.sort((a, b) => b.bedTime.compareTo(a.bedTime));

      // 4. 분석 결과 맵 저장
      _deviceAnalysisResultMap = analysisResultMap;

      print('📊 총 ${deviceDataList.length}개의 디바이스 수면 데이터 로드 완료');
      return deviceDataList;
    } catch (error) {
      print('❌ 디바이스 데이터 로드 실패: $error');
      return [];
    }
  }

  /// SleepAnalysisResult를 SleepData로 변환
  SleepData _convertAnalysisResultToSleepData(SleepAnalysisResult result) {
    final stats = result.summaryStatistics;
    
    // 수면 시작/종료 시간 계산 (stage_intervals에서 추출)
    DateTime? startTime;
    DateTime? endTime;
    
    if (result.stageIntervals.isNotEmpty) {
      startTime = DateTime.parse(result.stageIntervals.first.startTime);
      endTime = DateTime.parse(result.stageIntervals.last.endTime);
    }

    return SleepData(
      id: result.analysisId,
      sleepDate: startTime != null 
          ? DateTime(startTime.year, startTime.month, startTime.day)
          : DateTime.now(),
      bedTime: startTime ?? DateTime.now(),
      sleepTime: startTime ?? DateTime.now(),
      wakeTime: endTime ?? DateTime.now(),
      totalSleepDuration: Duration(minutes: stats.totalSleepTime),
      deepSleepDuration: Duration(minutes: stats.n3Time),
      lightSleepDuration: Duration(minutes: stats.n1Time + stats.n2Time),
      remSleepDuration: Duration(minutes: stats.remTime),
      awakeTimeDuration: Duration(minutes: stats.wakeTime),
      sleepQualityScore: stats.sleepEfficiency,
      sourceId: 'device_ml_server',
      recordedAt: DateTime.parse(result.analysisTimestamp),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6B46C1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadSleepData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF16213E), // 기존 홈화면과 동일한 배경색
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '수면 데이터 확인',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'suit',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _generateDummyData,
            tooltip: '11월 12일 더미 데이터 생성',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSleepData,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
            tooltip: '날짜 선택',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'HealthKit'),
            Tab(text: '디바이스'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 날짜 선택 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.month}월 ${_selectedDate.day}일 수면 데이터',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'suit',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 탭 뷰
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadSleepData,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildHealthKitTab(),
                          _buildDeviceTab(),
                        ],
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHealthKitTab() {
    if (_healthKitData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.health_and_safety,
        title: 'HealthKit 데이터 없음',
        subtitle: '해당 날짜에 HealthKit 수면 데이터가 없습니다.\n건강 앱에서 수면 데이터를 확인해주세요.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _healthKitData.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showSleepDetailModal(_healthKitData[index], 'HealthKit'),
          child: _buildSleepDataCard(
            _healthKitData[index],
            '📱 HealthKit',
            const Color(0xFF6B5B95), // 기존 홈화면과 동일한 색상
          ),
        );
      },
    );
  }

  Widget _buildDeviceTab() {
    if (_deviceData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.smartphone,
        title: '디바이스 데이터 없음',
        subtitle: '해당 날짜에 디바이스로 측정한 수면 데이터가 없습니다.\n수면 측정을 진행해주세요.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deviceData.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showSleepDetailModal(_deviceData[index], '디바이스'),
          child: _buildSleepDataCard(
            _deviceData[index],
            '📲 디바이스 측정',
            const Color(0xFF6B5B95), // 기존 홈화면과 동일한 색상
          ),
        );
      },
    );
  }

  // 수면 데이터 상세 모달 표시
  void _showSleepDetailModal(SleepData sleepData, String source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSleepDetailModal(sleepData, source),
    );
  }

  // 상세 모달 위젯
  Widget _buildSleepDetailModal(SleepData sleepData, String source) {
    final duration = sleepData.wakeTime.difference(sleepData.bedTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 핸들바
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$source 수면 데이터',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'suit',
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 수면 시간 요약
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B5B95).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Icon(
                                Icons.bedtime,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${hours}시간 ${minutes}분',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'suit',
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '취침 ${_formatTime(sleepData.bedTime)} | 기상 ${_formatTime(sleepData.wakeTime)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'suit',
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 수면 그래프
                  Builder(
                    builder: (context) {
                      // 🔍 디버깅: 그래프 데이터 확인
                      final rawData = _healthKitRawDataMap[sleepData.id] ?? [];
                      final mlResult = _deviceAnalysisResultMap[sleepData.id];
                      
                      print('');
                      print('🎨 IntegratedSleepDataScreen - 그래프 렌더링');
                      print('   └─ sleepData.id: ${sleepData.id}');
                      print('   └─ sleepData.sourceId: ${sleepData.sourceId}');
                      print('   └─ rawDataPoints: ${rawData.length}개');
                      print('   └─ mlAnalysisResult: ${mlResult != null ? "✅ 있음 (${mlResult.stageIntervals.length}개 intervals)" : "❌ 없음"}');
                      print('   └─ _deviceAnalysisResultMap keys: ${_deviceAnalysisResultMap.keys.toList()}');
                      
                      if (mlResult != null) {
                        print('   └─ ML 분석 ID: ${mlResult.analysisId}');
                        print('   └─ Stage Intervals 샘플:');
                        for (int i = 0; i < (mlResult.stageIntervals.length > 3 ? 3 : mlResult.stageIntervals.length); i++) {
                          final interval = mlResult.stageIntervals[i];
                          print('      [$i] ${interval.stage}: ${interval.startTime} ~ ${interval.endTime}');
                        }
                      }
                      print('');
                      
                      return Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          child: CustomPaint(
                            painter: SleepStageGraphPainter(
                              sleepData: sleepData,
                              rawDataPoints: rawData, // HealthKit 원시 데이터
                              mlAnalysisResult: mlResult, // 디바이스 ML 분석 결과
                            ),
                            child: Container(),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 수면 단계별 상세 정보
                  _buildSleepStageDetails(sleepData),
                  
                  const SizedBox(height: 20),
                  
                  // 수면 품질 정보
                  _buildSleepQualityInfo(sleepData),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 수면 단계별 상세 정보
  Widget _buildSleepStageDetails(SleepData sleepData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '수면 단계별 시간',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'suit',
          ),
        ),
        const SizedBox(height: 12),
        
        // 깊은 잠
        _buildStageRow(
          '깊은 잠',
          sleepData.deepSleepDuration,
          const Color(0xFF3D5AFE),
          Icons.nights_stay,
        ),
        
        // 얕은 잠
        _buildStageRow(
          '얕은 잠',
          sleepData.lightSleepDuration,
          const Color(0xFF2196F3),
          Icons.bedtime,
        ),
        
        // REM 수면
        _buildStageRow(
          'REM 수면',
          sleepData.remSleepDuration,
          const Color(0xFF64B5F6),
          Icons.psychology,
        ),
        
        // 깨어있는 시간
        _buildStageRow(
          '깨어있는 시간',
          sleepData.awakeTimeDuration,
          const Color(0xFF90CAF9),
          Icons.visibility,
        ),
      ],
    );
  }

  Widget _buildStageRow(String title, Duration duration, Color color, IconData icon) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'suit',
                  ),
                ),
                Text(
                  hours > 0 ? '${hours}시간 ${minutes}분' : '${minutes}분',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontFamily: 'suit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 수면 품질 정보
  Widget _buildSleepQualityInfo(SleepData sleepData) {
    final qualityScore = sleepData.sleepQualityScore.toInt();
    final efficiency = sleepData.sleepEfficiency;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '수면 품질',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'suit',
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // 수면 품질 점수
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '수면 품질 점수',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'suit',
                    ),
                  ),
                  Text(
                    '$qualityScore점',
                    style: TextStyle(
                      color: _getSleepScoreColor(qualityScore),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'suit',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 수면 효율
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '수면 효율',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'suit',
                    ),
                  ),
                  Text(
                    '${efficiency.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'suit',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 품질 설명
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSleepScoreColor(qualityScore).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getSleepScoreDescription(qualityScore),
                  style: TextStyle(
                    color: _getSleepScoreColor(qualityScore),
                    fontSize: 14,
                    fontFamily: 'suit',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getSleepScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getSleepScoreDescription(int score) {
    if (score >= 80) return '훌륭한 수면 품질입니다! 😴';
    if (score >= 60) return '양호한 수면 품질입니다. 🙂';
    return '수면 품질 개선이 필요합니다. 😔';
  }

  Widget _buildSleepDataCard(SleepData sleepData, String source, Color accentColor) {
    final duration = sleepData.wakeTime.difference(sleepData.bedTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (소스 표시)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                source,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'suit',
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.6),
                size: 28,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 메인 수면 정보 (홈화면과 동일한 레이아웃)
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.bedtime,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hours}시간 ${minutes}분',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'suit',
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '취침 ${_formatTime(sleepData.bedTime)} | 기상 ${_formatTime(sleepData.wakeTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'suit',
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 수면 품질 점수
          Row(
            children: [
              const Icon(Icons.star, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                '수면 품질: ${sleepData.sleepQualityScore.toInt()}점',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'suit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'suit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontFamily: 'suit',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadSleepData,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period ${displayHour}:${minute.toString().padLeft(2, '0')}';
  }

  /// 11월 12일 디바이스 더미 데이터 생성
  Future<void> _generateDummyData() async {
    try {
      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('11월 12일 더미 데이터 생성 중...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // 더미 데이터 생성
      final filePath = await SleepDataStorageService.generateNovember12DummyData();
      
      // 11월 12일로 날짜 변경 후 데이터 새로고침
      setState(() {
        _selectedDate = DateTime(2024, 11, 12);
      });
      
      await _loadSleepData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('11월 12일 더미 데이터 생성 완료!\n파일: ${filePath.split('/').last}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('더미 데이터 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
