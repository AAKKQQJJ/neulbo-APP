import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/user_info.dart';

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
}
