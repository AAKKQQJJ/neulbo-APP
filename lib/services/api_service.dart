import 'package:dio/dio.dart';

import '../models/sleep_data.dart';
import 'oauth_service.dart';
import 'user_service.dart';

class ApiService {
  static final Dio _dio = Dio();

  static void initialize() {
    _dio.options.baseUrl = 'https://neulbo1.com/api/v1';

    // 요청 인터셉터: JWT 토큰 자동 추가
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // OAuth 로그인 엔드포인트는 기존 토큰을 포함하지 않음
          if (options.path == '/oauth/login') {
            print('ApiService - OAuth 로그인 요청: 기존 토큰 제외');
            handler.next(options);
            return;
          }
          
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
      print('ApiService - OAuth 로그인 요청 시작...');
      
      final response = await _dio.post('/oauth/login', data: requestData);
      print('ApiService - 응답 성공: ${response.statusCode}');
      print('ApiService - 응답 데이터: ${response.data}');
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

  /// === 사용자 관리 API ===
  
  /// 현재 사용자 프로필 조회
  static Future<Response> getUserProfile() async {
    try {
      return await _dio.get('/users/me/profile');
    } catch (error) {
      print('ApiService - 사용자 프로필 조회 실패: $error');
      rethrow;
    }
  }

  /// 현재 사용자 계정 정보 조회
  static Future<Response> getUserAccount() async {
    try {
      return await _dio.get('/users/me/account');
    } catch (error) {
      print('ApiService - 사용자 계정 조회 실패: $error');
      rethrow;
    }
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

  /// === 웨어러블 기기 수면 분석 API (ML 서버) ===
  
  /// 웨어러블 기기 수면 데이터 분석 및 저장
  /// 
  /// [userId] 사용자 ID (UUID 형식)
  /// [deviceType] 웨어러블 기기 타입 ("apple_watch", "galaxy_watch")
  /// [sleepStart] 수면 시작 시간 (ISO 8601 형식)
  /// [sleepEnd] 수면 종료 시간 (ISO 8601 형식)
  /// [sleepStages] 수면 단계별 데이터 배열
  /// [heartRate] 평균 심박수 (optional, 30.0-200.0 bpm)
  /// [sleepAnalysisMetadata] 기기별 메타데이터 (optional)
  /// [deviceId] 기기 고유 ID (optional, 최대 50자)
  static Future<Response> analyzeWearableSleepData({
    required String userId,
    required String deviceType,
    required DateTime sleepStart,
    required DateTime sleepEnd,
    required List<Map<String, dynamic>> sleepStages,
    double? heartRate,
    Map<String, dynamic>? sleepAnalysisMetadata,
    String? deviceId,
  }) async {
    try {
      // ML 서버 엔드포인트로 요청 (JWT 인증 필요)
      final Dio mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com/api/ml';

      // JWT 토큰 가져오기
      final String? token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다. JWT 토큰이 없습니다.');
      }

      final Map<String, dynamic> requestData = {
        'user_id': userId,
        'device_type': deviceType,
        'sleep_start': sleepStart.toUtc().toIso8601String(),
        'sleep_end': sleepEnd.toUtc().toIso8601String(),
        'sleep_stages': sleepStages,
      };

      // Optional 필드 추가
      if (heartRate != null) {
        requestData['heart_rate'] = heartRate;
      }
      if (sleepAnalysisMetadata != null) {
        requestData['sleep_analysis_metadata'] = sleepAnalysisMetadata;
      }
      if (deviceId != null) {
        requestData['device_id'] = deviceId;
      }

      print('ApiService - 웨어러블 수면 데이터 전송 중...');
      print('ApiService - deviceType: $deviceType');
      print('ApiService - sleepStages 개수: ${sleepStages.length}');
      print('ApiService - JWT 토큰: ${token.substring(0, 20)}...');

      final Response response = await mlDio.post(
        '/wearable/analyze',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('ApiService - 웨어러블 수면 데이터 분석 완료: ${response.statusCode}');
      return response;
    } catch (error) {
      print('ApiService - 웨어러블 수면 데이터 분석 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
        
        // 403: 인증 오류
        if (error.response?.statusCode == 403) {
          throw Exception('인증에 실패했습니다. 다시 로그인해주세요.');
        }
        // 401: 토큰 만료
        if (error.response?.statusCode == 401) {
          throw Exception('로그인이 만료되었습니다. 다시 로그인해주세요.');
        }
      }
      rethrow;
    }
  }

  /// === LLM 피드백 API (ML 서버) ===

  /// LLM 피드백 생성 (JWT 인증)
  /// 
  /// 사용자의 수면 분석 결과를 기반으로 AI가 맞춤형 피드백을 생성합니다.
  /// 
  /// [analysisId] 수면 분석 ID (UUID 형식) - 웨어러블 분석 결과의 analysis_id
  /// [userPrompt] 사용자 질문 (1-1000자)
  /// 
  /// Returns: LLM 응답, 모델 정보, 응답 시간 등
  static Future<Response> sendLlmFeedback({
    required String analysisId,
    required String userPrompt,
  }) async {
    try {
      // ML 서버 엔드포인트로 요청 (JWT 토큰 자동 주입)
      final Dio mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com/api/ml';

      // JWT 토큰 가져오기
      final String? token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다. JWT 토큰이 없습니다.');
      }

      final Map<String, dynamic> requestData = {
        'analysis_id': analysisId,
        'user_prompt': userPrompt,
      };

      print('ApiService - LLM 피드백 요청 중...');
      print('ApiService - 요청 URL: ${mlDio.options.baseUrl}/llm/feedback');
      print('ApiService - analysis_id: $analysisId');
      print('ApiService - user_prompt: $userPrompt');
      print('ApiService - JWT 토큰 길이: ${token.length}');
      print('ApiService - 요청 데이터: $requestData');

      final Response response = await mlDio.post(
        '/llm/feedback',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('ApiService - LLM 피드백 생성 완료: ${response.statusCode}');
      print('ApiService - 응답 시간: ${response.data['response_time_ms']}ms');
      return response;
    } catch (error) {
      print('ApiService - LLM 피드백 생성 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
        
        // 404: 분석 결과 없음
        if (error.response?.statusCode == 404) {
          throw Exception('해당하는 수면 분석 데이터를 찾을 수 없습니다. 먼저 수면 데이터를 동기화해주세요.');
        }
        // 401: 인증 오류
        if (error.response?.statusCode == 401) {
          throw Exception('인증에 실패했습니다. 다시 로그인해주세요.');
        }
      }
      rethrow;
    }
  }

  /// LLM 피드백 히스토리 조회
  /// 
  /// 현재 사용자의 이전 대화 내역을 조회합니다.
  /// 
  /// [limit] 조회할 피드백 개수 (기본값: 10)
  /// 
  /// Returns: 피드백 히스토리 리스트
  static Future<Response> getLlmFeedbackHistory({
    int limit = 10,
  }) async {
    try {
      // ML 서버 엔드포인트로 요청
      final Dio mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com/api/ml';

      // 사용자 ID 가져오기
      final String? userId = UserService.getUserId();
      if (userId == null) {
        throw Exception('로그인이 필요합니다. 사용자 ID가 없습니다.');
      }

      print('ApiService - LLM 피드백 히스토리 조회 중...');
      print('ApiService - user_id: $userId');
      print('ApiService - limit: $limit');

      final Response response = await mlDio.get(
        '/llm/feedback/history/$userId',
        queryParameters: {'limit': limit},
      );

      print('ApiService - LLM 피드백 히스토리 조회 완료: ${response.statusCode}');
      print('ApiService - 조회된 피드백 개수: ${(response.data as List).length}');
      return response;
    } catch (error) {
      print('ApiService - LLM 피드백 히스토리 조회 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
      }
      rethrow;
    }
  }

  /// 특정 LLM 피드백 상세 조회
  /// 
  /// [feedbackId] 피드백 ID (UUID 형식)
  /// 
  /// Returns: 피드백 상세 정보
  static Future<Response> getLlmFeedbackDetail({
    required String feedbackId,
  }) async {
    try {
      final Dio mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com/api/ml';

      // JWT 토큰 가져오기
      final String? token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다. JWT 토큰이 없습니다.');
      }

      print('ApiService - LLM 피드백 상세 조회 중...');
      print('ApiService - feedback_id: $feedbackId');

      final Response response = await mlDio.get(
        '/llm/feedback/$feedbackId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('ApiService - LLM 피드백 상세 조회 완료: ${response.statusCode}');
      return response;
    } catch (error) {
      print('ApiService - LLM 피드백 상세 조회 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
      }
      rethrow;
    }
  }
}
