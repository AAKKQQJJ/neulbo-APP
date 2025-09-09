import 'package:go_router/go_router.dart';

import '../view/features/btNavigationBar.dart';
import '../view/screens/home_screen.dart';
import '../view/screens/login_screen.dart';
import '../view/screens/sleepAI_screen.dart';
import '../view/screens/sleepmode_screen.dart';

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
    ],
  );

  static GoRouter get router => _router;
}
