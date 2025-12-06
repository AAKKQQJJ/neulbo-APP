import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import 'package:intl/intl.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final bool autoFocusComment;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.autoFocusComment = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    print('📋 PostDetailScreen: 게시물 로딩 시작');
    print('🎯 게시물 ID: ${widget.postId}');
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final post = await _postService.getPost(widget.postId);
      
      setState(() {
        _post = post;
        _isLoading = false;
      });

      print('✅ 게시물 로딩 완료: ${post.title}');
      
      // 댓글 자동 포커스가 요청된 경우
      if (widget.autoFocusComment && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _commentFocusNode.requestFocus();
        });
      }
    } catch (e) {
      print('❌ 게시물 로딩 에러: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;

    print('❤️ PostDetailScreen: 좋아요 토글 시작');
    print('🎯 게시물 ID: ${_post!.postId}');
    print('💖 현재 좋아요 상태: ${_post!.isLiked}, 카운트: ${_post!.likeCount}');


    try {
      final result = await _postService.toggleLike(_post!.postId);

      print('✅ 좋아요 토글 성공: $result');

      // 서버 응답 데이터
      final serverIsLiked = result['isLiked'] as bool;
      final serverLikeCount = result['likeCount'] as int;

      print('📋 서버 데이터: isLiked=$serverIsLiked, likeCount=$serverLikeCount');

      // 서버 응답을 절대적으로 신뢰하여 업데이트
      setState(() {
        _post = _post!.copyWith(
          isLiked: serverIsLiked,
          likeCount: serverLikeCount,
        );
      });
      print('🎯 서버 데이터로 최종 업데이트 완료');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverIsLiked ? '좋아요를 눌렀습니다' : '좋아요를 취소했습니다',
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF6C5CE7),
          ),
        );
      }
    } catch (e) {
      print('❌ 좋아요 토글 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('좋아요 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_post == null) return;
    
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    print('💬 PostDetailScreen: 댓글 작성 시도');
    print('🎯 게시물 ID: ${_post!.postId}, 내용: $content');
    
    try {
      final newComment = await _postService.createComment(
        postId: _post!.postId,
        content: content,
      );

      print('✅ 댓글 작성 성공: ${newComment.commentId}');

      // UI 업데이트
      setState(() {
        final updatedComments = List<Comment>.from(_post!.comments)..add(newComment);
        _post = _post!.copyWith(
          commentCount: _post!.commentCount + 1,
          comments: updatedComments,
        );
      });

      // 댓글 입력창 초기화
      _commentController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('댓글이 성공적으로 작성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ 댓글 작성 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 작성 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'sleep_tip':
        return '수면 쿨팁';
      case 'question':
        return '잠이 안와요';
      case 'experience':
        return '일상';
      case 'challenge':
        return '친구';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF2D1B69),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D1B69),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            '게시글',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _post != null
                    ? Column(
                        children: [
                          Expanded(
                            child: _buildPostContent(),
                          ),
                          // 댓글 입력창을 키보드 바로 위에 고정
                          _buildCommentInput(),
                        ],
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white70,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '게시글을 불러올 수 없습니다',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    if (_post == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게시글 헤더
          _buildPostHeader(),
          const SizedBox(height: 16),
          
          // 게시글 제목
          Text(
            _post!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 게시글 내용
          Text(
            _post!.content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // 태그
          if (_post!.tags.isNotEmpty) _buildTags(),
          
          const SizedBox(height: 16),
          
          // 좋아요, 댓글 버튼
          _buildActionButtons(),
          
          const SizedBox(height: 24),
          
          // 댓글 목록
          _buildCommentsList(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Row(
      children: [
        // 작성자 프로필 이미지
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFB3A8EA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: _post!.authorProfileImage != null && _post!.authorProfileImage!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    _post!.authorProfileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.person, color: Colors.white, size: 20);
                    },
                  ),
                )
              : const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        
        // 작성자 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _post!.authorNickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getCategoryDisplayName(_post!.category),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatDateTime(_post!.createdAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        // 조회수
        Row(
          children: [
            Icon(
              Icons.visibility,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${_post!.viewCount}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _post!.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 좋아요 버튼
        GestureDetector(
          onTap: _toggleLike,
          child: Row(
            children: [
              Icon(
                _post!.isLiked ? Icons.favorite : Icons.favorite_border,
                color: _post!.isLiked ? Colors.red : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${_post!.likeCount}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 24),
        
        // 댓글 버튼
        GestureDetector(
          onTap: () {
            _commentFocusNode.requestFocus();
          },
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${_post!.commentCount}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // 공유 버튼
        GestureDetector(
          onTap: () {
            // TODO: 공유 기능 구현
          },
          child: Icon(
            Icons.share_outlined,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    if (_post!.comments.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.white.withValues(alpha: 0.3),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '아직 댓글이 없습니다.\n첫 번째 댓글을 작성해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 ${_post!.commentCount}개',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        ...(_post!.comments.map((comment) => _buildCommentItem(comment)).toList()),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 댓글 작성자 프로필
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6B46C1),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: comment.authorProfileImage != null && comment.authorProfileImage!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      comment.authorProfileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person, color: Colors.white, size: 16);
                      },
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          
          // 댓글 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorNickname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // TODO: 댓글 좋아요 기능 구현
                      },
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: comment.isLiked ? Colors.red : Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likeCount}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B69),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _submitComment();
                }
              },
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              final content = _commentController.text.trim();
              if (content.isNotEmpty) {
                _submitComment();
              }
            },
            icon: const Icon(
              Icons.send,
              color: Color(0xFFB3A8EA),
            ),
          ),
        ],
      ),
    );
  }
}