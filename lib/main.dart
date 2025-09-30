import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:neulbo/const/routes.dart';

import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.initialize();
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 현재는 딥링크 기능을 비활성화하고 기본 앱 기능에 집중
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
