import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../models/sleep_recording_data.dart';
import '../models/sleep_data.dart';

/// 수면 데이터를 로컬 파일로 저장하고 관리하는 서비스 (개발용)
class SleepDataStorageService {
  /// 수면 데이터를 JSON 파일로 저장
  /// 
  /// [data] 저장할 수면 녹음 데이터
  /// 
  /// Returns: 저장된 파일 경로
  static Future<String> saveSleepData(SleepRecordingData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sleepDir = Directory('${directory.path}/sleep_data');
      
      // 디렉토리가 없으면 생성
      if (!await sleepDir.exists()) {
        await sleepDir.create(recursive: true);
      }

      // 파일명: sessionId.json
      final fileName = '${data.sessionId}.json';
      final file = File('${sleepDir.path}/$fileName');

      // JSON 저장 (toFullJson 사용 - 모든 데이터 포함)
      final jsonData = data.toFullJson();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonData),
      );

      print('💾 수면 데이터 저장 완료: ${file.path}');
      print('💾 파일 크기: ${(await file.length() / 1024).toStringAsFixed(2)} KB');

      return file.path;
    } catch (error) {
      print('❌ 수면 데이터 저장 실패: $error');
      rethrow;
    }
  }

  /// 저장된 모든 수면 데이터 파일 목록 조회
  /// 
  /// Returns: 파일 정보 리스트 [{sessionId, filePath, fileSize, modifiedDate}]
  static Future<List<Map<String, dynamic>>> getSavedDataList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sleepDir = Directory('${directory.path}/sleep_data');

      if (!await sleepDir.exists()) {
        return [];
      }

      final files = sleepDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();

      // 최신순으로 정렬
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      final List<Map<String, dynamic>> dataList = [];
      
      for (final file in files) {
        final stat = file.statSync();
        final sessionId = file.path.split('/').last.replaceAll('.json', '');
        
        dataList.add({
          'sessionId': sessionId,
          'filePath': file.path,
          'fileSize': stat.size,
          'modifiedDate': stat.modified,
        });
      }

      print('📁 저장된 수면 데이터: ${dataList.length}개');
      return dataList;
    } catch (error) {
      print('❌ 수면 데이터 목록 조회 실패: $error');
      return [];
    }
  }

  /// 특정 수면 데이터 파일 읽기
  /// 
  /// [filePath] 파일 경로
  /// 
  /// Returns: SleepRecordingData 객체
  static Future<SleepRecordingData> loadSleepData(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      print('📂 수면 데이터 로드 완료: $filePath');
      return SleepRecordingData.fromJson(jsonData);
    } catch (error) {
      print('❌ 수면 데이터 로드 실패: $error');
      rethrow;
    }
  }

  /// 특정 수면 데이터 파일 삭제
  /// 
  /// [filePath] 파일 경로
  static Future<void> deleteSleepData(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ 수면 데이터 삭제 완료: $filePath');
      }
    } catch (error) {
      print('❌ 수면 데이터 삭제 실패: $error');
      rethrow;
    }
  }

  /// 모든 저장된 수면 데이터 삭제
  static Future<void> deleteAllSleepData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sleepDir = Directory('${directory.path}/sleep_data');

      if (await sleepDir.exists()) {
        await sleepDir.delete(recursive: true);
        print('🗑️ 모든 수면 데이터 삭제 완료');
      }
    } catch (error) {
      print('❌ 수면 데이터 전체 삭제 실패: $error');
      rethrow;
    }
  }

  /// 저장된 데이터의 총 용량 계산
  /// 
  /// Returns: 총 용량 (바이트)
  static Future<int> getTotalStorageSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sleepDir = Directory('${directory.path}/sleep_data');

      if (!await sleepDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      final files = sleepDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'));

      for (final file in files) {
        totalSize += file.statSync().size;
      }

      return totalSize;
    } catch (error) {
      print('❌ 저장 용량 계산 실패: $error');
      return 0;
    }
  }

  /// 특정 날짜의 수면 데이터 조회 (SleepData 형태로 변환)
  /// 
  /// [date] 조회할 날짜
  /// 
  /// Returns: 해당 날짜의 수면 데이터 또는 null
  Future<SleepData?> getSleepDataByDate(DateTime date) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sleepDir = Directory('${directory.path}/sleep_data');

      if (!await sleepDir.exists()) {
        return null;
      }

      // 해당 날짜의 파일들 찾기
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
          
          final targetDate = DateTime(date.year, date.month, date.day);

          if (sleepDate == targetDate) {
            // SleepRecordingData를 SleepData로 변환
            return _convertToSleepData(sleepRecordingData);
          }
        } catch (e) {
          print('⚠️ 파일 파싱 실패: ${file.path} - $e');
          continue;
        }
      }

      return null;
    } catch (error) {
      print('❌ 날짜별 수면 데이터 조회 실패: $error');
      return null;
    }
  }

  /// SleepRecordingData를 SleepData로 변환
  SleepData _convertToSleepData(SleepRecordingData recordingData) {
    final sleepDate = DateTime(
      recordingData.startTime.year,
      recordingData.startTime.month,
      recordingData.startTime.day,
    );

    // ML 분석 결과가 있으면 우선 사용
    if (recordingData.analysisResult != null) {
      final analysis = recordingData.analysisResult!;
      final stats = analysis.summaryStatistics;
      
      print('✅ ML 분석 결과 있음 - 상세 데이터 사용');
      
      return SleepData(
        id: recordingData.sessionId,
        sleepDate: sleepDate,
        bedTime: recordingData.startTime,
        sleepTime: recordingData.startTime,
        wakeTime: recordingData.endTime,
        totalSleepDuration: Duration(minutes: stats.totalSleepTime),
        deepSleepDuration: Duration(minutes: stats.n3Time),
        lightSleepDuration: Duration(minutes: stats.n1Time + stats.n2Time),
        remSleepDuration: Duration(minutes: stats.remTime),
        awakeTimeDuration: Duration(minutes: stats.wakeTime),
        sleepQualityScore: stats.sleepEfficiency,
        sourceId: 'device_ml_analyzed',
        recordedAt: DateTime.now(),
      );
    }
    
    // ML 분석 결과가 없으면 간단한 추정 사용
    print('⚠️ ML 분석 결과 없음 - 추정값 사용');
    
    final duration = recordingData.endTime.difference(recordingData.startTime);
    final hours = duration.inHours;
    
    // 간단한 수면 품질 점수 계산
    double qualityScore = 75.0; // 기본값
    
    // 수면 시간에 따른 점수 조정
    if (hours >= 7 && hours <= 9) {
      qualityScore += 10;
    } else if (hours < 6 || hours > 10) {
      qualityScore -= 15;
    }

    // 움직임 데이터가 있다면 활용
    if (recordingData.accelerometerData.isNotEmpty) {
      final avgMovement = recordingData.accelerometerData
          .map((data) => (data.x.abs() + data.y.abs() + data.z.abs()) / 3)
          .reduce((a, b) => a + b) / recordingData.accelerometerData.length;
      
      // 움직임이 적을수록 수면 품질이 좋다고 가정
      if (avgMovement < 0.5) {
        qualityScore += 5;
      } else if (avgMovement > 1.0) {
        qualityScore -= 10;
      }
    }

    // 점수 범위 제한
    qualityScore = qualityScore.clamp(0.0, 100.0);

    // 실제 수면 시간 (취침 후 30분 뒤부터 수면 시작으로 가정)
    final sleepTime = recordingData.startTime.add(const Duration(minutes: 30));
    
    // 총 수면 시간에서 깨어있는 시간 제외
    final awakeTime = Duration(minutes: (duration.inMinutes * 0.1).round());
    final totalSleepTime = duration - awakeTime;
    
    // 수면 단계별 시간 분배 (간단한 추정)
    final deepSleepTime = Duration(minutes: (totalSleepTime.inMinutes * 0.25).round());
    final lightSleepTime = Duration(minutes: (totalSleepTime.inMinutes * 0.55).round());
    final remSleepTime = Duration(minutes: (totalSleepTime.inMinutes * 0.20).round());

    return SleepData(
      id: recordingData.sessionId,
      sleepDate: sleepDate,
      bedTime: recordingData.startTime,
      sleepTime: sleepTime,
      wakeTime: recordingData.endTime,
      totalSleepDuration: totalSleepTime,
      deepSleepDuration: deepSleepTime,
      lightSleepDuration: lightSleepTime,
      remSleepDuration: remSleepTime,
      awakeTimeDuration: awakeTime,
      sleepQualityScore: qualityScore,
      sourceId: 'device_measurement',
      recordedAt: DateTime.now(),
    );
  }

  /// 11월 12일 디바이스 측정 더미 데이터 생성 (HealthKit과 약간 다른 수치)
  static Future<String> generateNovember12DummyData() async {
    // HealthKit 데이터: 취침 6:06, 기상 13:23 (7시간 17분)
    // 디바이스 데이터: 취침 6:15, 기상 13:30 (7시간 15분) - 약간 다르게 설정
    
    final startTime = DateTime(2024, 11, 12, 6, 15); // 오전 6:15 취침
    final endTime = DateTime(2024, 11, 12, 13, 30);  // 오후 1:30 기상
    
    // 총 수면시간: 7시간 15분 (435분)
    final totalMinutes = endTime.difference(startTime).inMinutes;
    
    // 수면 단계별 시간 (HealthKit과 약간 다르게)
    // HealthKit: 깊은잠 1:08, 얕은잠 4:30, REM 1:32, 깨어있음 6분
    // 디바이스: 깊은잠 1:15, 얕은잠 4:20, REM 1:25, 깨어있음 15분
    
    final deepSleepMinutes = 75;  // 1시간 15분 (HealthKit: 68분)
    final lightSleepMinutes = 260; // 4시간 20분 (HealthKit: 270분)
    final remSleepMinutes = 85;   // 1시간 25분 (HealthKit: 92분)
    final awakeMinutes = 15;      // 15분 (HealthKit: 6분)
    
    // 센서 데이터 생성 (10초 간격으로 생성)
    final accelerometerData = <AccelerometerData>[];
    final audioData = <AudioData>[];
    
    final random = Random(42); // 시드 고정으로 일관된 데이터 생성
    
    // 10초 간격으로 데이터 생성
    for (int i = 0; i < totalMinutes * 6; i++) { // 6 = 60초 / 10초
      final timestamp = startTime.add(Duration(seconds: i * 10));
      
      // 수면 단계에 따른 움직임 패턴
      final minuteFromStart = timestamp.difference(startTime).inMinutes;
      double movementIntensity;
      
      if (minuteFromStart < 30 || minuteFromStart > totalMinutes - 30) {
        // 잠들기 전/깨어나기 전: 높은 움직임
        movementIntensity = 0.6 + random.nextDouble() * 0.4;
      } else if (minuteFromStart >= 60 && minuteFromStart <= 135) {
        // 깊은 잠: 낮은 움직임
        movementIntensity = 0.1 + random.nextDouble() * 0.2;
      } else if (minuteFromStart >= 350 && minuteFromStart <= 435) {
        // REM 수면: 중간 움직임
        movementIntensity = 0.3 + random.nextDouble() * 0.3;
      } else {
        // 얕은 잠: 중간-낮은 움직임
        movementIntensity = 0.2 + random.nextDouble() * 0.3;
      }
      
      // 가속도계 데이터 (움직임 강도에 따라)
      accelerometerData.add(AccelerometerData.fromSleepStart(
        timestamp: timestamp,
        sleepStartTime: startTime,
        x: (random.nextDouble() - 0.5) * movementIntensity,
        y: (random.nextDouble() - 0.5) * movementIntensity,
        z: 9.8 + (random.nextDouble() - 0.5) * movementIntensity,
      ));
      
      // 오디오 데이터 (수면 단계에 따른 소음 레벨)
      double noiseLevel;
      if (minuteFromStart >= 350 && minuteFromStart <= 435) {
        // REM 수면: 약간 높은 소음 (꿈꾸기, 뒤척임)
        noiseLevel = 0.15 + random.nextDouble() * 0.1;
      } else if (minuteFromStart >= 60 && minuteFromStart <= 135) {
        // 깊은 잠: 매우 낮은 소음
        noiseLevel = 0.05 + random.nextDouble() * 0.05;
      } else {
        // 기타: 중간 소음
        noiseLevel = 0.1 + random.nextDouble() * 0.08;
      }
      
      audioData.add(AudioData.fromSleepStart(
        timestamp: timestamp,
        sleepStartTime: startTime,
        amplitude: noiseLevel,
        frequencyBands: List.generate(8, (index) => 
          noiseLevel * (0.8 + random.nextDouble() * 0.4)),
      ));
    }
    
    // SleepRecordingData 생성
    final sleepRecordingData = SleepRecordingData.create(
      startTime: startTime,
      endTime: endTime,
      accelerometerData: accelerometerData,
      audioData: audioData,
    );
    
    // 파일로 저장
    final filePath = await saveSleepData(sleepRecordingData);
    
    print('📅 11월 12일 디바이스 더미 데이터 생성 완료');
    print('🛏️ 취침: ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}');
    print('🌅 기상: ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}');
    print('⏰ 총 수면시간: ${(totalMinutes ~/ 60)}시간 ${totalMinutes % 60}분');
    print('😴 깊은 잠: ${deepSleepMinutes ~/ 60}시간 ${deepSleepMinutes % 60}분');
    print('💤 얕은 잠: ${lightSleepMinutes ~/ 60}시간 ${lightSleepMinutes % 60}분');
    print('🌙 REM 수면: ${remSleepMinutes ~/ 60}시간 ${remSleepMinutes % 60}분');
    print('👁️ 깨어있음: ${awakeMinutes}분');
    print('📊 센서 데이터: 가속도계 ${accelerometerData.length}개, 오디오 ${audioData.length}개');
    
    return filePath;
  }
}

