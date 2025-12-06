import 'package:go_router/go_router.dart';

import '../services/user_service.dart';
import '../view/features/btNavigationBar.dart';
import '../view/screens/home_screen.dart';
import '../view/screens/integrated_sleep_data_screen.dart';
import '../view/screens/login_screen.dart';
import '../view/screens/sleepAI_screen.dart';
import '../view/screens/sleep_data_demo_screen.dart';
import '../view/screens/sleepmode_screen.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      try {
      // Custom URL scheme (kakao://, naver://, google://) 무시
      final uri = state.uri;
        
        // 카카오, 네이버, 구글 등의 커스텀 스키마는 무시
        if (uri.scheme.startsWith('kakao') || 
            uri.scheme.startsWith('naver') || 
            uri.scheme.startsWith('google') ||
            (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != '')) {
        print('⚠️ GoRouter: Custom URL scheme 무시됨 - ${uri.scheme}://');
        return null;
      }
      
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
      } catch (e) {
        print('⚠️ GoRouter redirect 에러: $e');
        return null;
      }
    },
    onException: (context, state, router) {
      // GoRouter 예외 처리
      print('⚠️ GoRouter Exception: ${state.error}');
      print('⚠️ 문제가 된 URI: ${state.uri}');
      
      // 커스텀 스키마 관련 에러는 무시
      if (state.error.toString().contains('Origin is only applicable to schemes http and https')) {
        print('📱 OAuth 리다이렉트 감지됨 - 무시합니다');
        return;
      }
      
      // 다른 예외 발생 시 로그인 페이지로
      router.go('/login');
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
      GoRoute(
        path: '/integrated-sleep-data',
        builder: (context, state) => const IntegratedSleepDataScreen(),
      ),
    ],
  );

  static GoRouter get router => _router;
}
