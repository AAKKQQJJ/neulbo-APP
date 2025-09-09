import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:neulbo/const/routes.dart';

import 'services/api_service.dart';
import 'services/oauth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.initialize();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks(); // AppLinks 인스턴스 생성
  @override
  void initState() {
    super.initState();
    _handleInitialLink();
    _handleIncomingLinks();
  }

  // 앱이 종료된 상태에서 딥링크로 실행된 경우
  void _handleInitialLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      print('Initial link error: $e');
    }
  }

  // 앱이 실행 중일 때 딥링크 수신
  void _handleIncomingLinks() {
    _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri.toString());
    });
  }

  void _handleDeepLink(String link) async {
    final uri = Uri.parse(link);

    // OAuth 콜백 처리
    if (uri.scheme == 'yourapp' && uri.host == 'oauth' && uri.path == '/callback') {
      final success = await OAuthService.handleOAuthCallback(uri);

      if (success) {
        // 로그인 성공 - 메인 화면으로 이동
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // 로그인 실패 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
