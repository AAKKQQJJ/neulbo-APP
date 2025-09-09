// lib/services/oauth_service.dart
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OAuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ✅ 환경변수에서 안전하게 가져오기
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? '';
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  static String get kakaoClientId => dotenv.env['KAKAO_CLIENT_ID'] ?? '';
  static String get naverClientId => dotenv.env['NAVER_CLIENT_ID'] ?? '';

  // OAuth 제공자별 설정
  /// TODO - client url 입력 필요
  static Map<String, Map<String, String>> oauthConfigs = {
    'google': {
      'authUrl': 'https://accounts.google.com/o/oauth2/v2/auth',
      'clientId': googleClientId,
      'scope': 'openid email profile',
    },
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

  // 1. OAuth 로그인 시작
  static Future<void> startOAuthLogin(String provider) async {
    final config = oauthConfigs[provider]!;
    final redirectUri = 'yourapp://oauth/callback';
    final state = _generateRandomString(32); // CSRF 방지용

    // state 저장 (나중에 검증용)
    await _storage.write(key: 'oauth_state', value: state);

    final authUrl = Uri.parse(config['authUrl']!).replace(queryParameters: {
      'client_id': config['clientId']!,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': config['scope']!,
      'state': state,
    });

    // 2. 외부 브라우저로 OAuth 인증 페이지 열기
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch OAuth URL');
    }
  }

  // 3. 딥링크로 돌아온 인가 코드 처리
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
        // 4. 백엔드로 인가 코드 전송하여 JWT 받기
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

  // 5. 백엔드에 인가 코드를 보내고 JWT 토큰 받기
  static Future<bool> _exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'redirect_uri': 'yourapp://oauth/callback',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final jwtToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        // 7. JWT 토큰을 안전하게 저장
        await _storage.write(key: 'jwt_token', value: jwtToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);

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

  // 로그아웃
  static Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
  }

  // 랜덤 문자열 생성 (state 파라미터용)
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecond % chars.length])
        .join();
  }
}
