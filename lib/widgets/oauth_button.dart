import 'package:flutter/material.dart';
import '../models/oauth_button_config.dart';
import '../const/login_constants.dart';
import '../services/oauth_service.dart';

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
        onPressed: () => OAuthService.startOAuthLogin(config.provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: config.backgroundColor,
          foregroundColor: config.textColor,
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
                config.text,
                style: LoginConstants.buttonTextStyle.copyWith(
                  color: config.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
