import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/oauth_button_config.dart';
import '../const/login_constants.dart';
import '../services/oauth_service.dart';
import '../services/user_service.dart';

class OAuthButton extends StatelessWidget {
  final OAuthButtonConfig config;

  const OAuthButton({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: LoginConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: () async {
          // 네이버 로그인인 경우 비활성화 메시지 표시
          if (config.provider == 'naver') {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('현재 문제가 생겨 네이버 로그인이 불가능합니다.\n다른 로그인 방법을 이용해주세요.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }

          try {
            final success = await OAuthService.startOAuthLogin(config.provider);
            if (success && context.mounted) {
              // 사용자 정보 불러오기
              final userInfo = await UserService.loadUserInfo();
              
              if (userInfo != null) {
                // 신규 사용자인 경우 추가 정보 입력 화면으로 이동
                // 기존 사용자인 경우 홈 화면으로 이동
                if (userInfo.isNewUser) {
                  print('신규 사용자: 추가 정보 입력 화면으로 이동');
                  // TODO: 추가 정보 입력 화면이 있다면 해당 경로로 이동
                  // context.go('/additional-info');
                  // 현재는 추가 정보 입력 화면이 없으므로 홈 화면으로 이동
                  context.go('/btNavi');
                } else {
                  print('기존 사용자: 홈 화면으로 이동');
                  context.go('/btNavi');
                }
              } else {
                // 사용자 정보가 없으면 홈 화면으로 이동 (기본 동작)
                context.go('/btNavi');
              }
            }
          } catch (e) {
            print('로그인 에러: $e');
            if (context.mounted) {
              String errorMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
              
              // 네이버 로그인 관련 에러인 경우 특별한 메시지 표시
              if (e.toString().contains('네이버 로그인이 불가능합니다')) {
                errorMessage = '현재 문제가 생겨 네이버 로그인이 불가능합니다.\n다른 로그인 방법을 이용해주세요.';
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: config.provider == 'naver' 
              ? config.backgroundColor.withOpacity(0.5) 
              : config.backgroundColor,
          foregroundColor: config.provider == 'naver' 
              ? config.textColor.withOpacity(0.5) 
              : config.textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoginConstants.buttonRadius),
          ),
          elevation: 0,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Image.asset(
                config.iconPath,
                width: LoginConstants.iconSize,
                height: LoginConstants.iconSize,
                errorBuilder: (context, error, stackTrace) {
                  // 이미지 로드 실패시 대체 아이콘 표시
                  return Container(
                    width: LoginConstants.iconSize,
                    height: LoginConstants.iconSize,
                    decoration: BoxDecoration(
                      color: config.textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      color: config.textColor,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            Center(
              child: Text(
                config.provider == 'naver' 
                    ? '네이버 로그인 (현재 불가능)' 
                    : config.text,
                style: LoginConstants.buttonTextStyle.copyWith(
                  color: config.provider == 'naver' 
                      ? config.textColor.withOpacity(0.5) 
                      : config.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
