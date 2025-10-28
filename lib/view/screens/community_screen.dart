import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../const/design_constants.dart';
import '../../models/friend.dart';
import '../../models/post.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import 'create_post_screen.dart';
import 'friend_management_screen.dart';
import 'post_detail_screen.dart';
import 'user_sleep_data_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostService _postService = PostService();
  final FriendService _friendService = FriendService();

  List<Post> _posts = [];
  List<Friend> _friends = [];
  bool _isLoading = true;
  String _selectedCategory = 'friend';

  final List<Map<String, String>> _categories = [
    {'key': 'friend', 'name': '친구'},
    {'key': 'sleep_trouble', 'name': '잠이 안 와요🥱'},
    {'key': 'sleep_tip', 'name': '수면 쿨팁🛏️💤'},
    {'key': 'daily', 'name': '일상🌈'},
  ];

  // 더미 친구 데이터 (실제로는 API에서 가져옴)
  final List<Map<String, String>> _dummyFriends = [
    {'name': '나산하', 'image': ''},
    {'name': '박지현', 'image': ''},
    {'name': '김선우', 'image': ''},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _loadPosts();
      await _loadFriends();
    } catch (e) {
      // 데이터 로딩 오류: $e
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPosts() async {
    try {
      final result = await _postService.getPosts(
        category: _selectedCategory,
        size: 10,
      );
      setState(() {
        _posts = result['posts'] as List<Post>;
      });
    } catch (e) {
      // 게시물 로딩 오류: $e
      // 더미 데이터로 대체
      setState(() {
        _posts = _generateDummyPosts();
      });
    }
  }

  Future<void> _loadFriends() async {
    try {
      final result = await _friendService.getFriends(size: 10);
      setState(() {
        _friends = result['friends'] as List<Friend>;
      });
    } catch (e) {
      // 친구 목록 로딩 오류: $e
    }
  }

  Future<String?> _getUserProfileImage() async {
    try {
      // UserService에서 현재 로그인된 사용자의 프로필 이미지 URL 가져오기
      final profileImageUrl = UserService.getUserProfileImageUrl();
      return profileImageUrl.isNotEmpty ? profileImageUrl : null;
    } catch (e) {
      return null;
    }
  }

  String _getUserNickname() {
    try {
      // UserService에서 현재 로그인된 사용자의 닉네임 가져오기
      final nickname = UserService.getUserNickname();
      return nickname.isNotEmpty ? nickname : '내 쿨쿨';
    } catch (e) {
      return '내 쿨쿨';
    }
  }

  List<Post> _generateDummyPosts() {
    return List.generate(5, (index) {
      return Post(
        postId: 'post_$index',
        title: '게시글 제목 ${index + 1}',
        content: '이것은 샘플 게시글 내용입니다. 실제 데이터는 API에서 가져옵니다.',
        category: _selectedCategory,
        tags: ['태그1', '태그2'],
        isPublic: true,
        authorId: 'user_$index',
        authorNickname: '사용자${index + 1}',
        authorProfileImage: '',
        createdAt: DateTime.now().subtract(Duration(hours: index)),
        updatedAt: DateTime.now().subtract(Duration(hours: index)),
        viewCount: 10 + index * 5,
        likeCount: index * 2,
        commentCount: index,
        isLiked: index % 2 == 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 반응형 배경 이미지
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(DesignConstants.communityImagePath),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    onError: (exception, stackTrace) {
                      // 커뮤니티 배경 이미지 로드 실패: $exception
                    },
                  ),
                  color: const Color(0xFF2D1B69),
                ),
              ),
            ),
            // 콘텐츠
            SafeArea(
          child: Column(
                children: [
                  // 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
            children: [
                        const Text(
                  '커뮤니티',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'malang',
                  ),
                ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const FriendManagementScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.people,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 카테고리 탭
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(
                          color: Colors.white,
                          width: 2,
                        ),
                        insets: EdgeInsets.zero,
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      onTap: (index) {
                        setState(() {
                          _selectedCategory = _categories[index]['key']!;
                        });
                        _loadPosts();
                      },
                      tabs: _categories
                          .map((category) => Tab(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(category['name']!),
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 내 쿨쿨 (친구 목록)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _dummyFriends.length + 1, // +1 for user profile
                        separatorBuilder: (context, index) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // 첫 번째는 사용자 프로필 (내 쿨쿨)
                            return Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFB3A8EA), // 연보라색
                                        Color(0xFFD0FAFF), // 연청록색
                                        Color(0xFFB3A8EA), // 연보라색
                                      ],
                                      stops: [0.0, 0.49, 0.95],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF6B46C1),
                                    ),
                                    child: ClipOval(
                                      child: FutureBuilder<String?>(
                                        future: _getUserProfileImage(),
                                        builder: (context, snapshot) {
                                        final profileImageUrl = snapshot.data;

                                        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                                          return Image.network(
                                            profileImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF6B46C1),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 35,
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          return Container(
                                            color: const Color(0xFF6B46C1),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 35,
                                            ),
                                          );
                                        }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getUserNickname(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          }

                          // 나머지는 친구들
                          final friend = _dummyFriends[index - 1];
                          return GestureDetector(
                            onTap: () => _showUserSleepData(friend['name']!),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFB3A8EA), // 연보라색
                                        Color(0xFFD0FAFF), // 연청록색
                                        Color(0xFFB3A8EA), // 연보라색
                                      ],
                                      stops: [0.0, 0.49, 0.95],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF6B46C1),
                                    ),
                                    child: ClipOval(
                                      child: friend['image']!.isEmpty
                                        ? Container(
                                            color: const Color(0xFF6B46C1),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 35,
                                            ),
                                          )
                                        : Image.network(
                                            friend['image']!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF6B46C1),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 35,
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  friend['name']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 게시물 목록
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _posts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final post = _posts[index];
                              return _buildPostCard(post);
                            },
                ),
              ),
            ],
          ),
        ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreatePostDialog(),
          backgroundColor: const Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 정보
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6B46C1),
                  backgroundImage:
                      (post.authorProfileImage != null && post.authorProfileImage!.isNotEmpty)
                          ? NetworkImage(post.authorProfileImage!)
                          : null,
                  child: (post.authorProfileImage == null || post.authorProfileImage!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorNickname,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D1B69),
                        ),
                      ),
                      Text(
                        _formatDateTime(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 게시물 내용
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D1B69),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              post.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // 좋아요, 댓글 버튼
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Row(
                    children: [
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: post.isLiked ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showComments(post),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
    );
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
    } else {
      return '${difference.inDays}일 전';
    }
  }

  void _showUserSleepData(String userName) {
    // 실제로는 사용자 ID를 받아와야 하지만, 더미 데이터로 대체
    final userId = 'user_${userName.hashCode}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserSleepDataScreen(
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }

  void _toggleLike(Post post) async {
    try {
      await _postService.toggleLike(post.postId);
      setState(() {
        final index = _posts.indexWhere((p) => p.postId == post.postId);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
            isLiked: !_posts[index].isLiked,
            likeCount:
                _posts[index].isLiked ? _posts[index].likeCount - 1 : _posts[index].likeCount + 1,
          );
        }
      });
    } catch (e) {
      // 좋아요 처리 오류: $e
    }
  }

  void _showComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '댓글',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('댓글 기능 구현 예정'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
      ),
    )
        .then((result) {
      if (result == true) {
        _loadPosts(); // 게시물 작성 후 목록 새로고침
      }
    });
  }

  void _navigateToPostDetail(Post post) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: post.postId),
      ),
    )
        .then((result) {
      if (result == true) {
        _loadPosts(); // 게시물 수정/삭제 후 목록 새로고침
      }
    });
  }
}
