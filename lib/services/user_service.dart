import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/user_info.dart';
import 'api_service.dart';

class UserService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _userInfoKey = 'user_info';
  
  static UserInfo? _currentUser;

  /// 현재 사용자 정보 가져오기
  static UserInfo? get currentUser => _currentUser;

  /// 사용자 정보 저장
  static Future<void> saveUserInfo(UserInfo userInfo) async {
    _currentUser = userInfo;
    final userJson = json.encode(userInfo.toJson());
    await _storage.write(key: _userInfoKey, value: userJson);
  }

  /// 저장된 사용자 정보 불러오기
  static Future<UserInfo?> loadUserInfo() async {
    try {
      final userJson = await _storage.read(key: _userInfoKey);
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = UserInfo.fromJson(userMap);
        return _currentUser;
      }
    } catch (e) {
      print('사용자 정보 불러오기 실패: $e');
    }
    return null;
  }

  /// 사용자 정보 삭제 (로그아웃)
  static Future<void> clearUserInfo() async {
    _currentUser = null;
    await _storage.delete(key: _userInfoKey);
  }

  /// 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    final userInfo = await loadUserInfo();
    return userInfo != null;
  }

  /// 사용자 닉네임 가져오기
  static String getUserNickname() {
    return _currentUser?.nickname ?? '사용자';
  }

  /// 사용자 이메일 가져오기
  static String getUserEmail() {
    return _currentUser?.email ?? '';
  }

  /// 사용자 프로필 이미지 URL 가져오기
  static String getUserProfileImageUrl() {
    return _currentUser?.profileImageUrl ?? '';
  }

  /// 사용자 ID 가져오기 (백엔드 userId 우선, 없으면 providerId 사용)
  static String? getUserId() {
    return _currentUser?.userId ?? _currentUser?.providerId;
  }

  /// 사용자 Provider 가져오기
  static String? getUserProvider() {
    return _currentUser?.provider;
  }

  /// Provider ID 가져오기
  static String? getProviderId() {
    return _currentUser?.providerId;
  }

  /// 백엔드에서 사용자 정보 조회 및 업데이트
  /// 로그인 후 호출하여 백엔드의 userId를 가져와 저장
  static Future<bool> fetchAndUpdateUserInfo() async {
    try {
      if (_currentUser == null) {
        print('UserService - 현재 사용자 정보가 없습니다.');
        return false;
      }

      // 백엔드에서 사용자 계정 정보 조회
      final response = await ApiService.getUserAccount();
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // API 명세서에 따른 응답 구조 처리
        String? userId;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            final data = responseData['data'];
            userId = data['id'] as String?;
          }
        }

        if (userId != null) {
          // 기존 사용자 정보에 userId 추가하여 업데이트
          final updatedUserInfo = UserInfo(
            userId: userId,
            provider: _currentUser!.provider,
            providerId: _currentUser!.providerId,
            email: _currentUser!.email,
            name: _currentUser!.name,
            profileImageUrl: _currentUser!.profileImageUrl,
            nickname: _currentUser!.nickname,
            accessToken: _currentUser!.accessToken,
            refreshToken: _currentUser!.refreshToken,
            isNewUser: _currentUser!.isNewUser,
          );
          
          await saveUserInfo(updatedUserInfo);
          print('UserService - 사용자 ID 업데이트 완료: $userId');
          return true;
        } else {
          print('UserService - 백엔드 응답에서 userId를 찾을 수 없습니다.');
          return false;
        }
      } else {
        print('UserService - 사용자 정보 조회 실패: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('UserService - 사용자 정보 조회 중 오류: $error');
      return false;
    }
  }
}
