import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:mic_stream/mic_stream.dart';
import '../models/sleep_recording_data.dart';

/// 실시간 오디오 스트림 서비스 (파일 저장 없음)
/// Swift의 AVAudioEngine.installTap과 유사한 방식
class AudioRecordingService {
  Stream<Uint8List>? _micStream;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final List<AudioData> _audioDataList = [];
  Timer? _analysisTimer;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  
  // 실시간 오디오 분석을 위한 버퍼
  double _currentDecibelLevel = -160.0;
  double _currentAmplitude = 0.0;
  bool _firstDataReceived = false;

  /// 마이크 권한 요청
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      print('AudioRecordingService - 마이크 권한 허용됨');
      return true;
    } else {
      print('AudioRecordingService - 마이크 권한 거부됨');
      return false;
    }
  }

  /// 실시간 오디오 스트림 시작 (Swift의 installTap과 유사)
  /// 파일 저장 없이 실시간으로 dB 레벨만 측정
  Future<void> startRecording() async {
    if (_isRecording) {
      print('⚠️ AudioRecordingService - 이미 녹음 중입니다.');
      return;
    }

    print('🎤 AudioRecordingService - 마이크 권한 확인 중...');
    
    // 권한 상태 확인 (디버깅용)
    final permStatus = await Permission.microphone.status;
    print('🎤 현재 권한 상태: $permStatus');
    print('🎤 isGranted: ${permStatus.isGranted}');
    print('🎤 isDenied: ${permStatus.isDenied}');
    print('🎤 isPermanentlyDenied: ${permStatus.isPermanentlyDenied}');

    // 권한이 없으면 요청 (mic_stream이 자체적으로 처리하지만 명시적으로 요청)
    if (!permStatus.isGranted) {
      print('🎤 마이크 권한 요청 중...');
      final result = await Permission.microphone.request();
      print('🎤 권한 요청 결과: $result');
      
      if (!result.isGranted) {
        throw Exception('마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
      }
    }

    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _audioDataList.clear();
    _firstDataReceived = false;

    try {
      print('🔊 AudioRecordingService - 실시간 오디오 스트림 시작');
      print('📊 파일 저장 없이 dB 레벨만 측정 (Swift installTap 방식)');
      print('📱 시작 시간: ${_recordingStartTime!.toIso8601String()}');

      // MicStream 시작 (샘플레이트: 44100Hz)
      print('🎙️ MicStream 초기화 중...');
      _micStream = await MicStream.microphone(
        audioSource: AudioSource.DEFAULT,
        sampleRate: 44100,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
      );
      print('✅ MicStream 초기화 완료');

      // 실시간 오디오 스트림 구독 (Swift의 installTap처럼)
      print('🎧 오디오 스트림 구독 중...');
      _audioStreamSubscription = _micStream!.listen(
        _onAudioData,
        onError: (error) {
          print('❌ AudioRecordingService - 오디오 스트림 오류: $error');
          print('❌ 오류 타입: ${error.runtimeType}');
        },
        onDone: () {
          print('⚠️ 오디오 스트림 종료됨');
        },
      );
      print('✅ 오디오 스트림 구독 완료');

      // 30초마다 분석 데이터 저장
      _analysisTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _saveAudioAnalysis(),
      );

      print('✅ AudioRecordingService - 실시간 오디오 스트림 시작 완료');
    } catch (e, stackTrace) {
      print('❌ AudioRecordingService - 스트림 시작 실패');
      print('❌ 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      print('❌ 스택 트레이스: $stackTrace');
      _isRecording = false;
      rethrow;
    }
  }

  /// 실시간 오디오 데이터 처리 (Swift의 installTap 콜백과 유사)
  /// bufferSize마다 호출됨
  void _onAudioData(Uint8List audioData) {
    if (!_isRecording) return;

    // 첫 번째 데이터 수신 시 로그
    if (!_firstDataReceived) {
      print('🎵 첫 오디오 데이터 수신! 크기: ${audioData.length} bytes');
      _firstDataReceived = true;
    }

    // PCM 데이터를 Int16 배열로 변환
    final samples = <int>[];
    for (int i = 0; i < audioData.length - 1; i += 2) {
      final sample = (audioData[i + 1] << 8) | audioData[i];
      samples.add(sample.toSigned(16));
    }

    // RMS (Root Mean Square) 계산
    double sum = 0.0;
    for (final sample in samples) {
      final normalized = sample / 32768.0; // 16-bit normalize
      sum += normalized * normalized;
    }
    
    final rms = sqrt(sum / samples.length);
    
    // dB 레벨 계산 (Swift의 calculateDecibelLevel과 동일)
    _currentDecibelLevel = 20 * log(max(rms, 1e-8)) / ln10;
    _currentDecibelLevel = max(_currentDecibelLevel, -160.0);
    
    // 진폭 정규화 (0~1)
    _currentAmplitude = (rms * 2).clamp(0.0, 1.0);
  }

  /// 분석 데이터 저장 (30초마다) - Swift SoundData와 동일하게 dB만 저장
  void _saveAudioAnalysis() {
    if (!_isRecording || _recordingStartTime == null) return;

    final now = DateTime.now();

    final data = AudioData.fromSleepStart(
      timestamp: now,
      sleepStartTime: _recordingStartTime!,
      decibelLevel: _currentDecibelLevel,
    );

    _audioDataList.add(data);

    // 10개마다 로그 출력 (Swift 예제처럼)
    if (_audioDataList.length % 10 == 0) {
      print('🔊 오디오 데이터 저장: ${_audioDataList.length}개, '
            '소음: ${_currentDecibelLevel.toStringAsFixed(1)}dB, '
            '상대시간: ${data.relativeTime.toStringAsFixed(1)}초');
    }
  }

  /// 실시간 오디오 스트림 중지 (파일 저장 없음)
  Future<void> stopRecording() async {
    if (!_isRecording) {
      print('⚠️ AudioRecordingService - 녹음 중이 아닙니다.');
      return;
    }

    _isRecording = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;

    try {
      // 스트림 구독 취소
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      _micStream = null;
      
      print('🔊 AudioRecordingService - 실시간 스트림 중지');
      print('📊 총 ${_audioDataList.length}개 오디오 데이터 수집');
      print('💾 파일 저장 없음 - dB 레벨 데이터만 수집됨');
    } catch (e) {
      print('❌ AudioRecordingService - 스트림 중지 실패: $e');
    }
  }

  /// 수집된 오디오 데이터 가져오기 (dB 레벨 + 진폭만 포함)
  List<AudioData> getAudioData() {
    return List.unmodifiable(_audioDataList);
  }

  /// 녹음 시작 시간 가져오기
  DateTime? getRecordingStartTime() {
    return _recordingStartTime;
  }

  /// 현재 녹음 중인지 확인
  bool get isRecording => _isRecording;

  /// 현재 실시간 dB 레벨 가져오기
  double get currentDecibelLevel => _currentDecibelLevel;

  /// 현재 실시간 진폭 가져오기
  double get currentAmplitude => _currentAmplitude;

  /// 서비스 정리 (파일 저장 없으므로 스트림만 정리)
  Future<void> dispose() async {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    _micStream = null;
    
    _audioDataList.clear();
    _isRecording = false;
    _currentDecibelLevel = -160.0;
    _currentAmplitude = 0.0;
    _firstDataReceived = false;
    
    print('🧹 AudioRecordingService - 서비스 정리 완료 (파일 저장 없음)');
  }
}

