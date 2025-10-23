import 'package:shared_preferences/shared_preferences.dart';

/// 수면 분석 ID 관리 서비스
/// 
/// 웨어러블 수면 데이터 분석 결과의 analysis_id를 저장하고 조회합니다.
class SleepAnalysisService {
  static const String _keyLastAnalysisId = 'last_sleep_analysis_id';
  static const String _keyLastAnalysisTimestamp = 'last_sleep_analysis_timestamp';
  static const String _keyLastAnalysisSummary = 'last_sleep_analysis_summary';

  /// 마지막 수면 분석 ID 저장
  /// 
  /// [analysisId] 분석 ID (UUID)
  /// [summary] 분석 요약 정보 (선택사항)
  static Future<void> saveLastAnalysisId({
    required String analysisId,
    String? summary,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastAnalysisId, analysisId);
      await prefs.setString(
        _keyLastAnalysisTimestamp,
        DateTime.now().toIso8601String(),
      );
      
      if (summary != null) {
        await prefs.setString(_keyLastAnalysisSummary, summary);
      }
      
      print('SleepAnalysisService - 분석 ID 저장 완료: $analysisId');
    } catch (error) {
      print('SleepAnalysisService - 분석 ID 저장 실패: $error');
    }
  }

  /// 마지막 수면 분석 ID 조회
  /// 
  /// Returns: 저장된 분석 ID 또는 null
  static Future<String?> getLastAnalysisId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? analysisId = prefs.getString(_keyLastAnalysisId);
      
      if (analysisId != null) {
        print('SleepAnalysisService - 저장된 분석 ID 조회: $analysisId');
        return analysisId;
      } else {
        print('SleepAnalysisService - 저장된 분석 ID가 없습니다');
        return null;
      }
    } catch (error) {
      print('SleepAnalysisService - 분석 ID 조회 실패: $error');
      return null;
    }
  }

  /// 마지막 수면 분석 타임스탬프 조회
  /// 
  /// Returns: 분석 저장 시간 또는 null
  static Future<DateTime?> getLastAnalysisTimestamp() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? timestampStr = prefs.getString(_keyLastAnalysisTimestamp);
      
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
      return null;
    } catch (error) {
      print('SleepAnalysisService - 타임스탬프 조회 실패: $error');
      return null;
    }
  }

  /// 마지막 수면 분석 요약 정보 조회
  /// 
  /// Returns: 분석 요약 또는 null
  static Future<String?> getLastAnalysisSummary() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastAnalysisSummary);
    } catch (error) {
      print('SleepAnalysisService - 분석 요약 조회 실패: $error');
      return null;
    }
  }

  /// 저장된 분석 ID 삭제
  static Future<void> clearLastAnalysisId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastAnalysisId);
      await prefs.remove(_keyLastAnalysisTimestamp);
      await prefs.remove(_keyLastAnalysisSummary);
      print('SleepAnalysisService - 분석 ID 삭제 완료');
    } catch (error) {
      print('SleepAnalysisService - 분석 ID 삭제 실패: $error');
    }
  }

  /// 분석 ID 유효성 확인
  /// 
  /// 저장된 분석 ID가 있고, 최근 7일 이내의 데이터인지 확인합니다.
  /// 
  /// Returns: 유효한 분석 ID 또는 null
  static Future<String?> getValidAnalysisId() async {
    try {
      final String? analysisId = await getLastAnalysisId();
      if (analysisId == null) {
        print('SleepAnalysisService - 분석 ID가 없습니다');
        return null;
      }

      final DateTime? timestamp = await getLastAnalysisTimestamp();
      if (timestamp == null) {
        print('SleepAnalysisService - 타임스탬프가 없습니다');
        return analysisId; // 타임스탬프가 없어도 ID는 반환
      }

      // 7일 이내 데이터인지 확인
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(timestamp);
      
      if (difference.inDays > 7) {
        print('SleepAnalysisService - 분석 데이터가 너무 오래되었습니다 (${difference.inDays}일 전)');
        print('SleepAnalysisService - 새로운 수면 데이터를 동기화해주세요');
        return null;
      }

      print('SleepAnalysisService - 유효한 분석 ID: $analysisId (${difference.inDays}일 전)');
      return analysisId;
    } catch (error) {
      print('SleepAnalysisService - 분석 ID 유효성 확인 실패: $error');
      return null;
    }
  }

  /// 분석 ID 상태 정보 조회
  /// 
  /// Returns: 분석 ID 상태 정보 맵
  static Future<Map<String, dynamic>> getAnalysisStatus() async {
    try {
      final String? analysisId = await getLastAnalysisId();
      final DateTime? timestamp = await getLastAnalysisTimestamp();
      final String? summary = await getLastAnalysisSummary();

      if (analysisId == null) {
        return {
          'hasAnalysisId': false,
          'message': '수면 데이터를 먼저 동기화해주세요',
          'detail': 'HealthKit에서 수면 데이터를 가져와 분석해야 합니다.',
        };
      }

      final DateTime now = DateTime.now();
      final Duration? difference = timestamp != null ? now.difference(timestamp) : null;

      if (difference != null && difference.inDays > 7) {
        return {
          'hasAnalysisId': true,
          'isValid': false,
          'analysisId': analysisId,
          'daysAgo': difference.inDays,
          'message': '수면 데이터가 오래되었습니다',
          'detail': '최신 수면 데이터를 동기화하면 더 정확한 답변을 받을 수 있습니다.',
          'summary': summary,
        };
      }

      return {
        'hasAnalysisId': true,
        'isValid': true,
        'analysisId': analysisId,
        'daysAgo': difference?.inDays ?? 0,
        'message': '수면 분석 데이터 준비됨',
        'detail': '${difference?.inDays ?? 0}일 전 데이터를 기반으로 답변합니다.',
        'summary': summary,
      };
    } catch (error) {
      print('SleepAnalysisService - 상태 조회 실패: $error');
      return {
        'hasAnalysisId': false,
        'message': '상태 확인 실패',
        'detail': '오류가 발생했습니다: $error',
      };
    }
  }
}

