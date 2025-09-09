import 'package:dio/dio.dart';

import 'oauth_service.dart';

class ApiService {
  static final Dio _dio = Dio();

  static void initialize() {
    _dio.options.baseUrl = 'https://your-backend.com/api';

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
}
