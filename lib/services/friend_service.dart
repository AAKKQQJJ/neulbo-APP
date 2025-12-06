import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

import '../models/friend.dart';
import '../models/friend_sleep_data.dart';
import 'oauth_service.dart';

/// 이미 친구 요청을 보낸 경우의 예외
class AlreadyRequestedException implements Exception {
  final String message;
  const AlreadyRequestedException(this.message);
  
  @override
  String toString() => message;
}

class FriendService {
  static const String baseUrl = 'https://neulbo1.com/api/v1';
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // 친구 목록 조회
  static Future<Map<String, dynamic>> getFriends({
    String? search,
    int page = 0,
    int size = 20,
    String sort = 'name',
  }) async {
    print('📞 FriendService.getFriends 호출');
    print('🎯 파라미터: search=$search, page=$page, size=$size, sort=$sort');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      // 쿼리 파라미터 구성
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('https://neulbo1.com/api/v1/friends').replace(queryParameters: queryParams);
      
      print('📡 친구 목록 조회 API 호출 시작');
      print('- URL: $uri');
      print('- Method: GET');

      final response = await FriendService._dio.get(
        '/friends',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📄 친구 목록 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // 두 가지 응답 구조 처리
        if (data['success'] == true) {
          // API 명세서 형식: {success: true, data: {friends: [...], pagination: {...}}}
          print('✅ 친구 목록 조회 성공 (API 명세서 형식)');
          
          final friendsData = data['data']['friends'] as List;
          final friends = friendsData.map((friendJson) => Friend.fromJson(friendJson)).toList();
          
          print('📋 친구 수: ${friends.length}개');
          
          return {
            'friends': friends,
            'pagination': data['data']['pagination'],
          };
        } else if (data['content'] != null) {
          // Spring Boot 페이지네이션 형식: {content: [...], pageable: {...}, totalElements: ...}
          print('✅ 친구 목록 조회 성공 (Spring Boot 페이지네이션 형식)');
          
          final friendsData = data['content'] as List;
          final friends = friendsData.map((friendJson) => Friend.fromJson(friendJson)).toList();
          
          print('📋 친구 수: ${friends.length}개');
          
          // Spring Boot 페이지네이션을 표준 형식으로 변환
          return {
            'friends': friends,
            'pagination': {
              'currentPage': data['number'] ?? 0,
              'totalPages': data['totalPages'] ?? 1,
              'totalElements': data['totalElements'] ?? friends.length,
              'size': data['size'] ?? friends.length,
              'hasNext': !(data['last'] ?? true),
              'hasPrevious': !(data['first'] ?? true),
            },
          };
        } else {
          throw Exception(data['message'] ?? '친구 목록 조회에 실패했습니다');
        }
      } else {
        throw Exception('친구 목록 조회 실패: ${response.data?['message'] ?? 'HTTP ${response.statusCode}'}');
      }
    } catch (e) {
      print('❌ 친구 목록 조회 에러: $e');
      
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] as String?;
        
        print('🚨 DioException 상세:');
        print('- Status Code: $statusCode');
        print('- Response Data: ${e.response?.data}');
        print('- Error Type: ${e.type}');
        print('- Error Message: ${e.message}');
        
