import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
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
      'authUrl': 'https://kauth.kakao.com/oauth/authorize	',
      'clientId': kakaoClientId,
      'scope': 'profile_nickname profile_image',
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
        return await _handleKakaoSignIn();
      case 'naver':
        return await _handleNaverSignIn();
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

          // 백엔드에서 사용자 ID 조회 및 업데이트
          await UserService.fetchAndUpdateUserInfo();

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

  // Kakao Sign-In 처리
  static Future<bool> _handleKakaoSignIn() async {
    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;
      
      if (isInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          print('카카오톡으로 로그인 성공');
        } catch (error) {
          print('카카오톡으로 로그인 실패, 카카오계정으로 로그인 시도: $error');
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
        print('카카오계정으로 로그인 성공');
      }
      
       final User user = await UserApi.instance.me();
       print('카카오 사용자 정보 상세:');
       print('- ID: ${user.id}');
       print('- 이메일: ${user.kakaoAccount?.email}');
       print('- 이메일 동의: ${user.kakaoAccount?.emailNeedsAgreement}');
       print('- 닉네임: ${user.kakaoAccount?.profile?.nickname}');
       print('- 프로필 이미지: ${user.kakaoAccount?.profile?.profileImageUrl}');
       
       // 이메일 권한이 없는 경우 추가 동의 요청
       String email = user.kakaoAccount?.email ?? '';
       if (email.isEmpty && user.kakaoAccount?.emailNeedsAgreement == true) {
         print('이메일 권한 추가 동의 요청 중...');
         try {
           final OAuthToken newToken = await UserApi.instance.loginWithNewScopes(['account_email']);
           final User updatedUser = await UserApi.instance.me();
           email = updatedUser.kakaoAccount?.email ?? '';
           print('추가 동의 후 이메일: $email');
         } catch (e) {
           print('이메일 권한 동의 실패: $e');
           // 이메일 없이도 진행
         }
       }
      
      final success = await _sendKakaoUserDataToBackend(user, email);
      
      if (success) {
        print('Kakao 로그인 성공');
        return true;
      } else {
        print('백엔드 인증 실패');
        await UserApi.instance.logout();
        return false;
      }
    } catch (error) {
      print('Kakao Sign-In 에러: $error');
      return false;
    }
  }

   // Kakao 사용자 데이터를 백엔드로 전송
   static Future<bool> _sendKakaoUserDataToBackend(User user, String email) async {
     try {
       print('Kakao 사용자 데이터 전송 중...');
       final kakaoAccount = user.kakaoAccount;
       final profile = kakaoAccount?.profile;
       
       print('전송할 카카오 데이터:');
       print('- Provider ID: ${user.id}');
       print('- Email: $email');
       print('- Name: ${profile?.nickname ?? ''}');
       print('- Profile Image: ${profile?.profileImageUrl ?? ''}');
       
       final response = await ApiService.oauthLogin(
         provider: 'kakao',
         providerId: user.id.toString(),
         email: email,
         name: profile?.nickname ?? '',
         profileImageUrl: profile?.profileImageUrl ?? '',
         nickname: profile?.nickname ?? '',
       );

      return await _processOAuthResponse(
        response: response,
        provider: 'kakao',
        providerId: user.id.toString(),
        email: email,
        name: profile?.nickname ?? '',
        profileImageUrl: profile?.profileImageUrl ?? '',
        nickname: profile?.nickname ?? '',
      );
    } catch (e) {
      print('Kakao 백엔드 인증 에러: $e');
      return false;
    }
  }

  // Naver Sign-In 처리
  static Future<bool> _handleNaverSignIn() async {
    try {
      print('=== 네이버 로그인 시작 ===');
      print('네이버 Client ID: $naverClientId');
      print('네이버 Client Secret: ${naverClientId.isNotEmpty ? "설정됨" : "미설정"}');
      print('FlutterNaverLogin.logIn() 호출 중...');
      
      // 타임아웃 추가 (15초로 늘림)
      final NaverLoginResult result = await FlutterNaverLogin.logIn().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ 네이버 로그인 타임아웃 (15초)!');
          print('');
          print('=== 문제 진단 ===');
          print('1. 앱이 완전히 재빌드되지 않았을 가능성');
          print('2. Info.plist의 NaverThirdPartyConstantsForApp이 적용되지 않음');
          print('3. 네이버 개발자 센터 Bundle ID 불일치');
          print('');
          print('해결 방법:');
          print('- 시뮬레이터에서 앱 삭제');
          print('- flutter clean && flutter pub get');
          print('- cd ios && rm -rf Pods Podfile.lock && pod install && cd ..');
          print('- flutter run');
          throw TimeoutException('네이버 로그인 타임아웃');
        },
      );
      print('✅ FlutterNaverLogin.logIn() 응답 받음!');
      print('네이버 로그인 결과 status: ${result.status}');
      print('네이버 로그인 전체 결과: $result');
      
      if (result.status == NaverLoginStatus.loggedIn) {
        print('✅ 네이버 로그인 성공!');
        
        final NaverAccountResult account = await FlutterNaverLogin.currentAccount();
        print('네이버 사용자 ID: ${account.id}');
        print('네이버 사용자 이메일: ${account.email}');
        print('네이버 사용자 이름: ${account.name}');
        
        final success = await _sendNaverUserDataToBackend(account);
        
        if (success) {
          print('✅ 네이버 백엔드 인증 성공!');
          return true;
        } else {
          print('❌ 백엔드 인증 실패');
          await FlutterNaverLogin.logOut();
          return false;
        }
      } else {
        print('❌ 네이버 로그인 취소 또는 실패');
        print('로그인 상태: ${result.status}');
        return false;
      }
    } catch (error, stackTrace) {
      print('❌ Naver Sign-In 에러 발생!');
      print('에러: $error');
      print('스택 트레이스: $stackTrace');
      return false;
    }
  }

  // Naver 사용자 데이터를 백엔드로 전송
  static Future<bool> _sendNaverUserDataToBackend(NaverAccountResult account) async {
    try {
      print('Naver 사용자 데이터 전송 중...');
      
      final response = await ApiService.oauthLogin(
        provider: 'naver',
        providerId: account.id,
        email: account.email,
        name: account.name,
        profileImageUrl: account.profileImage ?? '',
        nickname: account.nickname ?? account.name,
      );

      return await _processOAuthResponse(
        response: response,
        provider: 'naver',
        providerId: account.id,
        email: account.email,
        name: account.name,
        profileImageUrl: account.profileImage ?? '',
        nickname: account.nickname ?? account.name,
      );
    } catch (e) {
      print('Naver 백엔드 인증 에러: $e');
      return false;
    }
  }

  // OAuth 응답 공통 처리
  static Future<bool> _processOAuthResponse({
    required dynamic response,
    required String provider,
    required String providerId,
    required String email,
    required String name,
    required String profileImageUrl,
    required String nickname,
  }) async {
    try {
      print('백엔드 응답 상태: ${response.statusCode}');
      print('백엔드 응답 내용: ${response.data}');

      if (response.statusCode == 200) {
        final responseBody = response.data;
        
        String? accessToken;
        String? refreshToken;
        bool isNewUser = false;
        
        if (responseBody.containsKey('success') && responseBody.containsKey('data')) {
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
          accessToken = responseBody['accessToken'];
          refreshToken = responseBody['refreshToken'];
          isNewUser = responseBody['isNewUser'] ?? false;
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
            provider: provider,
            providerId: providerId,
            email: email,
            name: name,
            profileImageUrl: profileImageUrl,
            nickname: nickname,
            accessToken: accessToken,
            refreshToken: refreshToken,
            isNewUser: isNewUser,
          );
          await UserService.saveUserInfo(userInfo);

          // 백엔드에서 사용자 ID 조회 및 업데이트
          await UserService.fetchAndUpdateUserInfo();

          print('$provider 로그인 성공 - 신규 사용자: $isNewUser');
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
      print('OAuth 응답 처리 에러: $e');
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
    
    // 각 OAuth 제공자 로그아웃
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google 로그아웃 에러: $e');
    }
    
    try {
      await UserApi.instance.logout();
    } catch (e) {
      print('Kakao 로그아웃 에러: $e');
    }
    
    try {
      await FlutterNaverLogin.logOut();
    } catch (e) {
      print('Naver 로그아웃 에러: $e');
    }
  }

  // 랜덤 문자열 생성 (state 파라미터용)
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecond % chars.length])
        .join();
  }
}
