import 'package:dio/dio.dart';
import '../models/sleep_recording_data.dart';
import 'motion_sensor_service.dart';
import 'audio_recording_service.dart';
import 'api_service.dart';
import 'sleep_data_storage_service.dart';

class SleepRecordingService {
  final MotionSensorService _motionSensorService = MotionSensorService();
  final AudioRecordingService _audioRecordingService = AudioRecordingService();
  
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;
  bool _isRecording = false;

  /// 수면 녹음 시작
  Future<void> startRecording() async {
    if (_isRecording) {
      print('SleepRecordingService - 이미 녹음 중입니다.');
      return;
    }

    try {
      _recordingStartTime = DateTime.now();
      _isRecording = true;

      // 가속도계 데이터 수집 시작
      await _motionSensorService.startRecording();

      // 오디오 데이터 수집 시작
      await _audioRecordingService.startRecording();

      print('SleepRecordingService - 수면 녹음 시작: ${_recordingStartTime!.toIso8601String()}');
    } catch (e) {
      print('SleepRecordingService - 녹음 시작 실패: $e');
      _isRecording = false;
      rethrow;
    }
  }

  /// 수면 녹음 중지
  Future<void> stopRecording() async {
    if (!_isRecording) {
      print('SleepRecordingService - 녹음 중이 아닙니다.');
      return;
    }

    _recordingEndTime = DateTime.now();
    _isRecording = false;

    try {
      // 가속도계 데이터 수집 중지
      await _motionSensorService.stopRecording();

      // 오디오 데이터 수집 중지
      await _audioRecordingService.stopRecording();

      print('SleepRecordingService - 수면 녹음 중지: ${_recordingEndTime!.toIso8601String()}');
    } catch (e) {
      print('SleepRecordingService - 녹음 중지 실패: $e');
      rethrow;
    }
  }

  /// 수집된 데이터를 ML 서버로 전송하여 분석 요청
  Future<SleepAnalysisResult> analyzeSleepData() async {
    if (_recordingStartTime == null || _recordingEndTime == null) {
      throw Exception('녹음 데이터가 없습니다.');
    }

    // 수집된 데이터 가져오기
    final accelerometerData = _motionSensorService.getAccelerometerData();
    final audioData = _audioRecordingService.getAudioData();

    // 최소 데이터 검증 (최소 1시간 녹음 필요)
    final duration = _recordingEndTime!.difference(_recordingStartTime!);
    if (duration.inHours < 1) {
      throw Exception('수면 분석을 위해서는 최소 1시간 이상의 녹음이 필요합니다.');
    }

    if (accelerometerData.isEmpty || audioData.isEmpty) {
      throw Exception('수집된 센서 데이터가 부족합니다.');
    }

    // Swift 예제처럼 팩토리 메서드로 SleepRecordingData 생성
    final recordingData = SleepRecordingData.create(
      startTime: _recordingStartTime!,
      endTime: _recordingEndTime!,
      accelerometerData: accelerometerData,
      audioData: audioData,
    );

    // Swift 예제처럼 데이터 요약 정보 출력
    print(recordingData.summary);

    // 🆕 로컬에 데이터 저장 (개발용 - API 전송 실패 시 백업)
    String? savedFilePath;
    try {
      savedFilePath = await SleepDataStorageService.saveSleepData(recordingData);
      print('💾 로컬 저장 완료: $savedFilePath');
    } catch (storageError) {
      print('⚠️ 로컬 저장 실패 (계속 진행): $storageError');
    }

    try {
      // API 서비스를 통해 ML 서버로 분석 요청
      final result = await ApiService.analyzeSleepData(recordingData);
      
      print('✅ SleepRecordingService - 수면 분석 완료');
      print('📋 분석 ID: ${result.analysisId}');
      return result;
    } catch (e) {
      print('SleepRecordingService - 수면 분석 실패: $e');
      
      // API 전송 실패 시 로컬 저장 경로 안내
      if (savedFilePath != null) {
        print('💾 데이터는 로컬에 저장되었습니다: $savedFilePath');
        print('💡 내 정보 > 수면 데이터 관리에서 재전송 가능');
      }
      
      rethrow;
    }
  }

  /// 녹음 상태 정보 가져오기
  Map<String, dynamic> getRecordingStatus() {
    return {
      'isRecording': _isRecording,
      'recordingStartTime': _recordingStartTime?.toIso8601String(),
      'recordingEndTime': _recordingEndTime?.toIso8601String(),
      'accelerometerDataCount': _motionSensorService.getAccelerometerData().length,
      'audioDataCount': _audioRecordingService.getAudioData().length,
      'duration': _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMinutes
          : 0,
    };
  }

  /// 현재 녹음 중인지 확인
  bool get isRecording => _isRecording;

  /// 녹음 시작 시간 가져오기
  DateTime? get recordingStartTime => _recordingStartTime;

  /// 녹음 종료 시간 가져오기
  DateTime? get recordingEndTime => _recordingEndTime;

  /// 서비스 정리
  Future<void> dispose() async {
    _motionSensorService.dispose();
    await _audioRecordingService.dispose();
    _isRecording = false;
  }
}

