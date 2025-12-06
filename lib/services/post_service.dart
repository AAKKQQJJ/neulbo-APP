import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import 'api_service.dart';
import 'oauth_service.dart';

class PostService {
  static const String baseUrl = 'https://neulbo1.com/api/v1';
  final ApiService _apiService = ApiService();

  // 특정 게시물 상세 조회
  Future<Post> getPost(String postId) async {
    print('📋 PostService: 게시물 상세 조회 시작');
    print('🎯 게시물 ID: $postId');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음" : "토큰 없음"}');
      
      final uri = Uri.parse('$baseUrl/posts/$postId');
      print('📡 API 요청 시작: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📄 게시물 상세 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // API 명세서에 따른 응답 구조 처리
        if (data['success'] == true) {
          print('✅ 게시물 상세 조회 성공 (API 명세서 형식)');
          return Post.fromJson(data['data']);
        } else if (data['postId'] != null) {
          // 직접 데이터 형식
          print('✅ 게시물 상세 조회 성공 (직접 형식)');
          return Post.fromJson(data);
        } else {
          throw Exception(data['message'] ?? '게시물 조회에 실패했습니다');
        }
      } else if (response.statusCode == 404) {
        throw Exception('게시물을 찾을 수 없습니다');
      } else {
        throw Exception('HTTP ${response.statusCode}: 게시물 조회에 실패했습니다');
      }
    } catch (e) {
      print('❌ PostService 에러 발생: $e');
      throw Exception('게시물 조회 중 오류가 발생했습니다: $e');
    }
  }

  // 게시물 목록 조회
  Future<Map<String, dynamic>> getPosts({
    int page = 0,
    int size = 20,
    String category = 'all',
    String sort = 'latest',
    String? search,
  }) async {
    print('📋 PostService: 게시물 목록 조회 시작');
    print('🎯 파라미터: page=$page, size=$size, category=$category, sort=$sort');
    
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
        'sort': sort,
      };

      // 카테고리가 'all'이 아닌 경우에만 추가
      if (category != 'all') {
        queryParams['category'] = category;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: queryParams);
      final token = await OAuthService.getJwtToken();

      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음" : "토큰 없음"}');
      print('📡 API 요청 시작: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📄 게시물 목록 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 두 가지 응답 구조 처리
        if (data['success'] == true) {
          // API 명세서 형식: {success: true, data: {posts: [...], pagination: {...}}}
          final postsData = data['data']['posts'] as List;
          print('✅ 게시물 파싱 시작 (API 명세서 형식): ${postsData.length}개');
          
          final posts = postsData
              .map((postJson) => Post.fromJson(postJson))
              .toList();

          print('✅ 게시물 목록 조회 성공: ${posts.length}개');

          return {
            'posts': posts,
            'pagination': data['data']['pagination'],
          };
        } else if (data['posts'] != null) {
          // 직접 응답 형식: {posts: [...], pagination: {...}}
          final postsData = data['posts'] as List;
          print('✅ 게시물 파싱 시작 (직접 응답 형식): ${postsData.length}개');
          
          final posts = postsData
              .map((postJson) => Post.fromJson(postJson))
              .toList();

          print('✅ 게시물 목록 조회 성공: ${posts.length}개');

          return {
            'posts': posts,
            'pagination': data['pagination'],
          };
        } else {
          print('❌ 서버에서 실패 응답: ${data['message']}');
          throw Exception(data['message'] ?? '게시물 조회에 실패했습니다');
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        print('❌ 에러 응답: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: 게시물 조회에 실패했습니다');
      }
    } catch (e) {
      print('❌ PostService 에러 발생: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      throw Exception('게시물 조회 중 오류가 발생했습니다: $e');
    }
  }


  // 새 게시물 작성
  Future<Post> createPost({
    required String title,
    required String content,
    String category = 'experience',
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    print('📝 PostService: 게시물 작성 시작');
    print('🎯 제목: $title');
    print('📋 카테고리: $category');
    print('🏷️ 태그: $tags');
    print('🔓 공개: $isPublic');
    
    try {
      final token = await OAuthService.getJwtToken();
      print('🔑 JWT 토큰 확인: ${token != null ? "토큰 있음 (${token.substring(0, 20)}...)" : "토큰 없음"}');
      
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

      print('📡 게시물 작성 API 호출 시작');
      print('- URL: $baseUrl/posts');
      print('- Method: POST');
      print('- Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      print('📄 게시물 작성 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // API 명세서 표준 응답 구조 확인
        if (data['success'] == true) {
          print('✅ 게시물 작성 성공! (표준 API 응답)');
          return Post.fromJson(data['data']);
        } 
        // 직접 Post 객체 응답 구조 처리
        else if (data.containsKey('postId')) {
          print('✅ 게시물 작성 성공! (직접 Post 객체 응답)');
          return Post.fromJson(data);
        } 
        // 기타 실패 응답
        else {
          print('❌ 서버에서 실패 응답: ${data['message']}');
          throw Exception(data['message'] ?? '게시물 작성에 실패했습니다');
        }
      } else {
        final errorData = json.decode(response.body);
        final message = errorData['message'] ?? 'HTTP ${response.statusCode}: 게시물 작성에 실패했습니다';
        print('🚨 HTTP 에러: $message');
        
        // API 명세서에 따른 상세 에러 처리
        if (response.statusCode == 400) {
          final fieldErrors = errorData['data']?['fieldErrors'] as List?;
          if (fieldErrors != null && fieldErrors.isNotEmpty) {
            final firstError = fieldErrors.first;
            throw Exception('${firstError['reason']} (${firstError['field']})');
          }
        }
        
        throw Exception(message);
      }
    } catch (e) {
      print('❌ 게시물 작성 에러: $e');
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
    print('❤️ PostService: 좋아요 토글 시작');
    print('🎯 게시물 ID: $postId');
    
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        print('❌ JWT 토큰이 없습니다');
        throw Exception('로그인이 필요합니다');
      }

      print('🔑 JWT 토큰 확인: 토큰 있음');
      print('📡 좋아요 API 호출 시작');
      print('- URL: $baseUrl/posts/$postId/like');
      print('- Method: POST');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('📄 좋아요 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        print('🔍 응답 데이터 분석:');
        print('  - success: ${data['success']}');
        print('  - data: ${data['data']}');
        print('  - postId: ${data['postId']}');
        print('  - isLiked: ${data['isLiked']}');
        print('  - likeCount: ${data['likeCount']}');
        print('  - message: ${data['message']}');
        
        // API 명세서 형태: {success: true, data: {...}}
        if (data['success'] == true && data['data'] != null) {
          print('✅ 좋아요 처리 성공! (API 명세서 형태)');
          final responseData = data['data'] as Map<String, dynamic>;
          print('📋 최종 응답 데이터: $responseData');
          print('  - isLiked: ${responseData['isLiked']}');
          print('  - likeCount: ${responseData['likeCount']}');
          return responseData;
        }
        // 직접 응답 형태: {postId: ..., isLiked: ..., likeCount: ...}
        else if (data['postId'] != null && data.containsKey('isLiked') && data.containsKey('likeCount')) {
          print('✅ 좋아요 처리 성공! (직접 응답 형태)');
          print('📋 최종 응답 데이터: $data');
          print('  - isLiked: ${data['isLiked']}');
          print('  - likeCount: ${data['likeCount']}');
          return data;
        }
        // 에러 응답
        else {
          print('❌ 서버에서 실패 응답: ${data['message'] ?? '알 수 없는 에러'}');
          print('❌ 전체 응답 구조: $data');
          throw Exception(data['message'] ?? '좋아요 처리에 실패했습니다');
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        print('❌ 에러 응답: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: 좋아요 처리에 실패했습니다');
      }
    } catch (e) {
      print('❌ 좋아요 처리 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      throw Exception('좋아요 처리 중 오류가 발생했습니다: $e');
    }
  }

  // 댓글 작성
  Future<Comment> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    print('💬 PostService: 댓글 작성 시작');
    print('🎯 게시물 ID: $postId');
    print('📝 댓글 내용: $content');
    print('👥 부모 댓글 ID: $parentCommentId');
    
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      print('🔑 JWT 토큰 확인: 토큰 있음');

      final requestBody = <String, dynamic>{
        'content': content,
      };

      if (parentCommentId != null) {
        requestBody['parentCommentId'] = parentCommentId;
      }

      print('📡 댓글 작성 API 호출 시작');
      print('- URL: $baseUrl/posts/$postId/comments');
      print('- Method: POST');
      print('- Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      print('📄 댓글 작성 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ 댓글 작성 성공!');
          return Comment.fromJson(data['data']);
        } else {
          print('❌ 서버에서 실패 응답: ${data['message']}');
          throw Exception(data['message'] ?? '댓글 작성에 실패했습니다');
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        print('❌ 에러 응답: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: 댓글 작성에 실패했습니다');
      }
    } catch (e) {
      print('❌ 댓글 작성 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      throw Exception('댓글 작성 중 오류가 발생했습니다: $e');
    }
  }

  // 댓글 좋아요/취소
  Future<Map<String, dynamic>> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    print('❤️ PostService: 댓글 좋아요 토글 시작');
    print('🎯 게시물 ID: $postId');
    print('💬 댓글 ID: $commentId');
    
    try {
      final token = await OAuthService.getJwtToken();
      if (token == null) {
        throw Exception('로그인이 필요합니다');
      }

      print('🔑 JWT 토큰 확인: 토큰 있음');
      print('📡 댓글 좋아요 API 호출 시작');
      print('- URL: $baseUrl/posts/$postId/comments/$commentId/like');
      print('- Method: POST');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('📄 댓글 좋아요 응답: Status ${response.statusCode}');
      print('📄 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ 댓글 좋아요 처리 성공!');
          return data['data'];
        } else {
          print('❌ 서버에서 실패 응답: ${data['message']}');
          throw Exception(data['message'] ?? '댓글 좋아요 처리에 실패했습니다');
        }
      } else {
        print('❌ HTTP 에러: ${response.statusCode}');
        print('❌ 에러 응답: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: 댓글 좋아요 처리에 실패했습니다');
      }
    } catch (e) {
      print('❌ 댓글 좋아요 처리 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      throw Exception('댓글 좋아요 처리 중 오류가 발생했습니다: $e');
    }
  }
}
