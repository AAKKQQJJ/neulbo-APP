import 'package:flutter/material.dart';

class LoginConstants {
  // 색상
  static const Color naverColor = Color(0xFF06BE34);
  static const Color googleBackgroundColor = Color(0xFFECF1FD);
  static const Color kakaoColor = Color(0xFFFFEB3B);
  static const Color footerSecondaryColor = Color(0xFFF0E9FF);

  // 크기
  static const double buttonHeight = 54.0;
  static const double iconSize = 40.0;
  static const double buttonRadius = 12.0;
  
  // 텍스트 스타일
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 48,
    fontFamily: 'malang',
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );
  
  static const TextStyle subtitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontFamily: 'suit',
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontFamily: 'suit',
    fontWeight: FontWeight.w800,
  );
  
  static const TextStyle footerPrimaryStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontFamily: 'suit',
    fontWeight: FontWeight.w800,
  );
  
  static const TextStyle footerSecondaryStyle = TextStyle(
    color: footerSecondaryColor,
    fontSize: 10,
    fontFamily: 'suit',
    fontWeight: FontWeight.w600,
  );

  // 아이콘 경로
  static const String naverIconPath = 'asset/img/naver_icon.png';
  static const String googleIconPath = 'asset/img/google_icon.png';
  static const String kakaoIconPath = 'asset/img/kakao_icon.png';
  static const String backgroundImagePath = 'asset/img/login_background_img.png';

  // 텍스트 상수
  static const String appTitle = '쿨쿨';
  static const String subtitleOne = '더 길고 포근한 잠을 위한';
  static const String subtitleTwo = '똑똑한 수면 관리, 쿨쿨';
  static const String naverLoginText = '네이버로 로그인';
  static const String googleLoginText = '구글로 로그인';
  static const String kakaoLoginText = '카카오로 로그인';
  static const String browseWithoutLoginText = '로그인 없이 둘러보기';
  static const String termsText = '서비스 이용약관 및 개인정보 수집 이용';
}
