import 'package:go_router/go_router.dart';

import '../services/user_service.dart';
import '../view/features/btNavigationBar.dart';
import '../view/screens/home_screen.dart';
import '../view/screens/login_screen.dart';
import '../view/screens/sleepAI_screen.dart';
import '../view/screens/sleep_data_demo_screen.dart';
import '../view/screens/sleepmode_screen.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final isLoggedIn = await UserService.isLoggedIn();
      final isLoginPage = state.matchedLocation == '/login';

      // 로그인된 상태에서 로그인 페이지에 있으면 홈으로 리다이렉트
      if (isLoggedIn && isLoginPage) {
        return '/btNavi';
      }

      // 로그인되지 않은 상태에서 로그인 페이지가 아니면 로그인으로 리다이렉트
      if (!isLoggedIn && !isLoginPage) {
        return '/login';
      }

      return null; // 리다이렉트하지 않음
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/btNavi',
        builder: (context, state) => BtNavigationBar(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeScreen(),
      ),
      GoRoute(
        path: '/sleepMode',
        builder: (context, state) => SleepmodeScreen(),
      ),
      GoRoute(
        path: '/sleepAi',
        builder: (context, state) => SleepaiScreen(),
      ),
      GoRoute(
        path: '/sleep-data-demo',
        builder: (context, state) => SleepDataDemoScreen(),
      ),
    ],
  );

  static GoRouter get router => _router;
}
