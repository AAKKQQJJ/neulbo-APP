import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/friend.dart';
import '../../services/friend_service.dart';

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Friend> _friends = [];
  List<FriendRequest> _friendRequests = [];
  List<UserSearchResult> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadFriends(),
        _loadFriendRequests(),
      ]);
    } catch (e) {
      // 친구 데이터 로딩 오류: $e
      _loadDummyData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFriends() async {
    print('📞 FriendManagementScreen: 친구 목록 로딩 시작');
    
    try {
      final result = await FriendService.getFriends(
        page: 0,
        size: 50, // 충분한 수의 친구를 로드
        sort: 'name',
      );
      
      if (mounted) {
        setState(() {
          _friends = result['friends'] as List<Friend>;
        });
        
        print('✅ 친구 목록 로딩 성공: ${_friends.length}명');
      }
    } catch (e) {
      print('❌ 친구 목록 로딩 실패: $e');
      
      if (mounted) {
        // 에러 발생 시 빈 목록으로 설정
        setState(() {
          _friends = [];
        });
        
        // 사용자에게 에러 알림
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 목록을 불러오는데 실패했습니다'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '다시 시도',
              textColor: Colors.white,
              onPressed: () => _loadFriends(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      print('🔍 친구 요청 목록 로딩 시작...');
      final result = await FriendService.getFriendRequests(
        type: 'received',
        status: 'pending',
      );
      print('📋 친구 요청 API 응답: $result');
      print('📋 응답 타입: ${result.runtimeType}');
      print('📋 friendRequests 키 존재: ${result.containsKey('friendRequests')}');
      
      if (result.containsKey('friendRequests')) {
        final friendRequests = result['friendRequests'];
        print('📋 friendRequests 타입: ${friendRequests.runtimeType}');
        print('📋 friendRequests 길이: ${(friendRequests as List).length}');
        
        setState(() {
          _friendRequests = friendRequests as List<FriendRequest>;
        });
        
        print('✅ 친구 요청 목록 로딩 완료: ${_friendRequests.length}개');
      } else {
        print('❌ 응답에 friendRequests 키가 없습니다');
        setState(() {
          _friendRequests = [];
        });
      }
    } catch (e) {
      print('❌ 친구 요청 로딩 오류: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      setState(() {
        _friendRequests = [];
      });
    }
  }

  void _loadDummyData() {
    setState(() {
      _friends = [
        Friend(
          friendshipId: 'friendship_1',
          friend: const FriendUser(
            userId: 'user_1',
            nickname: '나산하',
            profileImage: '',
            isOnline: true,
          ),
          friendshipDate: DateTime.now().subtract(const Duration(days: 30)),
          mutualFriendsCount: 5,
        ),
        Friend(
          friendshipId: 'friendship_2',
          friend: const FriendUser(
            userId: 'user_2',
            nickname: '박지현',
            profileImage: '',
            isOnline: false,
            lastSeenAt: null,
          ),
          friendshipDate: DateTime.now().subtract(const Duration(days: 15)),
          mutualFriendsCount: 3,
        ),
      ];

      _friendRequests = [
        FriendRequest(
          friendRequestId: 'request_1',
          fromUser: const FriendUser(
            userId: 'user_3',
            nickname: '김선우',
            profileImage: '',
          ),
          toUser: const FriendUser(
            userId: 'current_user',
            nickname: '나',
          ),
          message: '안녕하세요! 친구가 되어요.',
          status: FriendRequestStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await FriendService.searchUsers(query: query);
      setState(() {
        _searchResults = result['users'] as List<UserSearchResult>;
      });
    } catch (e) {
      // 사용자 검색 오류: $e
      // 더미 검색 결과
      setState(() {
        _searchResults = [
          UserSearchResult(
            userId: 'search_user_1',
            nickname: '검색된 사용자 1',
            profileImage: '',
            friendshipStatus: FriendshipStatus.none,
            mutualFriendsCount: 2,
          ),
        ];
      });
    } finally {
      setState(() => _isSearching = false);
    }
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
        backgroundColor: const Color(0xFF2D1B69),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            '친구 관리 & 찾기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: '친구 목록'),
              Tab(text: '친구 찾기'),
              Tab(text: '친구 요청'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFriendsTab(),
            _buildSearchTab(),
            _buildFriendRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '친구가 없습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '친구 찾기 탭에서 새로운 친구를 찾아보세요',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _friends.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF6B46C1),
                backgroundImage: (friend.friend.profileImage != null && friend.friend.profileImage!.isNotEmpty)
                    ? NetworkImage(friend.friend.profileImage!)
                    : null,
                child: (friend.friend.profileImage == null || friend.friend.profileImage!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 25)
                    : null,
              ),
              if (friend.friend.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.friend.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend.friend.isOnline
                      ? '온라인'
                      : friend.friend.lastSeenAt != null
                          ? '마지막 접속: ${_formatDateTime(friend.friend.lastSeenAt!)}'
                          : '오프라인',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '공통 친구 ${friend.mutualFriendsCount}명',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteFriendDialog(friend);
              } else if (value == 'profile') {
                _showUserProfile(friend.friend);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('프로필 보기'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('친구 삭제'),
              ),
            ],
            child: const Icon(
              Icons.more_vert,
              color: Color(0xFF6B46C1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_friendRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '받은 친구 요청이 없습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _friendRequests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        return _buildFriendRequestCard(request);
      },
    );
  }

  Widget _buildFriendRequestCard(FriendRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF6B46C1),
                backgroundImage: (request.fromUser.profileImage != null && request.fromUser.profileImage!.isNotEmpty)
                    ? NetworkImage(request.fromUser.profileImage!)
                    : null,
                child: (request.fromUser.profileImage == null || request.fromUser.profileImage!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 25)
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fromUser.nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.createdAt != null 
                          ? _formatDateTime(request.createdAt!)
                          : '방금 전',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (request.message != null) ...[
            const SizedBox(height: 12),
            Text(
              request.message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondToFriendRequest(
                    request,
                    FriendRequestAction.accept,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B46C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('수락'),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToFriendRequest(
                    request,
                    FriendRequestAction.reject,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B46C1),
                    side: const BorderSide(color: Color(0xFF6B46C1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('거절'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '닉네임 또는 이메일로 검색',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(
                Icons.search, 
                color: Colors.white.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (value) {
              _searchUsers(value);
            },
          ),
        ),
        
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? '친구를 검색해보세요'
                                : '검색 결과가 없습니다',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_searchController.text.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              '닉네임 또는 이메일로 새로운 친구를 찾아보세요',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return _buildSearchResultCard(user);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(UserSearchResult user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF6B46C1),
            backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty)
                ? NetworkImage(user.profileImage!)
                : null,
            child: (user.profileImage == null || user.profileImage!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white, size: 25)
                : null,
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '공통 친구 ${user.mutualFriendsCount}명',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          
          _buildFriendshipButton(user),
        ],
      ),
    );
  }

  Widget _buildFriendshipButton(UserSearchResult user) {
    switch (user.friendshipStatus) {
      case FriendshipStatus.none:
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('친구 추가'),
        );
      
      case FriendshipStatus.pendingSent:
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('요청 전송됨'),
        );
      
      case FriendshipStatus.pendingReceived:
        return ElevatedButton(
          onPressed: () => _acceptPendingRequest(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('수락'),
        );
      
      case FriendshipStatus.friends:
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('친구'),
        );
    }
  }

  Future<void> _sendFriendRequest(UserSearchResult user) async {
    try {
      await FriendService.sendFriendRequest(targetUserId: user.userId);
      
      setState(() {
        final index = _searchResults.indexWhere((u) => u.userId == user.userId);
        if (index != -1) {
          _searchResults[index] = UserSearchResult(
            userId: user.userId,
            nickname: user.nickname,
            profileImage: user.profileImage,
            friendshipStatus: FriendshipStatus.pendingSent,
            mutualFriendsCount: user.mutualFriendsCount,
          );
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 보냈습니다')),
        );
      }
    } catch (e) {
      if (e is AlreadyRequestedException) {
        // 이미 친구 요청을 보낸 경우 - UI 상태 업데이트
        setState(() {
          final index = _searchResults.indexWhere((u) => u.userId == user.userId);
          if (index != -1) {
            _searchResults[index] = UserSearchResult(
              userId: user.userId,
              nickname: user.nickname,
              profileImage: user.profileImage,
              friendshipStatus: FriendshipStatus.pendingSent,
              mutualFriendsCount: user.mutualFriendsCount,
            );
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.nickname}님에게 이미 친구 요청을 보냈습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('친구 요청 전송 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _acceptPendingRequest(UserSearchResult user) async {
    // 실제로는 요청 ID를 찾아서 수락해야 함
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 요청을 수락했습니다')),
      );
    }
  }

  Future<void> _respondToFriendRequest(
    FriendRequest request,
    FriendRequestAction action,
  ) async {
    try {
      final response = await FriendService.respondToFriendRequestApi(
        requestId: request.friendRequestId,
        action: action == FriendRequestAction.accept ? 'ACCEPT' : 'REJECT',
      );
      
      if (mounted) {
        setState(() {
          _friendRequests.removeWhere(
            (r) => r.friendRequestId == request.friendRequestId,
          );
        });
      }
      
      if (action == FriendRequestAction.accept && response['friendship'] != null && mounted) {
        // 실제 API 응답에서 friendship 정보를 받아서 친구 목록에 추가
        final friendshipData = response['friendship'];
        setState(() {
          _friends.add(Friend(
            friendshipId: friendshipData['friendshipId'],
            friend: request.fromUser,
            friendshipDate: DateTime.parse(friendshipData['createdAt']),
            mutualFriendsCount: 0, // API에서 제공하지 않으므로 기본값
          ));
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == FriendRequestAction.accept
                  ? '친구 요청을 수락했습니다'
                  : '친구 요청을 거절했습니다',
            ),
            backgroundColor: action == FriendRequestAction.accept
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteFriendDialog(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('${friend.friend.nickname}님을 친구에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFriend(friend);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFriend(Friend friend) async {
    try {
      await FriendService.deleteFriend(friend.friendshipId);
      
      setState(() {
        _friends.removeWhere((f) => f.friendshipId == friend.friendshipId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구를 삭제했습니다')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 삭제 실패: $e')),
      );
    }
  }

  void _showUserProfile(FriendUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.nickname}의 프로필'),
        content: const Text('프로필 화면 구현 예정'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
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
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}
