import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import 'api_service.dart';
import 'oauth_service.dart';

class PostService {
  static const String baseUrl = 'https://neulbo1.com/api/v1';
  final ApiService _apiService = ApiService();

  // 게시물 목록 조회
  Future<Map<String, dynamic>> getPosts({
    int page = 0,
    int size = 20,
    String category = 'all',
    String sort = 'latest',
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
        'category': category,
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams);
      final token = await OAuthService.getJwtToken();

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final posts = (data['data']['posts'] as List)
              .map((postJson) => Post.fromJson(postJson))
              .toList();

          return {
            'posts': posts,
            'pagination': data['data']['pagination'],
          };
        } else {
          throw Exception(data['message'] ?? '게시물 조회에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 게시물 조회에 실패했습니다');
      }
    } catch (e) {
      throw Exception('게시물 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 특정 게시물 상세 조회
  Future<Post> getPost(String postId) async {
    try {
      final token = await OAuthService.getJwtToken();
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Post.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? '게시물 조회에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 게시물 조회에 실패했습니다');
      }
    } catch (e) {
      throw Exception('게시물 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 새 게시물 작성
  Future<Post> createPost({
    required String title,
    required String content,
    String category = 'daily',
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final requestBody = {
        'title': title,
        'content': content,
        'category': category,
        'tags': tags,
        'isPublic': isPublic,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Post.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? '게시물 작성에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 게시물 작성에 실패했습니다');
      }
    } catch (e) {
      throw Exception('게시물 작성 중 오류가 발생했습니다: $e');
    }
  }

  // 게시물 수정
  Future<Post> updatePost({
    required String postId,
    required String title,
    required String content,
    String? category,
    List<String>? tags,
    bool? isPublic,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final requestBody = <String, dynamic>{
        'title': title,
        'content': content,
      };

      if (category != null) requestBody['category'] = category;
      if (tags != null) requestBody['tags'] = tags;
      if (isPublic != null) requestBody['isPublic'] = isPublic;

      final response = await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Post.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? '게시물 수정에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 게시물 수정에 실패했습니다');
      }
    } catch (e) {
      throw Exception('게시물 수정 중 오류가 발생했습니다: $e');
    }
  }

  // 게시물 삭제
  Future<void> deletePost(String postId) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message'] ?? '게시물 삭제에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 게시물 삭제에 실패했습니다');
      }
    } catch (e) {
      throw Exception('게시물 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 게시물 좋아요/취소
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '좋아요 처리에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 좋아요 처리에 실패했습니다');
      }
    } catch (e) {
      throw Exception('좋아요 처리 중 오류가 발생했습니다: $e');
    }
  }

  // 댓글 작성
  Future<Comment> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      final requestBody = <String, dynamic>{
        'content': content,
      };

      if (parentCommentId != null) {
        requestBody['parentCommentId'] = parentCommentId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Comment.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? '댓글 작성에 실패했습니다');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: 댓글 작성에 실패했습니다');
      }
    } catch (e) {
      throw Exception('댓글 작성 중 오류가 발생했습니다: $e');
    }
  }
}
