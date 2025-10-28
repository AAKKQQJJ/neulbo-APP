import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/sleep_recording_data.dart';

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
}

