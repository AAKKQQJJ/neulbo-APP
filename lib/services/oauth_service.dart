import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'user_service.dart';
import '../models/user_info.dart';

class OAuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // 환경변수에서 안전하게 가져오기
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? '';
  static String get kakaoClientId => dotenv.env['KAKAO_CLIENT_ID'] ?? '';
  static String get naverClientId => dotenv.env['NAVER_CLIENT_ID'] ?? '';
  static String get googleClientIdIOS => dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static String get googleClientIdAndroid => dotenv.env['GOOGLE_CLIENT_ID_ANDROID'] ?? '';
  static String get googleClientIdWeb => dotenv.env['GOOGLE_CLIENT_ID_WEB'] ?? '';

  // Google Sign-In 인스턴스 (idToken 방식)
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS는 Info.plist의 GIDClientID를 자동으로 사용하므로 clientId 파라미터 제거
    // serverClientId를 제거하고 idToken을 받도록 설정
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
  static Future<bool> startOAuthLogin(String provider) async {
    switch (provider) {
      case 'google':
        return await _handleGoogleSignIn();
      case 'kakao':
      case 'naver':
        await _handleTraditionalOAuth(provider);
        return false; // 딥링크로 처리되므로 여기서는 false 반환
      default:
        throw Exception('Unsupported OAuth provider: $provider');
    }
  }

  // Google Sign-In 처리 (idToken 방식)
  static Future<bool> _handleGoogleSignIn() async {
    try {
      // 매번 새로운 토큰을 받기 위해 우선 연결을 해제
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      // Google 로그인 시도
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account != null) {
        print('Google 로그인 계정 정보 확인됨: ${account.email}');
        
        // 사용자 데이터를 백엔드로 전송
        final success = await _sendGoogleUserDataToBackend(
          account: account,
        );
          
        if (success) {
          print('Google 로그인 성공');
          return true;
        } else {
          print('백엔드 인증 실패');
          await _googleSignIn.signOut();
          return false;
        }
      } else {
        print('Google 로그인 취소됨');
        return false;
      }
    } catch (error) {
      print('Google Sign-In 에러: $error');
      return false;
    }
  }

  // Google 사용자 데이터를 백엔드로 전송
  static Future<bool> _sendGoogleUserDataToBackend({
    required GoogleSignInAccount account,
  }) async {
    try {
      print('Google 사용자 데이터 전송 중...');
      print('Provider ID: ${account.id}');
      print('Email: ${account.email}');
      print('Display Name: ${account.displayName}');
      
      final response = await ApiService.oauthLogin(
        provider: 'google',
        providerId: account.id,
        email: account.email,
        name: account.displayName ?? '',
        profileImageUrl: account.photoUrl ?? '',
        nickname: account.displayName ?? '',
      );

      print('백엔드 응답 상태: ${response.statusCode}');
      print('백엔드 응답 내용: ${response.data}');

      if (response.statusCode == 200) {
        final responseBody = response.data;
        
        // 응답이 래핑된 형식인지 직접 데이터인지 확인
        String? accessToken;
        String? refreshToken;
        bool isNewUser = false;
        
        if (responseBody.containsKey('success') && responseBody.containsKey('data')) {
          // 래핑된 형식: {success: true, data: {accessToken: ..., refreshToken: ..., isNewUser: ...}}
          final success = responseBody['success'] ?? false;
          if (success && responseBody['data'] != null) {
            final data = responseBody['data'];
            accessToken = data['accessToken'];
            refreshToken = data['refreshToken'];
            isNewUser = data['isNewUser'] ?? false;
          } else {
            print('백엔드 응답 실패: success=${success}, message=${responseBody['message']}');
            return false;
          }
        } else if (responseBody.containsKey('accessToken')) {
          // 직접 데이터 형식: {accessToken: ..., refreshToken: ..., isNewUser: ...}
          accessToken = responseBody['accessToken'];
          refreshToken = responseBody['refreshToken'];
          isNewUser = responseBody['isNewUser'] ?? false;
          print('직접 데이터 형식으로 응답 받음');
        } else {
          print('알 수 없는 응답 형식: ${responseBody.keys.toList()}');
          return false;
        }

        if (accessToken != null) {
          // JWT 토큰을 안전하게 저장
          await _storage.write(key: 'jwt_token', value: accessToken);
          if (refreshToken != null) {
            await _storage.write(key: 'refresh_token', value: refreshToken);
          }

          // 사용자 정보 저장
          final userInfo = UserInfo(
            provider: 'google',
            providerId: account.id,
            email: account.email,
            name: account.displayName ?? '',
            profileImageUrl: account.photoUrl ?? '',
            nickname: account.displayName ?? '',
            accessToken: accessToken,
            refreshToken: refreshToken,
            isNewUser: isNewUser,
          );
          await UserService.saveUserInfo(userInfo);

          print('Google 로그인 성공 - 신규 사용자: $isNewUser');
          return true;
        } else {
          print('accessToken을 찾을 수 없습니다');
          return false;
        }
      } else {
        print('백엔드 응답 오류: ${response.statusCode} - ${response.data}');
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
      // 먼저 인가 코드로 OAuth 제공자에서 사용자 정보를 가져옴
      final userInfo = await _getUserInfoFromProvider(code);
      if (userInfo == null) {
        return false;
      }

      // 새로운 API 형식으로 백엔드에 전송
      final response = await ApiService.oauthLogin(
        provider: userInfo['provider'],
        providerId: userInfo['providerId'],
        email: userInfo['email'],
        name: userInfo['name'],
        profileImageUrl: userInfo['profileImageUrl'],
        nickname: userInfo['nickname'],
      );

      print('백엔드 응답 상태: ${response.statusCode}');
      print('백엔드 응답 내용: ${response.data}');

      if (response.statusCode == 200) {
        final responseBody = response.data;
        
        // 응답이 래핑된 형식인지 직접 데이터인지 확인
        String? accessToken;
        String? refreshToken;
        bool isNewUser = false;
        
        if (responseBody.containsKey('success') && responseBody.containsKey('data')) {
          // 래핑된 형식
          final success = responseBody['success'] ?? false;
          if (success && responseBody['data'] != null) {
            final data = responseBody['data'];
            accessToken = data['accessToken'];
            refreshToken = data['refreshToken'];
            isNewUser = data['isNewUser'] ?? false;
          } else {
            print('백엔드 응답 실패: success=${success}, message=${responseBody['message']}');
            return false;
          }
        } else if (responseBody.containsKey('accessToken')) {
          // 직접 데이터 형식
          accessToken = responseBody['accessToken'];
          refreshToken = responseBody['refreshToken'];
          isNewUser = responseBody['isNewUser'] ?? false;
          print('직접 데이터 형식으로 응답 받음');
        } else {
          print('알 수 없는 응답 형식: ${responseBody.keys.toList()}');
          return false;
        }

        if (accessToken != null) {
          // JWT 토큰을 안전하게 저장
          await _storage.write(key: 'jwt_token', value: accessToken);
          if (refreshToken != null) {
            await _storage.write(key: 'refresh_token', value: refreshToken);
          }

          print('OAuth 로그인 성공 - 신규 사용자: $isNewUser');
          return true;
        } else {
          print('accessToken을 찾을 수 없습니다');
          return false;
        }
      } else {
        print('백엔드 응답 오류: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      print('Token exchange error: $e');
      return false;
    }
  }

  // OAuth 제공자에서 사용자 정보 가져오기 (Kakao, Naver용)
  static Future<Map<String, dynamic>?> _getUserInfoFromProvider(String code) async {
    try {
      // 이 부분은 실제 구현에서는 각 OAuth 제공자의 API를 호출해야 합니다.
      // 현재는 예시로 기본값을 반환합니다.
      // 실제로는 code를 사용해서 access_token을 받고, 그 토큰으로 사용자 정보를 가져와야 합니다.
      
      // TODO: 실제 Kakao/Naver API 호출 구현 필요
      return {
        'provider': 'kakao', // 또는 'naver'
        'providerId': 'temp_provider_id',
        'email': 'temp@example.com',
        'name': '임시 사용자',
        'profileImageUrl': '',
        'nickname': '임시닉네임',
      };
    } catch (e) {
      print('사용자 정보 가져오기 실패: $e');
      return null;
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
