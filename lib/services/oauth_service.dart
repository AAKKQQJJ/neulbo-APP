import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OAuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // 환경변수에서 안전하게 가져오기
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? '';
  static String get kakaoClientId => dotenv.env['KAKAO_CLIENT_ID'] ?? '';
  static String get naverClientId => dotenv.env['NAVER_CLIENT_ID'] ?? '';
  static String get googleClientIdIOS => dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static String get googleClientIdAndroid => dotenv.env['GOOGLE_CLIENT_ID_ANDROID'] ?? '';
  static String get googleClientIdWeb => dotenv.env['GOOGLE_CLIENT_ID_WEB'] ?? '';

  // Google Sign-In 인스턴스 (Server-side 방식)
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS는 Info.plist의 GIDClientID를 자동으로 사용하므로 clientId 파라미터 제거
    serverClientId: googleClientIdWeb, // 웹 클라이언트 ID로 서버 사이드 인증 활성화
    scopes: [
      'email',
      'profile',
      'openid',
    ],
  );

  // 디버깅용 환경변수 출력은 제거 (민감정보 노출 방지)

  // OAuth 제공자별 설정 (Kakao, Naver용)
  static Map<String, Map<String, String>> get oauthConfigs => {
    'kakao': {
      'authUrl': 'https://kauth.kakao.com/oauth/authorize',
      'clientId': kakaoClientId,
      'scope': 'profile_nickname profile_image account_email',
    },
    'naver': {
      'authUrl': 'https://nid.naver.com/oauth2.0/authorize',
      'clientId': naverClientId,
      'scope': 'name email profile_image',
    },
  };

  // OAuth 로그인 시작 (통합 메서드)
  static Future<void> startOAuthLogin(String provider) async {
    switch (provider) {
      case 'google':
        await _handleGoogleSignIn();
        break;
      case 'kakao':
      case 'naver':
        await _handleTraditionalOAuth(provider);
        break;
      default:
        throw Exception('Unsupported OAuth provider: $provider');
    }
  }

  // Google Sign-In 처리 (Server-side 방식)
  static Future<void> _handleGoogleSignIn() async {
    try {
      // 매번 serverAuthCode를 받기 위해 우선 연결을 해제(토큰 철회)
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      // Google 로그인 시도
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        // 서버 사이드 인증을 위한 인가 코드 가져오기
        GoogleSignInAuthentication auth = await account.authentication;
        
        // serverAuthCode (인가 코드)를 백엔드로 전송
        if (auth.serverAuthCode != null) {
          final success = await _sendGoogleAuthCodeToBackend(auth.serverAuthCode!);
          
          if (success) {
            print('Google 로그인 성공');
          } else {
            print('백엔드 인증 실패');
            await _googleSignIn.signOut();
          }
        } else {
          // 한 번 더 강제 재인증을 시도하여 serverAuthCode 확보
          print('serverAuthCode가 없어 재시도합니다 (disconnect → signIn).');
          try {
            await _googleSignIn.disconnect();
          } catch (_) {}
          account = await _googleSignIn.signIn();
          if (account == null) {
            print('Google 로그인 취소됨');
            return;
          }
          auth = await account.authentication;
          if (auth.serverAuthCode != null) {
            final success = await _sendGoogleAuthCodeToBackend(auth.serverAuthCode!);
            if (success) {
              print('Google 로그인 성공');
            } else {
              print('백엔드 인증 실패');
              await _googleSignIn.signOut();
            }
          } else {
            print('인가 코드를 가져올 수 없습니다. Google 콘솔 설정을 확인하세요.');
            print('- Web Client ID를 serverClientId로 사용 중인지');
            print('- OAuth 동의화면/테스트 사용자 등록 여부');
            await _googleSignIn.signOut();
          }
        }
      } else {
        print('Google 로그인 취소됨');
      }
    } catch (error) {
      print('Google Sign-In 에러: $error');
    }
  }

  // Google 인가 코드를 백엔드로 전송
  static Future<bool> _sendGoogleAuthCodeToBackend(String authCode) async {
    try {
      print('Google 인가 코드 전송 중: ${authCode.substring(0, 20)}...');
      
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/oauth/login/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': authCode, // API 명세서에 따라 인가 코드 전송
        }),
      );

      print('백엔드 응답 상태: ${response.statusCode}');
      print('백엔드 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final isNewUser = data['isNewUser'] ?? false;

        // JWT 토큰을 안전하게 저장
        await _storage.write(key: 'jwt_token', value: accessToken);
        if (refreshToken != null) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }

        print('Google 로그인 성공 - 신규 사용자: $isNewUser');
        return true;
      } else {
        print('백엔드 응답 오류: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Google 백엔드 인증 에러: $e');
      return false;
    }
  }

  // 기존 방식 OAuth (Kakao, Naver용)
  static Future<void> _handleTraditionalOAuth(String provider) async {
    final config = oauthConfigs[provider];
    if (config == null) {
      throw Exception('Unsupported OAuth provider: $provider');
    }

    final redirectUri = 'coolcool://oauth/callback';
    final state = _generateRandomString(32);

    // state 저장 (나중에 검증용)
    await _storage.write(key: 'oauth_state', value: state);

    final authUrl = Uri.parse(config['authUrl']!).replace(queryParameters: {
      'client_id': config['clientId']!,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': config['scope']!,
      'state': state,
    });

    // 외부 브라우저로 OAuth 인증 페이지 열기
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch OAuth URL');
    }
  }

  // 딥링크로 돌아온 인가 코드 처리 (Kakao, Naver용)
  static Future<bool> handleOAuthCallback(Uri uri) async {
    try {
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final storedState = await _storage.read(key: 'oauth_state');

      // State 검증 (CSRF 공격 방지)
      if (state != storedState) {
        throw Exception('Invalid state parameter');
      }

      if (code != null) {
        // 백엔드로 인가 코드 전송하여 JWT 받기
        final success = await _exchangeCodeForToken(code);

        // 저장된 state 제거
        await _storage.delete(key: 'oauth_state');

        return success;
      }

      return false;
    } catch (e) {
      print('OAuth callback error: $e');
      return false;
    }
  }

  // 백엔드에 인가 코드를 보내고 JWT 토큰 받기 (Kakao, Naver용)
  static Future<bool> _exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'redirect_uri': 'coolcool://oauth/callback',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final jwtToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        // JWT 토큰을 안전하게 저장
        await _storage.write(key: 'jwt_token', value: jwtToken);
        if (refreshToken != null) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }

        return true;
      }

      return false;
    } catch (e) {
      print('Token exchange error: $e');
      return false;
    }
  }

  // JWT 토큰 가져오기
  static Future<String?> getJwtToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // 로그아웃 (모든 토큰 삭제)
  static Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _googleSignIn.signOut(); // Google 로그아웃도 함께
  }

  // 랜덤 문자열 생성 (state 파라미터용)
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecond % chars.length])
        .join();
  }
}
