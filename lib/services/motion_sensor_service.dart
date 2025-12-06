import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sleep_recording_data.dart';

class MotionSensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final List<AccelerometerData> _accelerometerDataList = [];
  DateTime? _recordingStartTime;
  bool _isRecording = false;

  /// 가속도계 데이터 수집 시작
  Future<void> startRecording() async {
    if (_isRecording) {
      print('📱 MotionSensorService - 이미 녹음 중입니다.');
      return;
    }

    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _accelerometerDataList.clear();

    print('📱 MotionSensorService - 가속도계 녹음 시작');
    print('📱 수면 시작 시간: ${_recordingStartTime!.toIso8601String()}');

    // 가속도계 데이터 스트림 구독 (30초 간격으로 데이터 저장)
    _accelerometerSubscription = accelerometerEvents.listen(
      (AccelerometerEvent event) {
        if (_isRecording && _recordingStartTime != null) {
          final now = DateTime.now();
          
          // 10초 간격으로 데이터 저장 (데이터 밀도 개선)
          if (_accelerometerDataList.isEmpty ||
              now.difference(_accelerometerDataList.last.timestamp).inSeconds >= 10) {
            
            // Swift 예제처럼 팩토리 메서드 사용
            final data = AccelerometerData.fromSleepStart(
              timestamp: now,
              sleepStartTime: _recordingStartTime!,
              x: event.x,
              y: event.y,
              z: event.z,
            );
            
            _accelerometerDataList.add(data);
            
            // 테스트용 로그 (움직임 크기)
            print('📱 가속도계 데이터 저장: ${_accelerometerDataList.length}개, '
                  '움직임: ${data.magnitude.toStringAsFixed(3)}g, '
                  '상대시간: ${data.relativeTime.toStringAsFixed(1)}초');
          }
        }
      },
      onError: (error) {
        print('❌ MotionSensorService - 가속도계 오류: $error');
      },
    );
  }

  /// 가속도계 데이터 수집 중지
  Future<void> stopRecording() async {
    if (!_isRecording) {
      print('MotionSensorService - 녹음 중이 아닙니다.');
      return;
    }

    _isRecording = false;
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;

    print('MotionSensorService - 가속도계 녹음 중지. 총 ${_accelerometerDataList.length}개 데이터 수집');
  }

  /// 수집된 가속도계 데이터 가져오기
  List<AccelerometerData> getAccelerometerData() {
    return List.unmodifiable(_accelerometerDataList);
  }

  /// 녹음 시작 시간 가져오기
  DateTime? getRecordingStartTime() {
    return _recordingStartTime;
  }

  /// 현재 녹음 중인지 확인
  bool get isRecording => _isRecording;

  /// 서비스 정리
  void dispose() {
    _accelerometerSubscription?.cancel();
    _accelerometerDataList.clear();
    _isRecording = false;
  }
}

