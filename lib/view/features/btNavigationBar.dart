import 'package:flutter/material.dart';

import '../screens/community_screen.dart';
import '../screens/home_screen.dart';
import '../screens/myprofile_screen.dart';
import '../screens/sleepAI_screen.dart';
import '../screens/sleepmode_screen.dart';

class BtNavigationBar extends StatefulWidget {
  const BtNavigationBar({super.key});

  @override
  State<BtNavigationBar> createState() => _BtNavigationBarState();
}

class _BtNavigationBarState extends State<BtNavigationBar> {
  int _selectedIndex = 0;
  final GlobalKey<State<HomeScreen>> _homeScreenKey = GlobalKey<State<HomeScreen>>();

  late final List<Widget> _Tap = [
    /// 홈 탭
    HomeScreen(key: _homeScreenKey),

    /// 커뮤니티 탭
    const CommunityScreen(),

    /// 수면모드 탭
    const SleepmodeScreen(),

    /// 수면 인공비서 탭
    const SleepaiScreen(),

    /// 내 정보 탭
    const MyprofileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // 홈 탭으로 전환 시 디바이스 설정 재확인
    if (index == 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        final state = _homeScreenKey.currentState;
        if (state != null && state is State<HomeScreen>) {
          // Dynamic call로 public 메서드 호출
          (state as dynamic).checkAndReloadIfDeviceChanged();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2D1B69),
              Color(0xFF1A0F3D),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: _Tap,
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _buildGradientBottomNavigationBar(),
    );
  }

  Widget _buildGradientBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF624BAC),
            Color(0xFF7B68B8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withOpacity(0.6),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              showUnselectedLabels: true,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_add_alt_1_sharp),
                  label: '커뮤니티',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bedtime_sharp),
                  label: '수면모드',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.support_agent_outlined),
                  label: '수면비서',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: '내 정보',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
