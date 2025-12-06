import 'package:flutter/material.dart';

import '../const/design_constants.dart';
import '../const/login_constants.dart';

class OAuthButtonConfig {
  final String provider;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final String iconPath;

  const OAuthButtonConfig({
    required this.provider,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.iconPath,
  });

  // 미리 정의된 설정들
  static const List<OAuthButtonConfig> defaultConfigs = [
    OAuthButtonConfig(
      provider: 'naver',
      text: LoginConstants.naverLoginText,
      backgroundColor: LoginConstants.naverColor,
      textColor: Colors.white,
      iconPath: DesignConstants.naverIconPath,
    ),
    OAuthButtonConfig(
      provider: 'google',
      text: LoginConstants.googleLoginText,
      backgroundColor: LoginConstants.googleBackgroundColor,
      textColor: Colors.black87,
      iconPath: DesignConstants.googleIconPath,
    ),
    OAuthButtonConfig(
      provider: 'kakao',
      text: LoginConstants.kakaoLoginText,
      backgroundColor: LoginConstants.kakaoColor,
      textColor: Colors.black87,
      iconPath: DesignConstants.kakaoIconPath,
    ),
  ];
}
