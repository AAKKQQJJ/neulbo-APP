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

  // Google Sign-In 인스턴스
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid',
    ],
  );

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

  // Google Sign-In 처리
  static Future<void> _handleGoogleSignIn() async {
    try {
      // Google 로그인 시도
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        // 인증 정보 가져오기
        final GoogleSignInAuthentication auth = await account.authentication;
        
        // ID 토큰을 백엔드로 전송 (서버에서 검증)
        if (auth.idToken != null) {
          final success = await _sendGoogleTokenToBackend(auth.idToken!);
          
          if (success) {
            print('Google 로그인 성공');
          } else {
            print('백엔드 인증 실패');
            await _googleSignIn.signOut();
          }
        } else {
          print('ID 토큰을 가져올 수 없습니다.');
          await _googleSignIn.signOut();
        }
      } else {
        print('Google 로그인 취소됨');
      }
    } catch (error) {
      print('Google Sign-In 에러: $error');
    }
  }

  // Google ID 토큰을 백엔드로 전송
  static Future<bool> _sendGoogleTokenToBackend(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/oauth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_token': idToken,
          'provider': 'google',
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
