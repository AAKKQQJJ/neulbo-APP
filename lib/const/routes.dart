import 'package:go_router/go_router.dart';
import 'package:neulbo/features/btNavigationBar.dart';
import 'package:neulbo/screens/sleepAI_screen.dart';
import 'package:neulbo/screens/sleepmode_screen.dart';

import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/btNavi',
        builder: (context, state) => btNavigationBar(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/sleepMode',
        builder: (context, state) => SleepmodeScreen(),
      ),
      GoRoute(
        path: '/sleepAi',
        builder: (context, state) => SleepaiScreen(),
      ),
    ],
  );

  static GoRouter get router => _router;
}
