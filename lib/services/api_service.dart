import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/sleep_data.dart';
import '../models/sleep_recording_data.dart';
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
      print('ApiService - ⏳ 서버 응답 대기 중...');
      
      final response = await _dio.post('/oauth/login', data: requestData);
      
      print('');
      print('🎉 ========== API 응답 수신 ==========');
      print('ApiService - ✅ 응답 성공: ${response.statusCode}');
      print('ApiService - 📦 응답 데이터: ${response.data}');
      print('ApiService - 📦 응답 타입: ${response.data.runtimeType}');
      print('==================================');
      print('');
      
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

      // JWT 토큰 페이로드 디코딩하여 user_id 추출
      String? userId;
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final payloadMap = json.decode(decoded) as Map<String, dynamic>;
          userId = payloadMap['user_id']?.toString() ?? 
                   payloadMap['userId']?.toString() ?? 
                   payloadMap['sub']?.toString();
          print('ApiService - JWT 페이로드에서 추출한 user_id: $userId');
          print('ApiService - JWT 전체 페이로드: $payloadMap');
        }
      } catch (e) {
        print('ApiService - JWT 디코딩 실패: $e');
        throw Exception('JWT 토큰 파싱에 실패했습니다.');
      }

      // user_id가 없으면 에러
      if (userId == null || userId.isEmpty) {
        throw Exception('JWT 토큰에서 user_id를 추출할 수 없습니다.');
      }

      final Map<String, dynamic> requestData = {
        'user_id': userId,          // 백엔드에서 요구하는 필드 추가
        'analysis_id': analysisId,
        'user_prompt': userPrompt,
      };

      print('ApiService - LLM 피드백 요청 중...');
      print('ApiService - 요청 URL: ${mlDio.options.baseUrl}/llm/feedback');
      print('ApiService - analysis_id: $analysisId');
      print('ApiService - user_prompt: $userPrompt');
      print('ApiService - JWT 토큰 길이: ${token.length}');
      print('ApiService - JWT 토큰 앞 50자: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
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
        print('ApiService - 응답 헤더: ${error.response?.headers}');
        print('ApiService - 요청 헤더: ${error.requestOptions.headers}');
        print('ApiService - 요청 경로: ${error.requestOptions.path}');
        print('ApiService - 요청 메서드: ${error.requestOptions.method}');
        
        // 422: 요청 데이터 유효성 검증 실패
        if (error.response?.statusCode == 422) {
          final errorData = error.response?.data;
          print('⚠️ 요청 데이터 유효성 검증 실패:');
          print('   - 에러 상세: $errorData');
          throw Exception('요청 데이터가 올바르지 않습니다. 다시 시도해주세요.');
        }
        
        // 500: 서버 내부 오류 - 더 자세한 정보 출력
        if (error.response?.statusCode == 500) {
          final errorData = error.response?.data;
          if (errorData is Map) {
            final requestId = errorData['request_id'];
            final errorMessage = errorData['error_message'];
            print('⚠️ 백엔드 개발자에게 전달할 정보:');
            print('   - request_id: $requestId');
            print('   - error_message: $errorMessage');
            print('   - analysis_id: $analysisId');
            print('   - 이 정보로 서버 로그를 확인해주세요!');
          }
          throw Exception('서버에서 피드백 생성 중 오류가 발생했습니다. 백엔드 개발자에게 문의해주세요.');
        }
        
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

  /// === ML 수면 분석 API ===

  /// 수면 데이터 분석 요청
  /// 
  /// [sleepRecordingData] 수집된 가속도계 및 오디오 데이터
  /// [retryCount] 재시도 횟수 (내부 사용, 기본값: 0)
  /// 
  /// Returns: 수면 분석 결과
  /// 
  /// API: POST /api/ml/sleep/analyze
  static Future<SleepAnalysisResult> analyzeSleepData(
    SleepRecordingData sleepRecordingData, {
    int retryCount = 0,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('JWT 토큰이 없습니다. 로그인이 필요합니다.');
      }

      print('');
      print('🔐 ========== JWT 토큰 확인 ==========');
      print('ApiService - JWT 토큰 존재: ${token.isNotEmpty ? "✅" : "❌"}');
      print('ApiService - JWT 토큰 길이: ${token.length}자');
      print('ApiService - JWT 토큰 앞 10자: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
      if (retryCount > 0) {
        print('ApiService - 🔄 재시도 횟수: $retryCount');
      }
      print('==================================');
      print('');

      print('ApiService - 수면 데이터 분석 요청 시작');
      print('ApiService - 세션 ID: ${sleepRecordingData.sessionId}');
      print('ApiService - 녹음 기간: ${sleepRecordingData.startTime.toIso8601String()} ~ ${sleepRecordingData.endTime.toIso8601String()}');
      print('ApiService - 녹음 시간: ${sleepRecordingData.duration.toStringAsFixed(0)}초 (${(sleepRecordingData.duration / 60).toStringAsFixed(1)}분)');
      print('ApiService - 가속도계 데이터: ${sleepRecordingData.accelerometerData.length}개');
      print('ApiService - 오디오 데이터: ${sleepRecordingData.audioData.length}개');
      print('ApiService - 데이터 품질: ${sleepRecordingData.dataQuality}');

      // ML 서버로 분석 요청 (base URL이 다름)
      final mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com';
      mlDio.options.connectTimeout = const Duration(minutes: 5);
      mlDio.options.receiveTimeout = const Duration(minutes: 5);

      print('');
      print('📤 ========== API 요청 정보 ==========');
      print('ApiService - 요청 URL: ${mlDio.options.baseUrl}/api/ml/sleep/analyze');
      print('ApiService - Authorization: Bearer ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      print('==================================');
      print('');

      final response = await mlDio.post(
        '/api/ml/sleep/analyze',
        data: sleepRecordingData.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('ApiService - 수면 데이터 분석 완료: ${response.statusCode}');
      
      // 응답 데이터를 SleepAnalysisResult 객체로 변환
      final result = SleepAnalysisResult.fromJson(response.data as Map<String, dynamic>);
      print('ApiService - 분석 ID: ${result.analysisId}');
      print('ApiService - 데이터 품질 점수: ${result.dataQualityScore}');
      
      return result;
    } catch (error) {
      print('ApiService - 수면 데이터 분석 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
        
        // 🔄 401 에러 시 자동 토큰 갱신 후 재시도 (최대 1회)
        if (error.response?.statusCode == 401 && retryCount == 0) {
          print('');
          print('⚠️ ========== JWT 토큰 만료 감지 ==========');
          print('ApiService - JWT 토큰이 만료되었습니다.');
          print('ApiService - 🔄 Refresh Token으로 자동 갱신 시도...');
          print('==================================');
          print('');

          try {
            // Refresh Token으로 새 Access Token 발급
            await refreshAccessToken();
            
            print('');
            print('✅ ========== 토큰 갱신 성공 ==========');
            print('ApiService - 새로운 Access Token으로 재시도합니다...');
            print('==================================');
            print('');
            
            // 재시도 (retryCount를 1로 증가시켜 무한 루프 방지)
            return await analyzeSleepData(sleepRecordingData, retryCount: 1);
          } catch (refreshError) {
            print('');
            print('❌ ========== 토큰 갱신 실패 ==========');
            print('ApiService - Refresh Token도 만료되었거나 유효하지 않습니다.');
            print('ApiService - 해결 방법: 앱에서 로그아웃 후 재로그인하세요.');
            print('==================================');
            print('');
            throw Exception('토큰 갱신 실패: $refreshError');
          }
        }
      }
      rethrow;
    }
  }

  /// JWT 토큰 갱신
  /// 
  /// Refresh Token을 사용하여 새로운 Access Token 발급
  /// 
  /// Returns: 새로운 Access Token
  /// 
  /// API: POST /api/v1/auth/tokens/refresh
  static Future<String> refreshAccessToken() async {
    try {
      final refreshToken = await OAuthService.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('Refresh Token이 없습니다. 다시 로그인해주세요.');
      }

      print('🔄 ApiService - Access Token 갱신 시작...');

      final response = await _dio.post(
        '/api/v1/auth/tokens/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
          },
        ),
      );

      if (response.data['success'] == true) {
        final newAccessToken = response.data['data']['accessToken'] as String;
        
        // 새 토큰 저장
        await OAuthService.saveJwtToken(newAccessToken);
        
        print('✅ ApiService - Access Token 갱신 완료');
        return newAccessToken;
      } else {
        throw Exception('토큰 갱신 실패: ${response.data['message']}');
      }
    } catch (error) {
      print('❌ ApiService - Access Token 갱신 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
      }
      rethrow;
    }
  }

  /// 수면 분석 이력 조회
  /// 
  /// [page] 페이지 번호 (기본값: 1)
  /// [pageSize] 페이지 크기 (기본값: 10)
  /// 
  /// Returns: 수면 분석 이력 목록
  /// 
  /// API: GET /api/ml/sleep/history
  static Future<Response> getSleepAnalysisHistory({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('JWT 토큰이 없습니다. 로그인이 필요합니다.');
      }

      print('ApiService - 수면 분석 이력 조회 요청: page=$page, pageSize=$pageSize');

      final mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com/api/ml';

      final response = await mlDio.get(
        '/sleep/history',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('ApiService - 수면 분석 이력 조회 완료: ${response.statusCode}');
      return response;
    } catch (error) {
      print('ApiService - 수면 분석 이력 조회 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
      }
      rethrow;
    }
  }

  /// 특정 수면 분석 결과 상세 조회
  /// 
  /// [analysisId] 분석 ID
  /// 
  /// Returns: 수면 분석 결과 상세
  /// 
  /// API: GET /api/ml/sleep/result/{analysis_id}
  static Future<SleepAnalysisResult> getSleepAnalysisResult(String analysisId) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('JWT 토큰이 없습니다. 로그인이 필요합니다.');
      }

      print('ApiService - 수면 분석 결과 상세 조회: $analysisId');

      final mlDio = Dio();
      mlDio.options.baseUrl = 'https://neulbo1.com/api/ml';

      final response = await mlDio.get(
        '/sleep/result/$analysisId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('ApiService - 수면 분석 결과 조회 완료: ${response.statusCode}');
      
      final result = SleepAnalysisResult.fromJson(response.data as Map<String, dynamic>);
      return result;
    } catch (error) {
      print('ApiService - 수면 분석 결과 조회 실패: $error');
      if (error is DioException) {
        print('ApiService - 응답 상태: ${error.response?.statusCode}');
        print('ApiService - 응답 내용: ${error.response?.data}');
      }
      rethrow;
    }
  }
}
