import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/friend.dart';
import 'api_service.dart';
import 'oauth_service.dart';

class FriendService {
  static const String baseUrl = 'https://neulbo1.com/api/v1';
  final ApiService _apiService = ApiService();

  // 친구 목록 조회
  Future<Map<String, dynamic>> getFriends({
    String? search,
    int page = 0,
    int size = 20,
    String sort = 'name',
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$baseUrl/friends').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final friends = (data['data']['friends'] as List)
              .map((friendJson) => Friend.fromJson(friendJson))
              .toList();

          return {
            'friends': friends,
            'pagination': data['data']['pagination'],
          };
        } else {
          throw Exception(data['message'] ?? '친구 목록 조회에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 목록 조회에 실패했습니다');
      }
    } catch (e) {
      throw Exception('친구 목록 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 요청 보내기
  Future<FriendRequest> sendFriendRequest({
    required String targetUserId,
    String? message,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final requestBody = <String, dynamic>{
        'targetUserId': targetUserId,
      };

      if (message != null && message.isNotEmpty) {
        requestBody['message'] = message;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return FriendRequest.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? '친구 요청 전송에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 요청 전송에 실패했습니다');
      }
    } catch (e) {
      throw Exception('친구 요청 전송 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 요청 목록 조회
  Future<Map<String, dynamic>> getFriendRequests({
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
        if (data['success'] == true) {
          final friendRequests = (data['data']['friendRequests'] as List)
              .map((requestJson) => FriendRequest.fromJson(requestJson))
              .toList();

          return {
            'friendRequests': friendRequests,
            'pagination': data['data']['pagination'],
          };
        } else {
          throw Exception(data['message'] ?? '친구 요청 목록 조회에 실패했습니다');
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
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '친구 요청 응답에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 요청 응답에 실패했습니다');
      }
    } catch (e) {
      throw Exception('친구 요청 응답 중 오류가 발생했습니다: $e');
    }
  }

  // 친구 삭제
  Future<void> deleteFriend(String friendshipId) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/friends/$friendshipId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message'] ?? '친구 삭제에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 친구 삭제에 실패했습니다');
      }
    } catch (e) {
      throw Exception('친구 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 사용자 검색 (친구 추가용)
  Future<Map<String, dynamic>> searchUsers({
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
}

enum FriendRequestAction {
  accept,
  reject;

  @override
  String toString() {
    return name.toUpperCase();
  }
}