        switch (statusCode) {
          case 401:
            throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
          case 403:
            throw Exception('친구 목록에 접근할 권한이 없습니다.');
          case 404:
            throw Exception('친구 목록을 찾을 수 없습니다.');
          default:
            throw Exception('HTTP $statusCode: ${message ?? '친구 목록 조회에 실패했습니다'}');
        }
      }
      
      throw Exception('친구 목록 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 요청 보내기
  static Future<FriendRequest> sendFriendRequest({
    required String targetUserId,
    String? message,
  }) async {
    print('📤 FriendService: 친구 요청 보내기 시작 (HTTP 버전)');
    print('🎯 대상 사용자 ID: $targetUserId');
    print('💬 메시지: ${message ?? "메시지 없음"}');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final requestBody = <String, dynamic>{
        'targetUserId': targetUserId,
      };

      if (message != null && message.isNotEmpty) {
        requestBody['message'] = message;
      }

      print('📡 HTTP 요청 시작');
      print('- URL: $baseUrl/friends/request');
      print('- Method: POST');
      print('- Request Body: $requestBody');
      print('- Headers: Authorization: Bearer ${token.substring(0, 20)}..., Content-Type: application/json');

      // 먼저 POST 시도
      var response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      // 405 에러면 PUT으로 재시도
      if (response.statusCode == 405) {
        print('🔄 POST 실패, PUT 메서드로 재시도...');
        response = await http.put(
          Uri.parse('$baseUrl/friends/request'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(requestBody),
        );
        print('📄 PUT 응답: Status ${response.statusCode}');
        print('📄 PUT 응답 본문: ${response.body}');
      }

      print('📄 HTTP 응답 받음: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✅ 친구 요청 성공!');
        print('📋 응답 데이터: $data');
        
        // 서버 응답이 직접 FriendRequest 객체 형태로 오는 경우
        if (data.containsKey('friendRequestId')) {
          return FriendRequest.fromJson(data);
        }
        // API 명세서 형태로 오는 경우
        else if (data['success'] == true) {
          return FriendRequest.fromJson(data['data']);
        } else {
          print('❌ 서버에서 실패 응답: ${data['message']}');
          throw Exception(data['message'] ?? '친구 요청 전송에 실패했습니다');
        }
      } else if (response.statusCode == 405) {
        print('🚨 405 Method Not Allowed 에러 상세:');
        print('- 요청한 HTTP 메서드(POST)가 허용되지 않습니다');
        print('- 서버 응답: ${response.body}');
        print('- 가능한 원인:');
        print('  1. API 엔드포인트 경로가 잘못됨: $baseUrl/friends/request');
        print('  2. 서버에서 POST 메서드를 지원하지 않음');
        print('  3. API 버전이나 경로가 변경됨');
        throw Exception('HTTP ${response.statusCode}: 친구 요청 전송에 실패했습니다');
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final message = data['message'] as String?;
        
        if (message != null && message.contains('이미 친구 요청을 보냈거나 받은 상태입니다')) {
          print('🔄 이미 친구 요청이 존재함');
          throw AlreadyRequestedException(message);
        } else {
          print('🚨 400 Bad Request: $message');
          throw Exception('HTTP ${response.statusCode}: ${message ?? '친구 요청 전송에 실패했습니다'}');
        }
      } else {
        print('🚨 기타 HTTP 에러: ${response.statusCode}');
        print('- 응답 본문: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: 친구 요청 전송에 실패했습니다');
      }
    } catch (e) {
      print('❌ FriendService 에러 발생: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      throw Exception('친구 요청 전송 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 요청 목록 조회 - 더미 메서드 (실제 구현은 extension에서)
  Future<Map<String, dynamic>> _getFriendRequestsOrig({
    String type = 'received', // received, sent
    String status = 'all', // all, pending, accepted, rejected
    int page = 0,
    int size = 20,
  }) async {
    print('🔄 더미 getFriendRequests 메서드 - Extension 메서드가 우선 호출됨');
    throw Exception('이 메서드는 사용되지 않아야 합니다. Extension 메서드를 확인하세요.');
  }

  // 기존 HTTP 구현 (백업용)
  Future<Map<String, dynamic>> _getFriendRequestsOld({
    String type = 'received', // received, sent
    String status = 'all', // all, pending, accepted, rejected
    int page = 0,
    int size = 20,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final queryParams = {
        'type': type,
        'status': status,
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse('$baseUrl/friends/requests').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // API 명세서에 따른 응답 구조 처리
        if (data['success'] == true) {
          // 표준 API 응답 구조
          final responseData = data['data'];
          final friendRequests = (responseData['friendRequests'] as List)
              .map((requestJson) => FriendRequest.fromJson(requestJson))
              .toList();

          return {
            'friendRequests': friendRequests,
            'pagination': responseData['pagination'],
          };
        } else {
          // Spring Boot 페이지네이션 응답 구조 (content 기반)
          final friendRequests = (data['content'] as List)
              .map((requestJson) => FriendRequest.fromJson(requestJson))
              .toList();

          return {
            'friendRequests': friendRequests,
            'pagination': {
              'currentPage': data['number'],
              'totalPages': data['totalPages'],
              'totalElements': data['totalElements'],
              'size': data['size'],
              'hasNext': !data['last'],
              'hasPrevious': !data['first'],
            },
          };
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 요청 목록 조회에 실패했습니다');
      }
    } catch (e) {
      throw Exception('친구 요청 목록 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 요청 응답 (수락/거절)
  Future<Map<String, dynamic>> respondToFriendRequest({
    required String requestId,
    required FriendRequestAction action,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final requestBody = {
        'action': action.toString(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/friends/requests/$requestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // API 명세서에 따른 응답 데이터 반환
          return {
            'friendRequestId': data['data']['friendRequestId'],
            'status': data['data']['status'],
            'processedAt': data['data']['processedAt'],
            'friendship': data['data']['friendship'], // 수락 시에만 존재
          };
        } else {
          throw Exception(data['message'] ?? '친구 요청 응답에 실패했습니다');
        }
      } else {
        final errorData = json.decode(response.body);
        final message = errorData['message'] ?? 'HTTP ${response.statusCode}: 친구 요청 응답에 실패했습니다';
        throw Exception(message);
      }
    } catch (e) {
      throw Exception('친구 요청 응답 중 오류가 발생했습니다: $e');
    }
  }


  // 사용자 검색 (친구 추가용) - DEPRECATED: Extension 메서드 사용
  Future<Map<String, dynamic>> _searchUsersOld({
    required String query,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final queryParams = {
        'query': query,
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse('$baseUrl/users/search').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final users = (data['data']['users'] as List)
              .map((userJson) => UserSearchResult.fromJson(userJson))
              .toList();

          return {
            'users': users,
            'pagination': data['data']['pagination'],
          };
        } else {
          throw Exception(data['message'] ?? '사용자 검색에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 사용자 검색에 실패했습니다');
      }
    } catch (e) {
      throw Exception('사용자 검색 중 오류가 발생했습니다: $e');
    }
  }

  // 사용자 검색 (친구 추가용)
  static Future<Map<String, dynamic>> searchUsers({
    required String query,
    int page = 0,
    int size = 10,
  }) async {
    print('🔍 사용자 검색 시작: query="$query", page=$page, size=$size');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      print('📡 API 요청 시작: ${FriendService._dio.options.baseUrl}/users/search');
      
      final response = await FriendService._dio.get(
        '/users/search',
        queryParameters: {
          'query': query,
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ API 응답 성공: Status ${response.statusCode}');
      print('📄 응답 데이터: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        print('🔍 서버 응답 data 구조: $data');
        
        // 서버 응답 구조에 맞게 수정: content 필드 사용
        final users = (data['content'] as List)
            .map((user) => UserSearchResult.fromJson(user))
            .toList();
        
        // 페이지네이션 정보 매핑
        final pagination = {
          'currentPage': data['number'] ?? 0,
          'totalPages': data['totalPages'] ?? 0,
          'totalElements': data['totalElements'] ?? 0,
          'size': data['size'] ?? 10,
          'hasNext': !(data['last'] ?? true),
          'hasPrevious': !(data['first'] ?? true),
        };
        
        return {
          'users': users,
          'pagination': pagination,
        };
      } else {
        throw Exception('사용자 검색 실패: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ 사용자 검색 에러 발생: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      
      if (e is DioException) {
        print('🔍 DioException 상세 정보:');
        print('- Status Code: ${e.response?.statusCode}');
        print('- Response Data: ${e.response?.data}');
        print('- Request URL: ${e.requestOptions.uri}');
        print('- Request Headers: ${e.requestOptions.headers}');
        print('- Request Query: ${e.requestOptions.queryParameters}');
        print('- Error Type: ${e.type}');
        print('- Error Message: ${e.message}');
        
        if (e.response?.statusCode == 401) {
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        } else if (e.response?.statusCode == 404) {
          // 검색 결과가 없는 경우
          print('📭 검색 결과 없음 - 빈 결과 반환');
          return {
            'users': <UserSearchResult>[],
            'pagination': {
              'currentPage': page,
              'totalPages': 0,
              'totalElements': 0,
              'size': size,
              'hasNext': false,
              'hasPrevious': false,
            },
          };
        } else if (e.response?.statusCode == 500) {
          final errorMessage = e.response?.data?['message'] ?? '서버 내부 오류가 발생했습니다';
          print('🚨 500 에러 상세: $errorMessage');
          print('💡 서버 문제로 인한 검색 실패 - 잠시 후 다시 시도해주세요');
          throw Exception('서버에 일시적인 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.');
        } else {
          throw Exception('HTTP ${e.response?.statusCode}: 사용자 검색에 실패했습니다');
        }
      }
      
      throw Exception('사용자 검색 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 요청 목록 조회
  static Future<Map<String, dynamic>> getFriendRequests({
    String type = 'received', // received, sent
    String status = 'pending', // all, pending, accepted, rejected
    int page = 0,
    int size = 20,
  }) async {
    print('📞 FriendService.getFriendRequests 호출');
    print('🎯 파라미터: type=$type, status=$status, page=$page, size=$size');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      print('📡 친구 요청 목록 API 호출 시작');
      print('- URL: https://neulbo1.com/api/v1/friends/requests');
      print('- Query: type=$type, status=$status, page=$page, size=$size');

      final response = await FriendService._dio.get(
        '/friends/requests',
        queryParameters: {
          'type': type,
          'status': status,
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📄 친구 요청 목록 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // API 명세서에 따른 응답 구조 처리
        if (data['success'] == true) {
          print('✅ 친구 요청 목록 조회 성공');
          
          final responseData = data['data'];
          final requests = (responseData['friendRequests'] as List)
              .map((request) => FriendRequest.fromJson(request))
              .toList();
          
          return {
            'friendRequests': requests,
            'pagination': responseData['pagination'],
          };
        } else {
          // Spring Boot 페이지네이션 응답 구조 (content 기반)
          print('📋 Spring Boot 페이지네이션 응답 구조 감지');
          final requests = (data['content'] as List)
              .map((request) => FriendRequest.fromJson(request))
              .toList();
          
          return {
            'friendRequests': requests,
            'pagination': {
              'currentPage': data['number'],
              'totalPages': data['totalPages'],
              'totalElements': data['totalElements'],
              'size': data['size'],
              'hasNext': !data['last'],
              'hasPrevious': !data['first'],
            },
          };
        }
      } else {
        throw Exception('친구 요청 목록 조회 실패: ${response.data?['message'] ?? 'HTTP ${response.statusCode}'}');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        }
      }
      throw Exception('친구 요청 목록 조회 중 오류 발생: $e');
    }
  }

  // 친구 요청 응답 (수락/거절)
  static Future<Map<String, dynamic>> respondToFriendRequestApi({
    required String requestId,
    required String action, // ACCEPT, REJECT
  }) async {
    print('📞 FriendService.respondToFriendRequestApi 호출');
    print('🎯 요청 ID: $requestId, 액션: $action');
    
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      final response = await FriendService._dio.put(
        '/friends/requests/$requestId',
        data: {'action': action},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📄 친구 요청 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.data}');

      if (response.statusCode == 200) {
        // API 명세서 v3에 따른 새로운 응답 구조 처리
        final data = response.data;
        
        print('✅ 친구 요청 응답 성공');
        print('📋 응답 데이터: $data');
        
        return data;
      } else {
        throw Exception('친구 요청 응답 실패: ${response.data?['message'] ?? 'HTTP ${response.statusCode}'}');
      }
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] as String?;
        
        switch (statusCode) {
          case 400:
            throw Exception(message ?? '잘못된 요청입니다');
          case 401:
            throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
          case 403:
            throw Exception('이 친구 요청에 응답할 권한이 없습니다');
          case 404:
            throw Exception('친구 요청을 찾을 수 없습니다');
          default:
            throw Exception('HTTP $statusCode: ${message ?? '친구 요청 응답에 실패했습니다'}');
        }
      }
      throw Exception('친구 요청 응답 중 오류 발생: $e');
    }
  }

  // 친구 삭제
  static Future<void> deleteFriend(String friendshipId) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      final response = await FriendService._dio.delete(
        '/friends/$friendshipId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          print('✅ 친구 삭제 성공');
        } else {
          throw Exception(data['message'] ?? '친구 삭제에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 삭제에 실패했습니다');
      }
    } catch (e) {
      throw Exception('친구 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 친구의 수면 점수 조회
  static Future<FriendSleepData> getFriendSleepScores({
    required String friendId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('JWT 토큰이 없습니다.');
      }

      final queryParameters = <String, dynamic>{};
      if (startDate != null) queryParameters['startDate'] = startDate;
      if (endDate != null) queryParameters['endDate'] = endDate;

      final response = await FriendService._dio.get(
        '/sleep/friends/$friendId/scores',
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        print('✅ 친구 수면 점수 조회 성공: $responseData');

        // API 명세서 형식 또는 직접 형식 모두 처리
        if (responseData['success'] == true && responseData['data'] != null) {
          return FriendSleepData.fromJson(responseData['data']);
        } else {
          return FriendSleepData.fromJson(responseData);
        }
      } else {
        print('❌ 친구 수면 점수 조회 실패: Status ${response.statusCode}, Data: ${response.data}');
        throw Exception('친구 수면 점수 조회에 실패했습니다: ${response.data['message'] ?? '알 수 없는 오류'}');
      }
    } on DioException catch (e) {
      print('❌ DioException 발생: ${e.message}');
      if (e.response != null) {
        print('❌ 응답 상태: ${e.response?.statusCode}');
        print('❌ 응답 데이터: ${e.response?.data}');
        if (e.response?.statusCode == 401) {
          throw Exception('인증 실패: 유효하지 않은 토큰입니다.');
        } else if (e.response?.statusCode == 403) {
          throw Exception('권한 없음: 친구의 수면 데이터를 볼 권한이 없습니다.');
        } else if (e.response?.statusCode == 404) {
          throw Exception('친구 또는 수면 데이터를 찾을 수 없습니다.');
        } else if (e.response?.statusCode == 500) {
          throw Exception('서버 내부 오류: 친구 수면 점수 조회 중 서버 오류가 발생했습니다.');
        }
      }
      throw Exception('친구 수면 점수 조회 중 오류 발생: ${e.message}');
    } catch (e) {
      print('❌ 친구 수면 점수 조회 중 예상치 못한 오류: $e');
      throw Exception('친구 수면 점수 조회 중 오류 발생: $e');
    }
  }
}

enum FriendRequestAction {
  accept,
  reject;

  @override
  String toString() {
    return name.toUpperCase();
  }
}

extension FriendServiceExtension on FriendService {
  /// 사용자 검색 (친구 추가용) - 실제 API 호출
  Future<Map<String, dynamic>> searchUsers({
    required String query,
    int page = 0,
    int size = 10,
  }) async {
    print('🔍 사용자 검색 시작: query="$query", page=$page, size=$size');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      print('📡 API 요청 시작: ${FriendService._dio.options.baseUrl}/users/search');
      
      final response = await FriendService._dio.get(
        '/users/search',
        queryParameters: {
          'query': query,
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ API 응답 성공: Status ${response.statusCode}');
      print('📄 응답 데이터: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        print('🔍 서버 응답 data 구조: $data');
        
        // 서버 응답 구조에 맞게 수정: content 필드 사용
        final users = (data['content'] as List)
            .map((user) => UserSearchResult.fromJson(user))
            .toList();
        
        // 페이지네이션 정보 매핑
        final pagination = {
          'currentPage': data['number'] ?? 0,
          'totalPages': data['totalPages'] ?? 0,
          'totalElements': data['totalElements'] ?? 0,
          'size': data['size'] ?? 10,
          'hasNext': !(data['last'] ?? true),
          'hasPrevious': !(data['first'] ?? true),
        };
        
        return {
          'users': users,
          'pagination': pagination,
        };
      } else {
        throw Exception('사용자 검색 실패: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ 사용자 검색 에러 발생: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      
      if (e is DioException) {
        print('🔍 DioException 상세 정보:');
        print('- Status Code: ${e.response?.statusCode}');
        print('- Response Data: ${e.response?.data}');
        print('- Request URL: ${e.requestOptions.uri}');
        print('- Request Headers: ${e.requestOptions.headers}');
        print('- Request Query: ${e.requestOptions.queryParameters}');
        print('- Error Type: ${e.type}');
        print('- Error Message: ${e.message}');
        
        if (e.response?.statusCode == 401) {
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        } else if (e.response?.statusCode == 404) {
          // 검색 결과가 없는 경우
          print('📭 검색 결과 없음 - 빈 결과 반환');
          return {
            'users': <UserSearchResult>[],
            'pagination': {
              'currentPage': page,
              'totalPages': 0,
              'totalElements': 0,
              'size': size,
              'hasNext': false,
              'hasPrevious': false,
            },
          };
        } else if (e.response?.statusCode == 500) {
          final errorMessage = e.response?.data?['message'] ?? '서버 내부 오류가 발생했습니다';
          print('🚨 500 에러 상세: $errorMessage');
          print('💡 서버 문제로 인한 검색 실패 - 잠시 후 다시 시도해주세요');
          throw Exception('서버에 일시적인 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.');
        } else {
          print('🚨 기타 HTTP 에러: ${e.response?.statusCode}');
          throw Exception('HTTP ${e.response?.statusCode}: ${e.response?.data?['message'] ?? e.message}');
        }
      } else {
        print('🚨 일반 에러: $e');
        throw Exception('사용자 검색 중 오류 발생: $e');
      }
    }
  }

  /// 친구 요청 보내기 - 실제 API 호출
  Future<FriendRequest> sendFriendRequest({
    required String targetUserId,
    String? message,
  }) async {
    print('📤 친구 요청 보내기 시작');
    print('🎯 대상 사용자 ID: $targetUserId');
    print('💬 메시지: ${message ?? "메시지 없음"}');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      final requestBody = {
        'targetUserId': targetUserId,
        if (message != null && message.isNotEmpty) 'message': message,
      };
      
      print('📡 친구 요청 API 호출 시작');
      print('- URL: ${FriendService._dio.options.baseUrl}/friends/request');
      print('- Method: POST');
      print('- Request Body: $requestBody');
      print('- Headers: Authorization: Bearer ${token.substring(0, 20)}..., Content-Type: application/json');

      final response = await FriendService._dio.post(
        '/friends/request',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ 친구 요청 API 응답 성공: Status ${response.statusCode}');
      print('📄 응답 데이터: ${response.data}');

      if (response.statusCode == 201) {
        return FriendRequest.fromJson(response.data['data']);
      } else {
        throw Exception('친구 요청 실패: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ 친구 요청 에러 발생: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      
      if (e is DioException) {
        print('🔍 DioException 상세 정보:');
        print('- Status Code: ${e.response?.statusCode}');
        print('- Response Data: ${e.response?.data}');
        print('- Request URL: ${e.requestOptions.uri}');
        print('- Request Method: ${e.requestOptions.method}');
        print('- Request Headers: ${e.requestOptions.headers}');
        print('- Request Data: ${e.requestOptions.data}');
        print('- Error Type: ${e.type}');
        print('- Error Message: ${e.message}');
        
        if (e.response?.statusCode == 401) {
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        } else if (e.response?.statusCode == 404) {
          throw Exception('사용자를 찾을 수 없습니다.');
        } else if (e.response?.statusCode == 405) {
          print('🚨 405 Method Not Allowed 에러 상세:');
          print('- 요청한 HTTP 메서드가 허용되지 않습니다');
          print('- 서버에서 지원하는 메서드를 확인해주세요');
          print('- 가능한 원인:');
          print('  1. API 엔드포인트 경로가 잘못됨');
          print('  2. 서버에서 POST 메서드를 지원하지 않음');
          print('  3. API 버전이나 경로가 변경됨');
          final errorMessage = e.response?.data?['message'] ?? 'HTTP 메서드가 허용되지 않습니다';
          throw Exception('요청 방법 오류: $errorMessage');
        } else if (e.response?.statusCode == 409) {
          throw AlreadyRequestedException('이미 친구 요청을 보낸 사용자입니다.');
        } else if (e.response?.statusCode == 400) {
          final message = e.response?.data?['message'] as String?;
          if (message != null && message.contains('이미 친구 요청을 보냈거나 받은 상태입니다')) {
            throw AlreadyRequestedException(message);
          } else {
            throw Exception('HTTP ${e.response?.statusCode}: ${message ?? e.message}');
          }
        } else {
          print('🚨 기타 HTTP 에러: ${e.response?.statusCode}');
          throw Exception('HTTP ${e.response?.statusCode}: ${e.response?.data?['message'] ?? e.message}');
        }
      } else {
        print('🚨 일반 에러: $e');
        throw Exception('친구 요청 중 오류 발생: $e');
      }
    }
  }

  /// 친구 요청 목록 조회 - 실제 API 호출
  Future<Map<String, dynamic>> getFriendRequests({
    String type = 'received', // received, sent
    String status = 'pending', // all, pending, accepted, rejected
    int page = 0,
    int size = 20,
  }) async {
    print('📞 FriendService.getFriendRequests 호출');
    print('🎯 파라미터: type=$type, status=$status, page=$page, size=$size');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      print('📡 친구 요청 목록 API 호출 시작');
      print('- URL: https://neulbo1.com/api/v1/friends/requests');
      print('- Query: type=$type, status=$status, page=$page, size=$size');

      final response = await FriendService._dio.get(
        '/friends/requests',
        queryParameters: {
          'type': type,
          'status': status,
          'page': page,
          'size': size,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📄 친구 요청 목록 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // API 명세서에 따른 응답 구조 처리
        if (data['success'] == true) {
          print('✅ 친구 요청 목록 조회 성공');
          
          final responseData = data['data'];
          final requests = (responseData['friendRequests'] as List)
              .map((request) => FriendRequest.fromJson(request))
              .toList();
          
          return {
            'friendRequests': requests,
            'pagination': responseData['pagination'],
          };
        } else {
          // Spring Boot 페이지네이션 응답 구조 (content 기반)
          print('📋 Spring Boot 페이지네이션 응답 구조 감지');
          final requests = (data['content'] as List)
              .map((request) => FriendRequest.fromJson(request))
              .toList();
          
          return {
            'friendRequests': requests,
            'pagination': {
              'currentPage': data['number'],
              'totalPages': data['totalPages'],
              'totalElements': data['totalElements'],
              'size': data['size'],
              'hasNext': !data['last'],
              'hasPrevious': !data['first'],
            },
          };
        }
      } else {
        throw Exception('친구 요청 목록 조회 실패: ${response.data?['message'] ?? 'HTTP ${response.statusCode}'}');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        }
      }
      throw Exception('친구 요청 목록 조회 중 오류 발생: $e');
    }
  }

  /// 친구 요청 응답 (수락/거절) - API 명세서 준수
  Future<Map<String, dynamic>> respondToFriendRequestApi({
    required String requestId,
    required String action, // ACCEPT, REJECT
  }) async {
    print('📞 FriendService.respondToFriendRequestApi 호출');
    print('🎯 요청 ID: $requestId, 액션: $action');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      print('📡 친구 요청 응답 API 호출 시작');
      print('- URL: https://neulbo1.com/api/v1/friends/requests/$requestId');
      print('- Method: PUT');
      print('- Request Body: {action: $action}');

      final response = await FriendService._dio.put(
        '/friends/requests/$requestId',
        data: {'action': action},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📄 친구 요청 응답 결과: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        print('✅ 친구 요청 응답 성공');
        print('📋 응답 데이터: $data');
        
        // 새로운 API 명세서에 따른 직접 응답 구조 처리
        return {
          'friendRequestId': data['friendRequestId'],
          'status': data['status'],
          'processedAt': data['processedAt'],
          'friendship': data['friendship'], // 수락 시에만 존재, 거절 시 null
        };
      } else {
        throw Exception('친구 요청 응답 실패: ${response.data?['message'] ?? 'HTTP ${response.statusCode}'}');
      }
    } catch (e) {
      print('❌ 친구 요청 응답 에러: $e');
      
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] as String?;
        
        print('🚨 DioException 상세:');
        print('- Status Code: $statusCode');
        print('- Response Data: ${e.response?.data}');
        print('- Error Type: ${e.type}');
        print('- Error Message: ${e.message}');
        
        switch (statusCode) {
          case 400:
            // 잘못된 액션, 이미 처리됨, 권한 없음 등
            if (message?.contains('유효하지 않은 액션') == true) {
              throw Exception('유효하지 않은 액션입니다. ACCEPT 또는 REJECT만 가능합니다.');
            } else if (message?.contains('이미 처리된') == true) {
              throw Exception('이미 처리된 친구 요청입니다.');
            } else if (message?.contains('권한이 없습니다') == true) {
              throw Exception('이 친구 요청에 응답할 권한이 없습니다.');
            } else {
              throw Exception('잘못된 요청입니다: ${message ?? '알 수 없는 오류'}');
            }
          case 401:
            throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
          case 404:
            throw Exception('친구 요청을 찾을 수 없습니다.');
          default:
            throw Exception('HTTP $statusCode: ${message ?? '친구 요청 응답에 실패했습니다'}');
        }
      }
      throw Exception('친구 요청 응답 중 오류 발생: $e');
    }
  }

  /// 친구 삭제 - 실제 API 호출
  Future<void> deleteFriend(String friendshipId) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다');
      }

      final response = await FriendService._dio.delete(
        '/friends/$friendshipId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('친구 삭제 실패: ${response.data['message']}');
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        } else if (e.response?.statusCode == 404) {
          throw Exception('친구 관계를 찾을 수 없습니다.');
        } else if (e.response?.statusCode == 403) {
          throw Exception('친구를 삭제할 권한이 없습니다.');
        }
      }
      throw Exception('친구 삭제 중 오류 발생: $e');
    }
  }

  /// 친구의 수면 점수 조회
  static Future<FriendSleepData> getFriendSleepScores({
    required String friendId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      print('📞 FriendService.getFriendSleepScores 호출');
      print('🎯 친구 ID: $friendId');
      print('📅 기간: ${startDate ?? '7일 전'} ~ ${endDate ?? '오늘'}');

      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('JWT 토큰을 찾을 수 없습니다');
      }
      print('🔑 JWT 토큰 확인: 토큰 있음');

      // 쿼리 파라미터 구성
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await FriendService._dio.get(
        '/sleep/friends/$friendId/scores',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📄 친구 수면 데이터 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // API 명세서에 따른 응답 구조 처리
        if (data['success'] == true) {
          print('✅ 친구 수면 데이터 조회 성공 (API 명세서 형식)');
          try {
            print('🔍 파싱할 데이터: ${data['data']}');
            return FriendSleepData.fromJson(data['data']);
          } catch (e) {
            print('❌ 친구 수면 점수 조회 중 예상치 못한 오류: $e');
            print('❌ 파싱 실패 데이터: ${data['data']}');
            throw Exception('친구 수면 점수 조회 중 오류 발생: $e');
          }
        } else if (data['friendId'] != null) {
          // 직접 데이터 형식
          print('✅ 친구 수면 데이터 조회 성공 (직접 형식)');
          try {
            print('🔍 파싱할 데이터: $data');
            return FriendSleepData.fromJson(data);
          } catch (e) {
            print('❌ 친구 수면 점수 조회 중 예상치 못한 오류: $e');
            print('❌ 파싱 실패 데이터: $data');
            throw Exception('친구 수면 점수 조회 중 오류 발생: $e');
          }
        } else {
          throw Exception(data['message'] ?? '친구 수면 데이터 조회에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 수면 데이터 조회에 실패했습니다');
      }
    } on DioException catch (e) {
      print('❌ Dio 에러 발생: ${e.type}');
      print('❌ 에러 메시지: ${e.message}');
      print('❌ 응답 데이터: ${e.response?.data}');
      
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;
        
        switch (statusCode) {
          case 401:
            throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
          case 403:
            throw Exception('친구의 수면 데이터를 볼 권한이 없습니다.');
          case 404:
            throw Exception('친구를 찾을 수 없거나 수면 데이터가 없습니다.');
          case 500:
            throw Exception('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
          default:
            final message = responseData?['message'] ?? '친구 수면 데이터 조회에 실패했습니다';
            throw Exception('HTTP $statusCode: $message');
        }
      }
      throw Exception('네트워크 오류가 발생했습니다: ${e.message}');
    } catch (e) {
      print('❌ 친구 수면 데이터 조회 오류: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      throw Exception('친구 수면 데이터 조회 중 오류가 발생했습니다: $e');
    }
  }
}
