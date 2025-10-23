import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../const/design_constants.dart';
import '../../services/oauth_service.dart';
import '../../services/user_service.dart';

class MyprofileScreen extends StatefulWidget {
  const MyprofileScreen({super.key});

  @override
  State<MyprofileScreen> createState() => _MyprofileScreenState();
}

class _MyprofileScreenState extends State<MyprofileScreen> {
  String _nickname = '사용자';
  String _email = '';
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    await UserService.loadUserInfo();
    setState(() {
      _nickname = UserService.getUserNickname();
      _email = UserService.getUserEmail();
      _profileImageUrl = UserService.getUserProfileImageUrl();
    });
  }

  Future<void> _handleLogout() async {
    try {
      await OAuthService.logout();
      await UserService.clearUserInfo();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print('로그아웃 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 반응형 배경 이미지
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(DesignConstants.defaultBackgroundPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    onError: (exception, stackTrace) {
                      print('내 프로필 배경 이미지 로드 실패: $exception');
                    },
                  ),
                  // 이미지가 작을 경우를 대비한 fallback 색상
                  color: const Color(0xFF2D1B69),
                ),
                child: Container(
                  // 이미지 위에 약간의 오버레이 (선택사항)
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 콘텐츠
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // 최상단: 프로필 이미지 + 유저네임
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          backgroundImage:
                              _profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) : null,
                          child: _profileImageUrl.isEmpty
                              ? const Icon(Icons.person, size: 45, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nickname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'suit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // 상단: 내 포인트, 내가 쓴 글, 고객센터
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTopButton(
                            icon: '💰',
                            label: '내 포인트',
                            onTap: () => _showComingSoon(context),
                          ),
                          _buildTopButton(
                            icon: '📝',
                            label: '내가 쓴 글',
                            onTap: () => _showComingSoon(context),
                          ),
                          _buildTopButton(
                            icon: '❓',
                            label: '고객센터',
                            onTap: () => _showComingSoon(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 중간: 메뉴 리스트
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _buildMenuItem(
                              icon: Icons.bar_chart_rounded,
                              title: '수면 데이터 확인하기',
                              onTap: () {
                                context.push('/sleep-data-demo');
                              },
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.nightlight_round,
                              title: '수면 목표',
                              subtitle: '하루 7시간',
                              onTap: () => _showComingSoon(context),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.favorite_border,
                              title: '건강 연동',
                              subtitle: 'HealthKit',
                              onTap: () => _showComingSoon(context),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.logout,
                              title: '로그아웃',
                              onTap: _handleLogout,
                              isDestructive: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 버튼 (내 포인트, 내가 쓴 글, 고객센터)
  Widget _buildTopButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'suit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 메뉴 아이템
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red.shade300 : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red.shade300 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'suit',
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontFamily: 'suit',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive ? Colors.red.shade300 : Colors.white.withOpacity(0.7),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // 구분선
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withOpacity(0.1),
      ),
    );
  }

  // "추후 개발 예정입니다" 메시지
  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '추후 개발 예정입니다',
          style: TextStyle(fontFamily: 'suit'),
        ),
        backgroundColor: Colors.deepPurple.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
