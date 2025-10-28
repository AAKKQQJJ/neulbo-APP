import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:neulbo/const/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_service.dart';
import 'services/user_service.dart';
import 'services/oauth_service.dart';

void main() async {
  print('🚀 앱 시작...');
  
  // 전역 에러 핸들러 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    // URL 스키마 관련 에러는 무시
    if (details.exception.toString().contains('Origin is only applicable to schemes http and https')) {
      print('📱 OAuth URL 스키마 에러 감지됨 - 무시합니다');
      return;
    }
    // 다른 에러는 기본 처리
    FlutterError.presentError(details);
  };
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('✅ Flutter 바인딩 초기화 완료');
    
    ApiService.initialize();
    print('✅ API 서비스 초기화 완료');
    
    // .env 파일 로드
    await dotenv.load(fileName: ".env");
    print('✅ .env 파일 로드 완료');
    
    // Kakao SDK 초기화
    final kakaoKey = dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';
    print('🔑 Kakao Native App Key: ${kakaoKey.isNotEmpty ? "존재" : "없음"}');
    KakaoSdk.init(nativeAppKey: kakaoKey);
    print('✅ Kakao SDK 초기화 완료');
    
    // 앱 재설치 시 Keychain 자동 삭제
    print('🔄 Keychain 확인 시작...');
    await _checkAndCleanupKeychain();
    print('✅ Keychain 확인 완료');
    
    // 저장된 사용자 정보 로드
    print('👤 사용자 정보 로드 시작...');
    await UserService.loadUserInfo();
    print('✅ 사용자 정보 로드 완료');
    
    print('🎉 앱 초기화 완료 - 시작합니다!');
    runApp(MyApp());
  } catch (e, stackTrace) {
    print('❌ 앱 초기화 실패: $e');
    print('Stack trace: $stackTrace');
    // 에러가 발생해도 앱을 시작 (라우팅 에러 방지)
    runApp(MyApp());
  }
}

/// 앱이 처음 실행되는 경우 (재설치) Keychain 데이터를 삭제합니다.
/// UserDefaults는 앱 삭제 시 함께 삭제되므로, 플래그가 없으면 재설치로 판단합니다.
Future<void> _checkAndCleanupKeychain() async {
  final prefs = await SharedPreferences.getInstance();
  const String hasLaunchedKey = 'has_launched_before';
  
  final bool hasLaunchedBefore = prefs.getBool(hasLaunchedKey) ?? false;
  
  if (!hasLaunchedBefore) {
    // 첫 실행 (재설치) → Keychain 삭제
    print('🔄 앱이 재설치되었습니다. Keychain 데이터를 삭제합니다...');
    await OAuthService.clearAllStoredData();
    
    // 플래그 저장
    await prefs.setBool(hasLaunchedKey, true);
    print('✅ Keychain 정리 완료');
  } else {
    print('✅ 기존 설치 확인됨 - Keychain 유지');
  }
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
