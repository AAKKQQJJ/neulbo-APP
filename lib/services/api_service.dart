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

  /// === 인증 관련 API ===
  
  /// OAuth 로그인
  static Future<Response> oauthLogin({
    required String provider,
    required String providerId,
    required String email,
    required String name,
    required String profileImageUrl,
    required String nickname,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'provider': provider,
        'providerId': providerId,
        'email': email,
        'name': name,
        'profileImageUrl': profileImageUrl,
        'nickname': nickname,
      };
      
      print('ApiService - 전송할 데이터: $requestData');
      print('ApiService - 요청 URL: ${_dio.options.baseUrl}/oauth/login');
      print('ApiService - Content-Type: ${_dio.options.headers['Content-Type']}');
      
      final response = await _dio.post('/oauth/login', data: requestData);
      print('ApiService - 응답 성공: ${response.statusCode}');
      return response;
    } catch (error) {
      print('ApiService - OAuth 로그인 실패: $error');
      
      // DioException인 경우 더 자세한 정보 출력
      if (error is DioException) {
        print('ApiService - 에러 타입: ${error.type}');
        print('ApiService - 상태 코드: ${error.response?.statusCode}');
        print('ApiService - 에러 메시지: ${error.message}');
        print('ApiService - 응답 데이터: ${error.response?.data}');
        print('ApiService - 요청 헤더: ${error.requestOptions.headers}');
      }
      
      rethrow;
    }
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
