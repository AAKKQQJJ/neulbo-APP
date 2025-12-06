import 'dart:math' as math;

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
import 'friend_sleep_detail_screen.dart';
import 'post_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostService _postService = PostService();

  List<Post> _posts = [];
  List<Friend> _friends = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'name': '전체'},
    {'key': 'sleep_tip', 'name': '수면 쿨팁🛏️💤'},
    {'key': 'question', 'name': '잠이 안 와요🥱'},
    {'key': 'experience', 'name': '일상🌈'},
    {'key': 'challenge', 'name': '챌린지🏆'},
  ];

  // 더미 친구 데이터 (실제로는 API에서 가져옴)

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
    print('📋 PostService: 게시물 목록 조회 시작');
    print('🎯 카테고리: $_selectedCategory');

    try {
      final result = await _postService.getPosts(
        category: _selectedCategory,
        size: 20,
        sort: 'latest',
      );

      final posts = result['posts'] as List<Post>;
      print('✅ 게시물 목록 조회 성공: ${posts.length}개');

      // 각 게시물의 초기 좋아요 상태 로그
      for (int i = 0; i < posts.length; i++) {
        final post = posts[i];
        print(
            '📋 게시물 $i: ${post.postId.substring(0, 8)}... - isLiked: ${post.isLiked}, likeCount: ${post.likeCount}');
      }

      if (mounted) {
        setState(() {
          _posts = posts;
        });
      }
    } catch (e) {
      print('❌ 게시물 로딩 오류: $e');

      if (mounted) {
        // 에러 발생 시 빈 목록으로 설정
        setState(() {
          _posts = [];
        });

        // 사용자에게 에러 알림
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('게시물을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '다시 시도',
              textColor: Colors.white,
              onPressed: () => _loadPosts(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadFriends() async {
    try {
      print('📞 CommunityScreen: 친구 목록 로딩 시작');
      final result = await FriendService.getFriends(size: 10);

      if (mounted) {
        setState(() {
          _friends = result['friends'] as List<Friend>;
        });
        print('✅ 친구 목록 로딩 성공: ${_friends.length}명');
      }
    } catch (e) {
      print('❌ 친구 목록 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _friends = [];
        });
      }
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

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 친구 목록은 항상 표시
          _buildFriendsSection(),
          const SizedBox(height: 24),

          // 빈 상태 메시지
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '아직 게시물이 없어요',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '첫 번째 게시물을 작성해보세요!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _navigateToCreatePost(),
                  icon: const Icon(Icons.edit),
                  label: const Text('게시물 작성하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 100,
        child: _friends.isEmpty
            ? _buildEmptyFriendsSection()
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _friends.length + 1, // +1 for user profile
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

                  // 나머지는 실제 친구들
                  final friend = _friends[index - 1];
                  return GestureDetector(
                    onTap: () => _showFriendSleepData(friend.friend.userId, friend.friend.nickname),
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
                              child: (friend.friend.profileImage == null ||
                                      friend.friend.profileImage!.isEmpty)
                                  ? Container(
                                      color: const Color(0xFF6B46C1),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 35,
                                      ),
                                    )
                                  : Image.network(
                                      friend.friend.profileImage!,
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
                          friend.friend.nickname,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyFriendsSection() {
    return Row(
      children: [
        // 사용자 프로필 (내 쿨쿨)
        Column(
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
        ),

        const SizedBox(width: 24),

        // 친구 추가 안내
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_outlined,
                color: Colors.white.withValues(alpha: 0.6),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                '친구를 추가해보세요!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '친구 관리에서 새로운 친구를 찾을 수 있어요',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                          // 친구 관리 버튼
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

                          const SizedBox(width: 8),

                          // 게시물 작성 버튼
                          IconButton(
                            onPressed: () => _navigateToCreatePost(),
                            icon: const Icon(
                              Icons.edit,
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

                    // 게시물 목록 (친구 목록 포함)
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : _posts.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
                                  itemCount: _posts.length + 1, // +1 for friends section
                                  separatorBuilder: (context, index) {
                                    if (index == 0) {
                                      // 친구 섹션과 첫 번째 게시글 사이
                                      return Column(
                                        children: [
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 0.5,
                                            color: Colors.white.withValues(alpha: 0.2),
                                            margin: const EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      );
                                    } else {
                                      // 게시글들 사이
                                      return Column(
                                        children: [
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 0.5,
                                            color: Colors.white.withValues(alpha: 0.2),
                                            margin: const EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      );
                                    }
                                  },
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      // 첫 번째 아이템은 친구 목록
                                      return _buildFriendsSection();
                                    }

                                    // 나머지는 게시물들
                                    final post = _posts[index - 1];
                                    return _buildPostCard(post);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 게시글 상세 화면으로 이동
  void _navigateToPostDetail(Post post, {bool autoFocusComment = false}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          postId: post.postId,
          autoFocusComment: autoFocusComment,
        ),
      ),
    )
        .then((_) {
      // 게시글 상세에서 돌아왔을 때 게시글 목록 새로고침
      _loadPosts();
    });
  }

  Widget _buildPostCard(Post post) {
    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 정보 (사용자명과 시간)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6B46C1),
                    ),
                    child: ClipOval(
                      child:
                          (post.authorProfileImage != null && post.authorProfileImage!.isNotEmpty)
                              ? Image.network(
                                  post.authorProfileImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFF6B46C1),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: const Color(0xFF6B46C1),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.authorNickname,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(post.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 더보기 버튼
                IconButton(
                  onPressed: () => _showPostOptions(post),
                  icon: const Icon(
                    Icons.more_horiz,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 게시물 내용 (사용자명 바로 아래)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                post.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 좋아요, 댓글 버튼과 수치
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  // 좋아요 버튼과 수
                  GestureDetector(
                    onTap: () => _toggleLike(post),
                    child: Row(
                      children: [
                        Icon(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: post.isLiked ? Colors.red : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.likeCount}',
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

                  // 댓글 버튼과 수
                  GestureDetector(
                    onTap: () => _navigateToPostDetail(post, autoFocusComment: true),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentCount}',
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

                  // 리트윗/공유 버튼과 수 (참고 이미지처럼)
                  Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.viewCount}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),

                  // 공유 버튼
                  Icon(
                    Icons.share_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
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

  void _showFriendSleepData(String friendId, String friendName) {
    print('🔘 친구 수면 데이터 화면 이동: $friendName ($friendId)');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendSleepDetailScreen(
          friendId: friendId,
          friendNickname: friendName,
        ),
      ),
    );
  }

  // 댓글 모달 UI

  // 댓글 아이템 UI

  Future<void> _toggleLike(Post post) async {
    print('❤️ CommunityScreen: 좋아요 토글 시작');
    print('🎯 게시물 ID: ${post.postId}');
    print('💖 현재 좋아요 상태: ${post.isLiked}, 카운트: ${post.likeCount}');

    // 중복 요청 방지
    final postIndex = _posts.indexWhere((p) => p.postId == post.postId);
    if (postIndex == -1) {
      print('❌ 게시물을 찾을 수 없습니다');
      return;
    }

    // 현재 상태 저장 (롤백용)
    final originalPost = _posts[postIndex];
    final originalIsLiked = originalPost.isLiked;
    final originalLikeCount = originalPost.likeCount;

    print('📊 원본 상태: isLiked=$originalIsLiked, likeCount=$originalLikeCount');

    // 1. 즉시 UI 피드백 (시각적 효과만) - 서버 버그로 인해 임시 비활성화
    final optimisticIsLiked = !originalIsLiked;
    final optimisticLikeCount = originalIsLiked ? originalLikeCount - 1 : originalLikeCount + 1;

    // 서버 응답이 안정적이지 않으므로 Optimistic Update 비활성화
    // setState(() {
    //   _posts[postIndex] = _posts[postIndex].copyWith(
    //     isLiked: optimisticIsLiked,
    //     likeCount: optimisticLikeCount,
    //   );
    // });

    print('⚡ Optimistic Update (비활성화): isLiked=$optimisticIsLiked, likeCount=$optimisticLikeCount');
    print('🔄 서버 응답 대기 중...');

    try {
      // 2. 서버에 요청 보내기
      final result = await PostService().toggleLike(post.postId);

      print('✅ 서버 응답 성공: $result');
      print('📋 서버 데이터: isLiked=${result['isLiked']}, likeCount=${result['likeCount']}');

      // 3. 서버 응답 보정 및 업데이트
      if (result['isLiked'] != null && result['likeCount'] != null) {
        final serverIsLiked = result['isLiked'] as bool;
        final serverLikeCount = result['likeCount'] as int;

        // 서버 응답 검증 및 보정
        int correctedLikeCount = serverLikeCount;

        // 서버 버그 감지: isLiked와 likeCount가 논리적으로 맞지 않는 경우
        if (originalIsLiked == false && serverIsLiked == true && serverLikeCount == 0) {
          // 좋아요 추가했는데 카운트가 0인 경우 → 1로 보정
          correctedLikeCount = originalLikeCount + 1;
          print('🔧 서버 버그 보정: 좋아요 추가 시 카운트 0 → ${correctedLikeCount}');
        } else if (originalIsLiked == true &&
            serverIsLiked == false &&
            serverLikeCount > originalLikeCount) {
          // 좋아요 취소했는데 카운트가 증가한 경우 → 감소로 보정
          correctedLikeCount = math.max(0, originalLikeCount - 1);
          print('🔧 서버 버그 보정: 좋아요 취소 시 카운트 증가 → ${correctedLikeCount}');
        }

        setState(() {
          final currentIndex = _posts.indexWhere((p) => p.postId == post.postId);
          if (currentIndex != -1) {
            _posts[currentIndex] = _posts[currentIndex].copyWith(
              isLiked: serverIsLiked,
              likeCount: correctedLikeCount,
            );
          }
        });

        print('🎯 최종 업데이트: isLiked=$serverIsLiked, likeCount=$correctedLikeCount');
        if (correctedLikeCount != serverLikeCount) {
          print('⚠️ 서버 응답 보정됨: ${serverLikeCount} → ${correctedLikeCount}');
        }
      } else {
        print('⚠️ 서버 응답에 필수 데이터가 없음, 롤백 실행');
        // 서버 응답이 불완전하면 롤백
        setState(() {
          final currentIndex = _posts.indexWhere((p) => p.postId == post.postId);
          if (currentIndex != -1) {
            _posts[currentIndex] = _posts[currentIndex].copyWith(
              isLiked: originalIsLiked,
              likeCount: originalLikeCount,
            );
          }
        });
      }
    } catch (e) {
      print('❌ 좋아요 토글 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');

      // 4. 에러 발생 시 원래 상태로 롤백
      setState(() {
        final currentIndex = _posts.indexWhere((p) => p.postId == post.postId);
        if (currentIndex != -1) {
          _posts[currentIndex] = _posts[currentIndex].copyWith(
            isLiked: originalIsLiked,
            likeCount: originalLikeCount,
          );
        }
      });

      print('🔄 에러로 인한 롤백 완료: isLiked=$originalIsLiked, likeCount=$originalLikeCount');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('좋아요 처리 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _navigateToCreatePost() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
      ),
    )
        .then((result) {
      if (result == true) {
        // 게시물 작성 후 목록 새로고침
        _loadPosts();

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시물이 성공적으로 작성되었습니다! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _showPostOptions(Post post) {
    // 게시물 옵션 메뉴 (신고, 숨기기 등)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('신고하기'),
              onTap: () {
                Navigator.pop(context);
                // 신고 기능 구현
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('숨기기'),
              onTap: () {
                Navigator.pop(context);
                // 숨기기 기능 구현
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
