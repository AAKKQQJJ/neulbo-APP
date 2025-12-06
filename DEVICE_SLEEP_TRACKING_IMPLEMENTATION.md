# 디바이스 수면 데이터 추출 모듈 구현 가이드

## 📋 목차

1. [개요](#개요)
2. [시스템 아키텍처](#시스템-아키텍처)
3. [핵심 모듈 구조](#핵심-모듈-구조)
4. [구현 단계](#구현-단계)
5. [데이터 흐름](#데이터-흐름)
6. [API 연동](#api-연동)
7. [문제 해결](#문제-해결)

---

## 개요

### 목적
스마트폰의 **가속도계(Accelerometer)**와 **마이크(Audio)**를 사용하여 수면 중 움직임과 소리를 측정하고, ML 서버를 통해 수면 단계를 분석하는 시스템입니다.

### 주요 기능
- ✅ 실시간 센서 데이터 수집 (가속도계, 오디오)
- ✅ 로컬 저장소에 데이터 저장
- ✅ ML 서버로 데이터 전송 및 분석
- ✅ 수면 단계 분석 결과 시각화
- ✅ LLM 기반 수면 피드백 제공

### 기술 스택
- **Flutter**: 크로스 플랫폼 앱 개발
- **sensors_plus**: 가속도계 센서 데이터 수집
- **record**: 오디오 녹음
- **shared_preferences**: 로컬 데이터 저장
- **dio**: HTTP 통신
- **FastAPI (ML 서버)**: 수면 데이터 분석

---

## 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (Frontend)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Motion Sensor    │  │ Audio Recording  │                │
│  │ Service          │  │ Service          │                │
│  │ (가속도계)        │  │ (마이크)          │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                      │                           │
│           └──────────┬───────────┘                           │
│                      ▼                                       │
│           ┌─────────────────────┐                           │
│           │ Sleep Recording     │                           │
│           │ Service             │                           │
│           │ (데이터 통합)        │                           │
│           └──────────┬──────────┘                           │
│                      │                                       │
│                      ▼                                       │
│           ┌─────────────────────┐                           │
│           │ Sleep Data Storage  │                           │
│           │ Service             │                           │
│           │ (로컬 저장)          │                           │
│           └──────────┬──────────┘                           │
│                      │                                       │
│                      ▼                                       │
│           ┌─────────────────────┐                           │
│           │ API Service         │                           │
│           │ (서버 통신)          │                           │
│           └──────────┬──────────┘                           │
│                      │                                       │
└──────────────────────┼───────────────────────────────────────┘
                       │ HTTPS (JWT)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ML Server (FastAPI - Backend)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  POST /api/ml/sleep/analyze                                  │
│  ├─ 센서 데이터 검증                                          │
│  ├─ XGBoost 모델로 수면 단계 예측                            │
│  ├─ 수면 통계 계산                                            │
│  └─ DB 저장 및 결과 반환                                      │
│                                                               │
│  GET /api/ml/sleep/history                                   │
│  └─ 사용자별 수면 분석 이력 조회                              │
│                                                               │
│  POST /api/ml/llm/feedback                                   │
│  └─ LLM 기반 수면 피드백 생성                                 │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 핵심 모듈 구조

### 1. Motion Sensor Service (`motion_sensor_service.dart`)

**역할**: 가속도계 센서 데이터 수집

```dart
class MotionSensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final List<AccelerometerData> _accelerometerData = [];
  
  // 센서 데이터 수집 시작
  void startRecording() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _accelerometerData.add(AccelerometerData(
        timestamp: DateTime.now(),
        x: event.x,
        y: event.y,
        z: event.z,
      ));
    });
  }
  
  // 센서 데이터 수집 중지
  void stopRecording() {
    _accelerometerSubscription?.cancel();
  }
  
  // 수집된 데이터 반환
  List<AccelerometerData> getAccelerometerData() {
    return List.from(_accelerometerData);
  }
}
```

**주요 기능**:
- ✅ 실시간 가속도계 데이터 수집 (X, Y, Z 축)
- ✅ 타임스탬프와 함께 데이터 저장
- ✅ 메모리 관리 (수집 중지 시 리소스 해제)

**예시 데이터**:
```json
{
  "accelerometer_data": [
    {
      "timestamp": "2025-01-17T22:00:00.000Z",
      "x": -0.123,
      "y": 0.456,
      "z": 9.789
    },
    {
      "timestamp": "2025-01-17T22:00:01.000Z",
      "x": -0.098,
      "y": 0.423,
      "z": 9.812
    },
    {
      "timestamp": "2025-01-17T22:00:02.000Z",
      "x": -0.145,
      "y": 0.389,
      "z": 9.756
    },
    {
      "timestamp": "2025-01-17T22:00:03.000Z",
      "x": -0.112,
      "y": 0.467,
      "z": 9.801
    },
    {
      "timestamp": "2025-01-17T22:00:04.000Z",
      "x": -0.089,
      "y": 0.445,
      "z": 9.823
    }
  ]
}
```

**데이터 해석**:
- **X, Y, Z 축**: 중력 가속도 (단위: m/s²)
- **Z축 ~9.8**: 기기가 평평하게 놓여있음 (수면 중)
- **X, Y축 변화**: 사용자의 움직임 감지
- **큰 변화**: 뒤척임, 작은 변화: 안정적인 수면

---

### 2. Audio Recording Service (`audio_recording_service.dart`)

**역할**: 마이크를 통한 오디오 데이터 수집

```dart
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final List<AudioData> _audioData = [];
  Timer? _samplingTimer;
  
  // 오디오 녹음 시작
  Future<void> startRecording() async {
    await _recorder.start();
    
    // 30초마다 오디오 샘플링
    _samplingTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      final amplitude = await _recorder.getAmplitude();
      _audioData.add(AudioData(
        timestamp: DateTime.now(),
        amplitude: amplitude.current,
        frequencyBands: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
      ));
    });
  }
  
  // 오디오 녹음 중지
  Future<void> stopRecording() async {
    _samplingTimer?.cancel();
    await _recorder.stop();
  }
  
  // 수집된 데이터 반환
  List<AudioData> getAudioData() {
    return List.from(_audioData);
  }
}
```

**주요 기능**:
- ✅ 백그라운드 오디오 녹음
- ✅ 주기적 샘플링 (30초 간격)
- ✅ 진폭(amplitude) 및 주파수 대역 데이터 수집

**예시 데이터**:
```json
{
  "audio_data": [
    {
      "timestamp": "2025-01-17T22:00:00.000Z",
      "amplitude": 0.15,
      "frequency_bands": [0.12, 0.18, 0.25, 0.32, 0.45, 0.58, 0.67, 0.75]
    },
    {
      "timestamp": "2025-01-17T22:00:30.000Z",
      "amplitude": 0.08,
      "frequency_bands": [0.05, 0.08, 0.12, 0.15, 0.20, 0.25, 0.30, 0.35]
    },
    {
      "timestamp": "2025-01-17T22:01:00.000Z",
      "amplitude": 0.45,
      "frequency_bands": [0.35, 0.42, 0.55, 0.68, 0.75, 0.82, 0.88, 0.92]
    },
    {
      "timestamp": "2025-01-17T22:01:30.000Z",
      "amplitude": 0.12,
      "frequency_bands": [0.08, 0.15, 0.22, 0.28, 0.35, 0.42, 0.50, 0.58]
    },
    {
      "timestamp": "2025-01-17T22:02:00.000Z",
      "amplitude": 0.03,
      "frequency_bands": [0.02, 0.03, 0.05, 0.08, 0.10, 0.12, 0.15, 0.18]
    }
  ]
}
```

**데이터 해석**:
- **amplitude**: 소리 크기 (0.0 ~ 1.0)
  - `0.0 ~ 0.1`: 매우 조용함 (깊은 수면)
  - `0.1 ~ 0.3`: 보통 (코골이, 뒤척임)
  - `0.3 ~ 1.0`: 시끄러움 (깨어있음, 대화)
- **frequency_bands**: 8개 주파수 대역 (저주파 → 고주파)
  - 낮은 주파수: 코골이, 깊은 호흡
  - 높은 주파수: 말소리, 환경 소음

---

### 3. Sleep Recording Service (`sleep_recording_service.dart`)

**역할**: 센서 데이터 통합 및 ML 서버로 전송

```dart
class SleepRecordingService {
  final MotionSensorService _motionSensorService = MotionSensorService();
  final AudioRecordingService _audioRecordingService = AudioRecordingService();
  
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;
  
  // 수면 측정 시작
  Future<void> startRecording() async {
    _recordingStartTime = DateTime.now();
    
    // 센서 데이터 수집 시작
    _motionSensorService.startRecording();
    await _audioRecordingService.startRecording();
    
    print('✅ 수면 측정 시작: $_recordingStartTime');
  }
  
  // 수면 측정 종료
  Future<void> stopRecording() async {
    _recordingEndTime = DateTime.now();
    
    // 센서 데이터 수집 중지
    _motionSensorService.stopRecording();
    await _audioRecordingService.stopRecording();
    
    print('✅ 수면 측정 종료: $_recordingEndTime');
  }
  
  // 수집된 데이터 분석 요청
  Future<SleepAnalysisResult> analyzeSleepData() async {
    // 1. 데이터 검증
    final duration = _recordingEndTime!.difference(_recordingStartTime!);
    if (duration.inHours < 1) {
      throw Exception('수면 분석을 위해서는 최소 1시간 이상의 녹음이 필요합니다.');
    }
    
    // 2. 데이터 통합
    final recordingData = SleepRecordingData.create(
      startTime: _recordingStartTime!,
      endTime: _recordingEndTime!,
      accelerometerData: _motionSensorService.getAccelerometerData(),
      audioData: _audioRecordingService.getAudioData(),
    );
    
    // 3. 로컬 저장 (백업)
    await SleepDataStorageService.saveSleepData(recordingData);
    
    // 4. ML 서버로 전송
    final result = await ApiService.analyzeSleepData(recordingData);
    
    return result;
  }
}
```

**주요 기능**:
- ✅ 센서 데이터 통합 관리
- ✅ 최소 녹음 시간 검증 (1시간)
- ✅ 로컬 저장 및 서버 전송

**예시 데이터** (통합된 수면 녹음 데이터):
```json
{
  "session_id": "sleep_1737151200000",
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
  "recording_start": "2025-01-17T22:00:00.000Z",
  "recording_end": "2025-01-18T06:00:00.000Z",
  "duration": 28800.0,
  "accelerometer_data": [
    {
      "timestamp": "2025-01-17T22:00:00.000Z",
      "x": -0.123,
      "y": 0.456,
      "z": 9.789
    },
    {
      "timestamp": "2025-01-17T22:00:01.000Z",
      "x": -0.098,
      "y": 0.423,
      "z": 9.812
    }
    // ... 28,800개의 데이터 포인트 (1초마다)
  ],
  "audio_data": [
    {
      "timestamp": "2025-01-17T22:00:00.000Z",
      "amplitude": 0.15,
      "frequency_bands": [0.12, 0.18, 0.25, 0.32, 0.45, 0.58, 0.67, 0.75]
    },
    {
      "timestamp": "2025-01-17T22:00:30.000Z",
      "amplitude": 0.08,
      "frequency_bands": [0.05, 0.08, 0.12, 0.15, 0.20, 0.25, 0.30, 0.35]
    }
    // ... 960개의 데이터 포인트 (30초마다)
  ],
  "data_quality": "양호 - 센서 데이터 수집 정상",
  "metadata": {
    "device_model": "iPhone 14 Pro",
    "os_version": "iOS 17.2",
    "app_version": "1.0.0",
    "accelerometer_sample_rate": "1 Hz",
    "audio_sample_rate": "0.033 Hz (30초마다)"
  }
}
```

**데이터 통계**:
- **총 녹음 시간**: 8시간 (28,800초)
- **가속도계 데이터**: 28,800개 (1초마다 1개)
- **오디오 데이터**: 960개 (30초마다 1개)
- **예상 파일 크기**: ~2-3 MB (JSON 압축 시)

---

### 4. Sleep Data Storage Service (`sleep_data_storage_service.dart`)

**역할**: 로컬 저장소에 수면 데이터 저장 및 관리

```dart
class SleepDataStorageService {
  static const String _storageKey = 'sleep_data_list';
  
  // 수면 데이터 저장
  static Future<String> saveSleepData(SleepRecordingData data) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 파일 경로 생성
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/sleep_${data.sessionId}.json';
    
    // JSON 파일로 저장
    final file = File(filePath);
    await file.writeAsString(jsonEncode(data.toJson()));
    
    // 메타데이터 저장
    final List<String> savedList = prefs.getStringList(_storageKey) ?? [];
    savedList.insert(0, jsonEncode({
      'sessionId': data.sessionId,
      'filePath': filePath,
      'startTime': data.startTime.toIso8601String(),
      'endTime': data.endTime.toIso8601String(),
      'duration': data.duration,
    }));
    
    await prefs.setStringList(_storageKey, savedList);
    
    return filePath;
  }
  
  // 저장된 수면 데이터 목록 조회
  static Future<List<Map<String, dynamic>>> getSavedDataList() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedList = prefs.getStringList(_storageKey) ?? [];
    
    return savedList.map((item) {
      return jsonDecode(item) as Map<String, dynamic>;
    }).toList();
  }
  
  // 특정 수면 데이터 로드
  static Future<SleepRecordingData> loadSleepData(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    
    return SleepRecordingData.fromJson(jsonData);
  }
}
```

**주요 기능**:
- ✅ JSON 형식으로 로컬 저장
- ✅ 메타데이터 관리 (세션 ID, 파일 경로, 시간 정보)
- ✅ 저장된 데이터 목록 조회

**예시 데이터** (로컬 저장 메타데이터):
```json
{
  "saved_sleep_data_list": [
    {
      "sessionId": "sleep_1737151200000",
      "filePath": "/data/user/0/com.example.neulbo/app_flutter/sleep_1737151200000.json",
      "startTime": "2025-01-17T22:00:00.000Z",
      "endTime": "2025-01-18T06:00:00.000Z",
      "duration": 28800.0,
      "dataQuality": "양호",
      "fileSize": "2.3 MB",
      "isSynced": false,
      "createdAt": "2025-01-18T06:05:30.000Z"
    },
    {
      "sessionId": "sleep_1737064800000",
      "filePath": "/data/user/0/com.example.neulbo/app_flutter/sleep_1737064800000.json",
      "startTime": "2025-01-16T22:00:00.000Z",
      "endTime": "2025-01-17T06:30:00.000Z",
      "duration": 30600.0,
      "dataQuality": "양호",
      "fileSize": "2.5 MB",
      "isSynced": true,
      "syncedAt": "2025-01-17T07:00:00.000Z",
      "analysisId": "550e8400-e29b-41d4-a716-446655440000",
      "createdAt": "2025-01-17T06:35:00.000Z"
    },
    {
      "sessionId": "sleep_1736978400000",
      "filePath": "/data/user/0/com.example.neulbo/app_flutter/sleep_1736978400000.json",
      "startTime": "2025-01-15T22:00:00.000Z",
      "endTime": "2025-01-16T05:45:00.000Z",
      "duration": 27900.0,
      "dataQuality": "보통",
      "fileSize": "2.1 MB",
      "isSynced": true,
      "syncedAt": "2025-01-16T06:00:00.000Z",
      "analysisId": "660e8400-e29b-41d4-a716-446655440001",
      "createdAt": "2025-01-16T05:50:00.000Z"
    }
  ],
  "totalCount": 3,
  "totalStorageUsed": "6.9 MB"
}
```

**파일 구조**:
```
/data/user/0/com.example.neulbo/app_flutter/
├── sleep_1737151200000.json (2.3 MB) - 최신
├── sleep_1737064800000.json (2.5 MB)
└── sleep_1736978400000.json (2.1 MB)
```

**저장 전략**:
- 최대 7일치 데이터 보관
- 서버 동기화 완료 후 7일 경과 시 자동 삭제
- 저장 공간 부족 시 가장 오래된 데이터부터 삭제

---

### 5. API Service (`api_service.dart`)

**역할**: ML 서버와의 HTTP 통신

```dart
class ApiService {
  static final Dio _dio = Dio();
  
  // 수면 데이터 분석 요청
  static Future<SleepAnalysisResult> analyzeSleepData(
    SleepRecordingData sleepRecordingData,
  ) async {
    try {
      // JWT 토큰 가져오기
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('JWT 토큰이 없습니다. 로그인이 필요합니다.');
      }
      
      // JWT에서 user_id 추출
      String? userId = _extractUserIdFromJwt(token);
      
      // ML 서버로 분석 요청
      final mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com';
      
      final response = await mlDio.post(
        '/api/ml/sleep/analyze',
        data: sleepRecordingData.toJson(userId: userId),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      // 응답 데이터를 SleepAnalysisResult 객체로 변환
      final result = SleepAnalysisResult.fromJson(
        response.data as Map<String, dynamic>
      );
      
      print('✅ 수면 데이터 분석 완료');
      print('📊 분석 ID: ${result.analysisId}');
      print('📊 데이터 품질 점수: ${result.dataQualityScore}');
      
      return result;
    } catch (error) {
      print('❌ 수면 데이터 분석 실패: $error');
      rethrow;
    }
  }
  
  // JWT 토큰에서 user_id 추출
  static String? _extractUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final payloadMap = json.decode(decoded) as Map<String, dynamic>;
        
        return payloadMap['user_id']?.toString() ?? 
               payloadMap['userId']?.toString() ?? 
               payloadMap['sub']?.toString();
      }
    } catch (e) {
      print('⚠️ JWT 디코딩 실패: $e');
    }
    return null;
  }
}
```

**주요 기능**:
- ✅ JWT 인증 기반 API 통신
- ✅ 센서 데이터를 JSON으로 직렬화하여 전송
- ✅ ML 서버 응답을 Dart 객체로 역직렬화

**예시 데이터** (ML 서버 분석 결과):
```json
{
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "analysis_timestamp": "2025-01-18T06:15:30.123456",
  "recording_start": "2025-01-17T22:00:00Z",
  "recording_end": "2025-01-18T06:00:00Z",
  "stage_intervals": [
    {
      "start_time": "2025-01-17T22:00:00Z",
      "end_time": "2025-01-17T22:30:00Z",
      "stage": "Wake",
      "confidence": 0.92
    },
    {
      "start_time": "2025-01-17T22:30:00Z",
      "end_time": "2025-01-17T23:00:00Z",
      "stage": "N1",
      "confidence": 0.85
    },
    {
      "start_time": "2025-01-17T23:00:00Z",
      "end_time": "2025-01-18T02:00:00Z",
      "stage": "N2",
      "confidence": 0.88
    },
    {
      "start_time": "2025-01-18T02:00:00Z",
      "end_time": "2025-01-18T04:00:00Z",
      "stage": "N3",
      "confidence": 0.91
    },
    {
      "start_time": "2025-01-18T04:00:00Z",
      "end_time": "2025-01-18T05:30:00Z",
      "stage": "REM",
      "confidence": 0.89
    },
    {
      "start_time": "2025-01-18T05:30:00Z",
      "end_time": "2025-01-18T06:00:00Z",
      "stage": "Wake",
      "confidence": 0.93
    }
  ],
  "summary_statistics": {
    "total_sleep_time": 420,
    "sleep_efficiency": 87.5,
    "sleep_onset_latency": 30,
    "wake_after_sleep_onset": 30,
    "wake_time": 60,
    "n1_time": 30,
    "n2_time": 180,
    "n3_time": 120,
    "rem_time": 90,
    "wake_percentage": 12.5,
    "n1_percentage": 6.25,
    "n2_percentage": 37.5,
    "n3_percentage": 25.0,
    "rem_percentage": 18.75
  },
  "model_version": "1.2.3",
  "data_quality_score": 0.89
}
```

**수면 단계 설명**:
- **Wake**: 깨어있음 (60분, 12.5%)
- **N1**: 얕은 수면 1단계 (30분, 6.25%)
- **N2**: 얕은 수면 2단계 (180분, 37.5%)
- **N3**: 깊은 수면 (120분, 25.0%)
- **REM**: 렘수면 (90분, 18.75%)

**수면 품질 지표**:
- **총 수면시간**: 420분 (7시간)
- **수면 효율**: 87.5% (양호)
- **입면 잠복기**: 30분 (잠드는데 걸린 시간)
- **중간 각성**: 30분

---

## 구현 단계

### Phase 1: 센서 데이터 수집 (완료 ✅)

**목표**: 가속도계와 마이크를 통한 실시간 데이터 수집

**구현 내용**:
1. ✅ `MotionSensorService` 구현
   - 가속도계 센서 스트림 구독
   - X, Y, Z 축 데이터 수집
   - 타임스탬프 기록

2. ✅ `AudioRecordingService` 구현
   - 백그라운드 오디오 녹음
   - 30초 간격 샘플링
   - 진폭 및 주파수 대역 데이터 수집

3. ✅ 권한 관리
   - Android: `RECORD_AUDIO` 권한
   - iOS: `NSMicrophoneUsageDescription`

**검증 방법**:
```dart
// 테스트 코드
final motionService = MotionSensorService();
final audioService = AudioRecordingService();

motionService.startRecording();
await audioService.startRecording();

// 10초 대기
await Future.delayed(Duration(seconds: 10));

motionService.stopRecording();
await audioService.stopRecording();

print('가속도계 데이터: ${motionService.getAccelerometerData().length}개');
print('오디오 데이터: ${audioService.getAudioData().length}개');
```

---

### Phase 2: 데이터 통합 및 저장 (완료 ✅)

**목표**: 센서 데이터를 통합하고 로컬에 저장

**구현 내용**:
1. ✅ `SleepRecordingService` 구현
   - 센서 서비스 통합 관리
   - 녹음 시작/종료 제어
   - 데이터 검증 (최소 1시간)

2. ✅ `SleepDataStorageService` 구현
   - JSON 파일로 로컬 저장
   - 메타데이터 관리
   - 저장된 데이터 목록 조회

3. ✅ 데이터 모델 정의
   - `AccelerometerData`
   - `AudioData`
   - `SleepRecordingData`

**검증 방법**:
```dart
// 데이터 저장 테스트
final recordingData = SleepRecordingData.create(
  startTime: DateTime.now().subtract(Duration(hours: 8)),
  endTime: DateTime.now(),
  accelerometerData: [...],
  audioData: [...],
);

final filePath = await SleepDataStorageService.saveSleepData(recordingData);
print('저장 완료: $filePath');

// 데이터 로드 테스트
final loadedData = await SleepDataStorageService.loadSleepData(filePath);
print('로드 완료: ${loadedData.sessionId}');
```

---

### Phase 3: ML 서버 연동 (완료 ✅)

**목표**: 수집된 데이터를 ML 서버로 전송하고 분석 결과 수신

**구현 내용**:
1. ✅ API 엔드포인트 구현
   - `POST /api/ml/sleep/analyze`: 수면 데이터 분석
   - `GET /api/ml/sleep/history`: 분석 이력 조회
   - `GET /api/ml/sleep/result/{analysis_id}`: 상세 결과 조회

2. ✅ JWT 인증 구현
   - Spring Boot 서버에서 JWT 발급
   - API 요청 시 자동으로 토큰 주입
   - 토큰 갱신 로직

3. ✅ 에러 처리
   - 네트워크 오류 처리
   - 토큰 만료 처리
   - 데이터 검증 실패 처리

**API 요청 예시**:
```dart
// 수면 데이터 분석 요청
final result = await ApiService.analyzeSleepData(recordingData);

// 결과 출력
print('분석 ID: ${result.analysisId}');
print('총 수면시간: ${result.summaryStatistics.totalSleepTime}분');
print('수면 효율: ${result.summaryStatistics.sleepEfficiency}%');
print('깊은 수면: ${result.summaryStatistics.n3Time}분');
print('REM 수면: ${result.summaryStatistics.remTime}분');
```

---

### Phase 4: UI 구현 (완료 ✅)

**목표**: 사용자 친화적인 수면 측정 및 분석 화면 구현

**구현 내용**:
1. ✅ `SleepTrackingScreen` (수면 측정 화면)
   - 측정 시작/종료 버튼
   - 실시간 경과 시간 표시
   - 센서 상태 표시

2. ✅ `HomeScreen` (홈 화면)
   - "오늘 수면 분석하기" 버튼
   - 분석 결과 요약 표시
   - 수면 단계 그래프

3. ✅ `IntegratedSleepDataScreen` (수면 데이터 확인 화면)
   - 디바이스 측정 데이터 조회
   - 웨어러블 기기 데이터 조회
   - 통합 그래프 표시

**UI 플로우**:
```
1. 수면 측정 시작
   ↓
2. 센서 데이터 수집 (최소 1시간)
   ↓
3. 측정 종료
   ↓
4. 로컬 저장
   ↓
5. 홈 화면에서 "오늘 수면 분석하기" 클릭
   ↓
6. ML 서버로 데이터 전송
   ↓
7. 분석 결과 표시 (그래프 + 통계)
   ↓
8. "수면 데이터 확인하기"에서 이력 조회
```

---

### Phase 5: LLM 피드백 연동 (완료 ✅)

**목표**: AI 기반 수면 개선 조언 제공

**구현 내용**:
1. ✅ `SleepChatScreen` (수면 챗봇 화면)
   - 사용자 질문 입력
   - LLM 응답 표시
   - 마크다운 렌더링

2. ✅ LLM API 연동
   - `POST /api/ml/llm/feedback`: 피드백 생성
   - `GET /api/ml/llm/feedback/history/{user_id}`: 피드백 이력

3. ✅ 분석 ID 연동
   - 수면 분석 완료 시 `analysis_id` 저장
   - 챗봇에서 최근 `analysis_id` 사용

**사용 예시**:
```dart
// 수면 분석 후 analysis_id 저장
await SleepAnalysisService.saveLastAnalysisId(
  analysisId: result.analysisId,
  summary: '총 수면시간: ${result.summaryStatistics.totalSleepTime}분',
);

// 챗봇에서 피드백 요청
final analysisId = await SleepAnalysisService.getLastAnalysisId();
final response = await ApiService.sendLlmFeedback(
  analysisId: analysisId,
  userPrompt: '어떻게 하면 더 깊은 잠을 잘 수 있나요?',
);

print('AI 응답: ${response.data['llm_response']}');
```

**예시 LLM 응답**:
```json
{
  "feedback_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_prompt": "어떻게 하면 더 깊은 잠을 잘 수 있나요?",
  "llm_response": "## 수면 분석 결과 기반 맞춤 조언\n\n귀하의 수면 분석 결과를 확인한 결과, 총 7시간의 수면 중 깊은 수면(N3)이 120분(25%)으로 양호한 수준입니다. 하지만 더 개선하기 위해 다음을 추천드립니다:\n\n### 1. 수면 환경 최적화\n- **실내 온도**: 18-20도 유지\n- **조명**: 완전히 차단 (암막 커튼 사용)\n- **소음**: 귀마개 또는 백색소음 활용\n\n### 2. 수면 전 루틴\n- 잠들기 2-3시간 전 카페인 섭취 금지\n- 잠들기 1시간 전 스마트폰 사용 자제 (블루라이트)\n- 가벼운 스트레칭이나 명상 (10-15분)\n\n### 3. 규칙적인 수면 패턴\n- 매일 같은 시간에 잠들고 일어나기\n- 주말에도 수면 시간 일정하게 유지\n\n귀하의 현재 수면 효율(87.5%)은 양호하지만, 입면 잠복기(30분)가 다소 길어 위 방법들을 시도해보시길 권장합니다.",
  "llm_model": "llama3.1:8b",
  "response_time_ms": 1250.5,
  "timestamp": "2025-01-18T06:20:15.123456",
  "analysis_summary": "총 7.0시간 수면 분석 (수면효율: 87.5%, 총 수면시간: 420분)"
}
```

---

## 데이터 흐름

### 1. 수면 측정 플로우

```mermaid
sequenceDiagram
    participant User
    participant UI
    participant SleepRecording
    participant MotionSensor
    participant AudioRecording
    participant Storage

    User->>UI: "측정 시작" 버튼 클릭
    UI->>SleepRecording: startRecording()
    SleepRecording->>MotionSensor: startRecording()
    SleepRecording->>AudioRecording: startRecording()
    
    Note over MotionSensor,AudioRecording: 센서 데이터 수집 중...
    
    User->>UI: "측정 종료" 버튼 클릭
    UI->>SleepRecording: stopRecording()
    SleepRecording->>MotionSensor: stopRecording()
    SleepRecording->>AudioRecording: stopRecording()
    SleepRecording->>Storage: saveSleepData()
    Storage-->>SleepRecording: filePath
    SleepRecording-->>UI: 저장 완료
    UI-->>User: "측정 완료" 메시지
```

### 2. 수면 분석 플로우

```mermaid
sequenceDiagram
    participant User
    participant UI
    participant ApiService
    participant MLServer
    participant Database

    User->>UI: "오늘 수면 분석하기" 클릭
    UI->>ApiService: analyzeSleepData()
    ApiService->>ApiService: JWT 토큰 가져오기
    ApiService->>ApiService: user_id 추출
    ApiService->>MLServer: POST /api/ml/sleep/analyze
    
    MLServer->>MLServer: 데이터 검증
    MLServer->>MLServer: XGBoost 모델 예측
    MLServer->>MLServer: 수면 통계 계산
    MLServer->>Database: 분석 결과 저장
    Database-->>MLServer: 저장 완료
    
    MLServer-->>ApiService: SleepAnalysisResult
    ApiService-->>UI: 분석 결과
    UI-->>User: 그래프 + 통계 표시
```

### 3. 데이터 조회 플로우

```mermaid
sequenceDiagram
    participant User
    participant UI
    participant ApiService
    participant MLServer
    participant Database

    User->>UI: "수면 데이터 확인하기" 클릭
    UI->>ApiService: getSleepAnalysisHistory()
    ApiService->>ApiService: JWT 토큰 가져오기
    ApiService->>MLServer: GET /api/ml/sleep/history
    
    MLServer->>MLServer: JWT에서 user_id 추출
    MLServer->>Database: SELECT * FROM sleep_analysis WHERE user_id = ?
    Database-->>MLServer: 분석 이력 목록
    
    MLServer-->>ApiService: 분석 이력 (JSON)
    ApiService-->>UI: List<SleepAnalysisResult>
    UI-->>User: 이력 목록 + 그래프 표시
```

---

## API 연동

### 1. 수면 데이터 분석 API

**Endpoint**: `POST /api/ml/sleep/analyze`

**Request**:
```json
{
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
  "recording_start": "2025-10-01T22:00:00Z",
  "recording_end": "2025-10-02T06:00:00Z",
  "accelerometer_data": [
    {
      "timestamp": "2025-10-01T22:00:00Z",
      "x": -0.123,
      "y": 0.456,
      "z": 9.789
    }
  ],
  "audio_data": [
    {
      "timestamp": "2025-10-01T22:00:00Z",
      "amplitude": 0.15,
      "frequency_bands": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
    }
  ]
}
```

**Response**:
```json
{
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "analysis_timestamp": "2025-10-19T06:15:30.123456",
  "recording_start": "2025-10-01T22:00:00Z",
  "recording_end": "2025-10-02T06:00:00Z",
  "stage_intervals": [
    {
      "start_time": "2025-10-01T22:00:00Z",
      "end_time": "2025-10-01T22:30:00Z",
      "stage": "Wake",
      "confidence": 0.92
    },
    {
      "start_time": "2025-10-01T22:30:00Z",
      "end_time": "2025-10-01T23:00:00Z",
      "stage": "N1",
      "confidence": 0.85
    }
  ],
  "summary_statistics": {
    "total_sleep_time": 420,
    "sleep_efficiency": 0.875,
    "wake_time": 60,
    "n1_time": 30,
    "n2_time": 180,
    "n3_time": 120,
    "rem_time": 90
  },
  "model_version": "1.2.3",
  "data_quality_score": 0.89
}
```

---

### 2. 수면 분석 이력 조회 API

**Endpoint**: `GET /api/ml/sleep/history`

**Request**:
```bash
GET /api/ml/sleep/history?page=1&page_size=10
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response**:
```json
{
  "analyses": [
    {
      "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
      "recording_start": "2025-10-01T22:00:00Z",
      "recording_end": "2025-10-02T06:00:00Z",
      "analysis_timestamp": "2025-10-02T06:15:30Z",
      "status": "completed",
      "data_quality_score": 0.89,
      "summary_statistics": {
        "total_sleep_time": 420,
        "sleep_efficiency": 0.875
      }
    }
  ],
  "total_count": 25,
  "page": 1,
  "page_size": 10
}
```

---

### 3. LLM 피드백 API

**Endpoint**: `POST /api/ml/llm/feedback`

**Request**:
```json
{
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_prompt": "어떻게 하면 더 깊은 잠을 잘 수 있나요?"
}
```

**Response**:
```json
{
  "feedback_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_prompt": "어떻게 하면 더 깊은 잠을 잘 수 있나요?",
  "llm_response": "귀하의 수면 분석 결과를 바탕으로 다음과 같은 개선 방안을 제안드립니다...",
  "llm_model": "llama3.1:8b",
  "response_time_ms": 1250.5,
  "timestamp": "2025-10-19T06:20:15.123456"
}
```

---

## 문제 해결

### 문제 1: 센서 데이터 수집이 안 됨

**증상**:
- 가속도계 데이터가 비어있음
- 오디오 녹음이 시작되지 않음

**해결 방법**:
1. **권한 확인**
   ```xml
   <!-- Android: android/app/src/main/AndroidManifest.xml -->
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   ```
   
   ```xml
   <!-- iOS: ios/Runner/Info.plist -->
   <key>NSMicrophoneUsageDescription</key>
   <string>수면 중 소리를 측정하기 위해 마이크 권한이 필요합니다.</string>
   ```

2. **런타임 권한 요청**
   ```dart
   import 'package:permission_handler/permission_handler.dart';
   
   Future<void> requestPermissions() async {
     final status = await Permission.microphone.request();
     if (status.isDenied) {
       print('마이크 권한이 거부되었습니다.');
     }
   }
   ```

---

### 문제 2: ML 서버 연동 시 404 에러

**증상**:
- `POST /api/ml/sleep/analyze`: 200 OK
- `GET /api/ml/sleep/history`: 404 Not Found

**원인**:
- JWT 토큰에서 `user_id` 추출 실패
- 백엔드에서 다른 `user_id`로 조회

**해결 방법**:
1. **JWT 페이로드 확인**
   ```dart
   // 프론트엔드에서 JWT 디코딩
   final parts = token.split('.');
   final payload = base64Url.decode(base64Url.normalize(parts[1]));
   final payloadMap = json.decode(utf8.decode(payload));
   print('JWT user_id: ${payloadMap['user_id']}');
   ```

2. **백엔드 로그 확인**
   ```python
   # FastAPI 백엔드
   @router.get("/sleep/history")
   async def get_sleep_history(request: Request):
       user_id = extract_user_id_from_jwt(request)
       print(f"🔍 JWT에서 추출한 user_id: {user_id}")
       
       results = db.query(SleepAnalysis).filter_by(user_id=user_id).all()
       print(f"🔍 조회된 데이터 수: {len(results)}")
       
       return results
   ```

3. **필드명 일치 확인**
   - Spring Boot: `user_id` vs `userId` vs `sub`
   - FastAPI: `user_id` vs `userId` vs `sub`

---

### 문제 3: 메모리 부족 (Out of Memory)

**증상**:
- 장시간 측정 시 앱 크래시
- 센서 데이터가 너무 많음

**해결 방법**:
1. **샘플링 주기 조정**
   ```dart
   // 가속도계: 1초에 1번만 샘플링
   Timer.periodic(Duration(seconds: 1), (_) {
     final event = await accelerometerEvents.first;
     _accelerometerData.add(AccelerometerData(...));
   });
   ```

2. **데이터 압축**
   ```dart
   // 중복 데이터 제거
   final uniqueData = _accelerometerData.toSet().toList();
   ```

3. **주기적으로 로컬 저장**
   ```dart
   // 1시간마다 로컬에 저장하고 메모리 비우기
   Timer.periodic(Duration(hours: 1), (_) async {
     await SleepDataStorageService.saveSleepData(recordingData);
     _accelerometerData.clear();
     _audioData.clear();
   });
   ```

---

### 문제 4: 백그라운드에서 센서 데이터 수집 중단

**증상**:
- 앱이 백그라운드로 전환되면 센서 데이터 수집 중단
- iOS에서 특히 심함

**해결 방법**:
1. **iOS 백그라운드 모드 활성화**
   ```xml
   <!-- ios/Runner/Info.plist -->
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
     <string>processing</string>
   </array>
   ```

2. **Android 포그라운드 서비스**
   ```dart
   import 'package:flutter_foreground_task/flutter_foreground_task.dart';
   
   await FlutterForegroundTask.startService(
     notificationTitle: '수면 측정 중',
     notificationText: '센서 데이터를 수집하고 있습니다.',
   );
   ```

3. **Wake Lock 사용**
   ```dart
   import 'package:wakelock/wakelock.dart';
   
   // 측정 시작 시
   await Wakelock.enable();
   
   // 측정 종료 시
   await Wakelock.disable();
   ```

---

## 참고 자료

### 관련 파일
- `lib/services/motion_sensor_service.dart`: 가속도계 센서 서비스
- `lib/services/audio_recording_service.dart`: 오디오 녹음 서비스
- `lib/services/sleep_recording_service.dart`: 수면 측정 통합 서비스
- `lib/services/sleep_data_storage_service.dart`: 로컬 저장소 서비스
- `lib/services/api_service.dart`: ML 서버 API 통신
- `lib/models/sleep_recording_data.dart`: 데이터 모델 정의
- `lib/view/screens/sleep_tracking_screen.dart`: 수면 측정 UI
- `lib/view/screens/home_screen.dart`: 홈 화면 (분석 결과 표시)
- `lib/view/screens/integrated_sleep_data_screen.dart`: 수면 데이터 확인 화면

### API 명세서
- `documents/api 명세서 v3.md`: 전체 API 명세서
- `BACKEND_API_REQUEST.md`: 백엔드 API 문제 해결 가이드

### 외부 라이브러리
- `sensors_plus`: ^4.0.0 (가속도계)
- `record`: ^5.0.0 (오디오 녹음)
- `dio`: ^5.4.0 (HTTP 통신)
- `shared_preferences`: ^2.2.2 (로컬 저장)
- `flutter_secure_storage`: ^9.0.0 (보안 저장)

---

## 향후 개선 사항

### 1. 데이터 품질 개선
- [ ] 센서 데이터 노이즈 필터링
- [ ] 이상치(outlier) 제거
- [ ] 샘플링 주기 최적화

### 2. 성능 최적화
- [ ] 메모리 사용량 최적화
- [ ] 배터리 소모 최소화
- [ ] 백그라운드 동작 안정화

### 3. 사용자 경험 개선
- [ ] 측정 중 실시간 피드백
- [ ] 측정 품질 실시간 표시
- [ ] 측정 중단/재개 기능

### 4. 분석 정확도 향상
- [ ] ML 모델 업데이트
- [ ] 개인화된 수면 패턴 학습
- [ ] 환경 요인 고려 (온도, 습도 등)

---

## 부록: 전체 데이터 예시

### A. 완전한 수면 측정 세션 예시

**시나리오**: 사용자가 2025년 1월 17일 밤 10시에 수면 측정을 시작하고, 다음날 아침 6시에 종료

#### 1. 수집된 원시 데이터 (8시간)

```json
{
  "session_id": "sleep_1737151200000",
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
  "recording_start": "2025-01-17T22:00:00.000Z",
  "recording_end": "2025-01-18T06:00:00.000Z",
  "duration": 28800.0,
  
  "accelerometer_data": [
    // 22:00 - 잠들기 전 (많은 움직임)
    {"timestamp": "2025-01-17T22:00:00Z", "x": -0.523, "y": 1.456, "z": 8.789},
    {"timestamp": "2025-01-17T22:00:01Z", "x": -0.698, "y": 1.123, "z": 8.512},
    {"timestamp": "2025-01-17T22:00:02Z", "x": -0.845, "y": 0.889, "z": 8.956},
    
    // 22:30 - N1 단계 (움직임 감소)
    {"timestamp": "2025-01-17T22:30:00Z", "x": -0.123, "y": 0.456, "z": 9.789},
    {"timestamp": "2025-01-17T22:30:01Z", "x": -0.098, "y": 0.423, "z": 9.812},
    
    // 23:00 - N2 단계 (안정적)
    {"timestamp": "2025-01-17T23:00:00Z", "x": -0.045, "y": 0.089, "z": 9.823},
    {"timestamp": "2025-01-17T23:00:01Z", "x": -0.032, "y": 0.067, "z": 9.831},
    
    // 02:00 - N3 단계 (거의 움직임 없음)
    {"timestamp": "2025-01-18T02:00:00Z", "x": -0.012, "y": 0.023, "z": 9.845},
    {"timestamp": "2025-01-18T02:00:01Z", "x": -0.008, "y": 0.015, "z": 9.852},
    
    // 04:00 - REM 단계 (약간의 움직임)
    {"timestamp": "2025-01-18T04:00:00Z", "x": -0.156, "y": 0.234, "z": 9.756},
    {"timestamp": "2025-01-18T04:00:01Z", "x": -0.189, "y": 0.267, "z": 9.723},
    
    // 05:30 - 깨어남 (움직임 증가)
    {"timestamp": "2025-01-18T05:30:00Z", "x": -0.456, "y": 0.789, "z": 9.234},
    {"timestamp": "2025-01-18T05:30:01Z", "x": -0.523, "y": 0.856, "z": 9.167}
    // ... 총 28,800개 데이터 포인트
  ],
  
  "audio_data": [
    // 22:00 - 잠들기 전 (환경 소음)
    {"timestamp": "2025-01-17T22:00:00Z", "amplitude": 0.25, "frequency_bands": [0.15, 0.22, 0.35, 0.42, 0.55, 0.68, 0.75, 0.82]},
    
    // 22:30 - N1 단계 (소음 감소)
    {"timestamp": "2025-01-17T22:30:00Z", "amplitude": 0.12, "frequency_bands": [0.08, 0.15, 0.22, 0.28, 0.35, 0.42, 0.50, 0.58]},
    
    // 23:00 - N2 단계 (조용함)
    {"timestamp": "2025-01-17T23:00:00Z", "amplitude": 0.05, "frequency_bands": [0.03, 0.06, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35]},
    
    // 01:00 - 코골이 시작
    {"timestamp": "2025-01-18T01:00:00Z", "amplitude": 0.35, "frequency_bands": [0.28, 0.35, 0.42, 0.48, 0.55, 0.62, 0.68, 0.75]},
    
    // 02:00 - N3 단계 (매우 조용함)
    {"timestamp": "2025-01-18T02:00:00Z", "amplitude": 0.02, "frequency_bands": [0.01, 0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.15]},
    
    // 04:00 - REM 단계 (호흡 변화)
    {"timestamp": "2025-01-18T04:00:00Z", "amplitude": 0.08, "frequency_bands": [0.05, 0.08, 0.12, 0.16, 0.20, 0.24, 0.28, 0.32]},
    
    // 05:30 - 깨어남 (움직임 소리)
    {"timestamp": "2025-01-18T05:30:00Z", "amplitude": 0.18, "frequency_bands": [0.12, 0.18, 0.25, 0.32, 0.40, 0.48, 0.55, 0.62]}
    // ... 총 960개 데이터 포인트 (30초마다)
  ],
  
  "data_quality": "양호 - 센서 데이터 수집 정상",
  "metadata": {
    "device_model": "iPhone 14 Pro",
    "os_version": "iOS 17.2",
    "app_version": "1.0.0",
    "battery_level_start": 85,
    "battery_level_end": 72,
    "accelerometer_sample_rate": "1 Hz",
    "audio_sample_rate": "0.033 Hz"
  }
}
```

#### 2. ML 서버 분석 결과

```json
{
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "analysis_timestamp": "2025-01-18T06:15:30.123456",
  "recording_start": "2025-01-17T22:00:00Z",
  "recording_end": "2025-01-18T06:00:00Z",
  
  "stage_intervals": [
    {"start_time": "2025-01-17T22:00:00Z", "end_time": "2025-01-17T22:30:00Z", "stage": "Wake", "confidence": 0.92},
    {"start_time": "2025-01-17T22:30:00Z", "end_time": "2025-01-17T23:00:00Z", "stage": "N1", "confidence": 0.85},
    {"start_time": "2025-01-17T23:00:00Z", "end_time": "2025-01-18T00:30:00Z", "stage": "N2", "confidence": 0.88},
    {"start_time": "2025-01-18T00:30:00Z", "end_time": "2025-01-18T01:00:00Z", "stage": "N1", "confidence": 0.82},
    {"start_time": "2025-01-18T01:00:00Z", "end_time": "2025-01-18T02:00:00Z", "stage": "N2", "confidence": 0.89},
    {"start_time": "2025-01-18T02:00:00Z", "end_time": "2025-01-18T03:30:00Z", "stage": "N3", "confidence": 0.91},
    {"start_time": "2025-01-18T03:30:00Z", "end_time": "2025-01-18T04:00:00Z", "stage": "N2", "confidence": 0.87},
    {"start_time": "2025-01-18T04:00:00Z", "end_time": "2025-01-18T05:15:00Z", "stage": "REM", "confidence": 0.89},
    {"start_time": "2025-01-18T05:15:00Z", "end_time": "2025-01-18T05:30:00Z", "stage": "N1", "confidence": 0.83},
    {"start_time": "2025-01-18T05:30:00Z", "end_time": "2025-01-18T06:00:00Z", "stage": "Wake", "confidence": 0.93}
  ],
  
  "summary_statistics": {
    "total_sleep_time": 420,
    "sleep_efficiency": 87.5,
    "sleep_onset_latency": 30,
    "wake_after_sleep_onset": 30,
    "wake_time": 60,
    "n1_time": 45,
    "n2_time": 180,
    "n3_time": 90,
    "rem_time": 75,
    "wake_percentage": 12.5,
    "n1_percentage": 9.4,
    "n2_percentage": 37.5,
    "n3_percentage": 18.75,
    "rem_percentage": 15.6
  },
  
  "sleep_quality_assessment": {
    "overall_score": 78,
    "rating": "양호",
    "strengths": [
      "충분한 총 수면시간 (7시간)",
      "높은 수면 효율 (87.5%)",
      "적절한 깊은 수면 비율"
    ],
    "improvements": [
      "입면 잠복기 단축 필요 (현재 30분)",
      "REM 수면 비율 증가 권장 (현재 15.6%, 목표 20-25%)"
    ]
  },
  
  "model_version": "1.2.3",
  "data_quality_score": 0.89,
  "processing_time_ms": 3456
}
```

#### 3. 사용자에게 표시되는 요약

```
📊 수면 분석 결과

🛌 총 수면시간: 7시간 0분
⭐ 수면 효율: 87.5% (양호)
😴 수면 점수: 78점

📈 수면 단계 분포:
├─ 깊은 수면 (N3): 1시간 30분 (18.8%)
├─ 얕은 수면 (N1+N2): 3시간 45분 (46.9%)
├─ REM 수면: 1시간 15분 (15.6%)
└─ 깨어있음: 1시간 0분 (12.5%)

💡 개선 포인트:
• 잠드는데 30분 소요 → 수면 루틴 개선 권장
• REM 수면 비율 낮음 → 규칙적인 수면 시간 유지 필요

🎯 다음 목표:
• 입면 잠복기 20분 이하로 단축
• REM 수면 비율 20% 이상 달성
```

---

### B. 데이터 크기 및 성능 지표

| 항목 | 값 | 비고 |
|------|-----|------|
| **원시 데이터 크기** | 2.3 MB | JSON 형식 |
| **압축 후 크기** | 0.8 MB | gzip 압축 |
| **가속도계 데이터** | 28,800개 | 1초마다 1개 |
| **오디오 데이터** | 960개 | 30초마다 1개 |
| **로컬 저장 시간** | ~500ms | SSD 기준 |
| **서버 전송 시간** | ~3-5초 | 4G LTE 기준 |
| **ML 분석 시간** | ~3-4초 | 서버 처리 시간 |
| **배터리 소모** | ~13% | 8시간 측정 기준 |

---

### C. 실제 사용 시나리오

#### 시나리오 1: 정상적인 수면 (수면 효율 85% 이상)

```
사용자: 김철수 (30세, 남성)
측정 기간: 2025-01-17 22:00 ~ 2025-01-18 06:00 (8시간)

결과:
- 총 수면시간: 7시간 (87.5% 효율)
- 깊은 수면: 90분 (18.8%)
- REM 수면: 75분 (15.6%)
- 수면 점수: 78점 (양호)

AI 조언:
"양호한 수면 패턴입니다. REM 수면 비율을 높이기 위해 
규칙적인 수면 시간을 유지하시고, 카페인 섭취를 
오후 2시 이전으로 제한하시길 권장합니다."
```

#### 시나리오 2: 불면증 패턴 (수면 효율 70% 미만)

```
사용자: 이영희 (28세, 여성)
측정 기간: 2025-01-17 23:00 ~ 2025-01-18 07:00 (8시간)

결과:
- 총 수면시간: 5시간 30분 (68.8% 효율)
- 입면 잠복기: 90분 (매우 김)
- 중간 각성: 12회 (빈번함)
- 깊은 수면: 45분 (13.6%, 부족)
- 수면 점수: 52점 (개선 필요)

AI 조언:
"수면 효율이 낮고 입면 잠복기가 매우 깁니다. 
다음을 권장드립니다:
1. 수면 위생 개선 (침실 온도, 조명, 소음)
2. 잠들기 2시간 전 스마트폰 사용 금지
3. 명상이나 호흡 운동 시도
4. 증상이 지속되면 전문의 상담 권장"
```

#### 시나리오 3: 코골이/수면무호흡 의심

```
사용자: 박민수 (45세, 남성)
측정 기간: 2025-01-17 22:30 ~ 2025-01-18 06:30 (8시간)

결과:
- 총 수면시간: 6시간 45분 (84.4% 효율)
- 오디오 분석: 코골이 패턴 감지 (3시간 30분)
- 중간 각성: 18회 (매우 빈번)
- 깊은 수면: 30분 (7.4%, 매우 부족)
- 수면 점수: 48점 (불량)

AI 조언:
"⚠️ 코골이 패턴과 빈번한 중간 각성이 감지되었습니다. 
수면무호흡증의 가능성이 있으니 수면클리닉 방문을 
강력히 권장드립니다. 수면무호흡은 심혈관 질환의 
위험을 높일 수 있습니다."
```

---

**작성일**: 2025-01-17  
**작성자**: Frontend Developer (Flutter)  
**버전**: 1.0.0

