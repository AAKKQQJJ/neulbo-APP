import 'package:flutter/material.dart';

import '../screens/community_screen.dart';
import '../screens/home_screen.dart';
import '../screens/myprofile_screen.dart';
import '../screens/sleepAI_screen.dart';
import '../screens/sleepmode_screen.dart';

class btNavigationBar extends StatefulWidget {
  const btNavigationBar({super.key});

  @override
  State<btNavigationBar> createState() => _btNavigationBarState();
}

class _btNavigationBarState extends State<btNavigationBar> {
  int _selectedIndex = 0;

  final List<Widget> _Tap = [
    /// 홈 탭
    HomeScreen(),

    /// 커뮤니티 탭
    CommunityScreen(),

    /// 수면모드 탭
    SleepmodeScreen(),

    /// 수면 인공비서 탭
    SleepaiScreen(),

    /// 내 정보 탭
    MyprofileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _Tap,
      ),
      bottomNavigationBar: BottomNavigationBar(
        /// 바텀 탭바 스타일 ///
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        unselectedIconTheme: IconThemeData(color: Colors.grey),
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        selectedIconTheme: IconThemeData(color: Colors.blueAccent),
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add_alt_1_sharp), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.bedtime_sharp), label: '수면모드'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent_outlined), label: '수면비서'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
      ),
    );
  }
}
