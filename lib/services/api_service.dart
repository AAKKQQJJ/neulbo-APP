import 'package:dio/dio.dart';

import '../models/sleep_data.dart';
import 'oauth_service.dart';

class ApiService {
  static final Dio _dio = Dio();

  static void initialize() {
    _dio.options.baseUrl = 'https://neulbo1.com/api/v1';

    // 요청 인터셉터: JWT 토큰 자동 추가
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await OAuthService.getJwtToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // 401 에러시 토큰 갱신 로직 (선택사항)
          if (error.response?.statusCode == 401) {
            // 리프레시 토큰으로 새 토큰 발급 시도
            // ...
          }
          handler.next(error);
        },
      ),
    );
  }

  // 예시 API 호출
  static Future<Response> getUserProfile() async {
    return await _dio.get('/user/profile');
  }

  static Future<Response> updateUserInfo(Map<String, dynamic> data) async {
    return await _dio.post('/user/update', data: data);
  }

  /// === 수면 데이터 관련 API ===
  
  /// 수면 데이터 업로드
  static Future<Response> uploadSleepData(SleepData sleepData) async {
    try {
      return await _dio.post('/sleep/upload', data: sleepData.toJson());
    } catch (error) {
      print('ApiService - 수면 데이터 업로드 실패: $error');
      rethrow;
    }
  }

  /// 여러 수면 데이터 일괄 업로드
  static Future<Response> uploadMultipleSleepData(List<SleepData> sleepDataList) async {
    try {
      final List<Map<String, dynamic>> jsonList = 
          sleepDataList.map((data) => data.toJson()).toList();
      
      return await _dio.post('/sleep/upload-batch', data: {'sleepDataList': jsonList});
    } catch (error) {
      print('ApiService - 수면 데이터 일괄 업로드 실패: $error');
      rethrow;
    }
  }

  /// HealthKit 연동 상태 업데이트
  static Future<Response> updateHealthKitStatus(bool isConnected) async {
    try {
      return await _dio.post('/sleep/healthkit-status', data: {
        'isConnected': isConnected,
        'connectedAt': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      print('ApiService - HealthKit 연동 상태 업데이트 실패: $error');
      rethrow;
    }
  }
}
