import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/friend.dart';
import '../../services/friend_service.dart';

class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  
  List<UserSearchResult> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    print('🔍 FriendSearchScreen: 검색 시작 - query: "$query"');
    
    if (query.isEmpty) {
      print('❌ 검색어가 비어있음');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      print('📞 FriendService.searchUsers 호출 중...');
      final result = await _friendService.searchUsers(query: query);
      print('✅ 검색 결과 받음: ${result['users']?.length ?? 0}개 사용자');
      
      if (mounted) {
        setState(() {
          _searchResults = result['users'] as List<UserSearchResult>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ FriendSearchScreen 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searchResults = [];
        });
        
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        print('📱 SnackBar 표시: $errorMessage');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(UserSearchResult user) async {
    print('🚀 FriendSearchScreen: 친구 요청 시작');
    print('👤 대상 사용자: ${user.nickname} (${user.userId})');
    
    try {
      print('📞 FriendService.sendFriendRequest 호출 중...');
      
      await _friendService.sendFriendRequest(
        targetUserId: user.userId,
        message: '안녕하세요! 친구가 되어주세요 😊',
      );

      print('✅ 친구 요청 성공!');
      
      // 해당 사용자의 상태를 pendingSent로 업데이트
      setState(() {
        final index = _searchResults.indexWhere((result) => result.userId == user.userId);
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
            content: Text('${user.nickname}님에게 친구 요청을 보냈습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ FriendSearchScreen 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      
      if (e is AlreadyRequestedException) {
        // 이미 친구 요청을 보낸 경우 - UI 상태 업데이트
        print('🔄 이미 요청 보냄 - UI 상태 업데이트');
        setState(() {
          final index = _searchResults.indexWhere((result) => result.userId == user.userId);
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
        // 기타 에러
        if (mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          print('📱 SnackBar 표시: $errorMessage');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildUserCard(UserSearchResult user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 프로필 이미지
          Container(
            width: 60,
            height: 60,
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
                child: (user.profileImage != null && user.profileImage!.isNotEmpty)
                    ? Image.network(
                        user.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          );
                        },
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 사용자 정보
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
                if (user.mutualFriendsCount > 0)
                  Text(
                    '공통 친구 ${user.mutualFriendsCount}명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          
          // 친구 요청 버튼
          _buildActionButton(user),
        ],
      ),
    );
  }

  Widget _buildActionButton(UserSearchResult user) {
    switch (user.friendshipStatus) {
      case FriendshipStatus.none:
        return ElevatedButton(
          onPressed: () {
            print('🔘 친구 추가 버튼 클릭됨: ${user.nickname}');
            _sendFriendRequest(user);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            '친구 추가',
            style: TextStyle(fontSize: 12),
          ),
        );
      
      case FriendshipStatus.pendingSent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange),
          ),
          child: const Text(
            '요청 중',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
            ),
          ),
        );
      
      case FriendshipStatus.pendingReceived:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue),
          ),
          child: const Text(
            '응답 대기',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
        );
      
      case FriendshipStatus.friends:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green),
          ),
          child: const Text(
            '친구',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
            ),
          ),
        );
    }
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
        backgroundColor: const Color(0xFF2D1B69),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          title: const Text(
            '친구 찾기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            // 검색 바
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '닉네임 또는 이메일로 검색',
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _searchUsers(),
                    ),
                  ),
                  IconButton(
                    onPressed: _searchUsers,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            
            // 검색 결과
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : _hasSearched
                      ? _searchResults.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.white30,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '검색 결과가 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                return _buildUserCard(_searchResults[index]);
                              },
                            )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 64,
                                color: Colors.white30,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '닉네임 또는 이메일로\n친구를 찾아보세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
