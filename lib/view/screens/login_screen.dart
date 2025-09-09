import 'package:flutter/material.dart';

import '../../services/oauth_service.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('로그인')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Naver 로그인 버튼
            ElevatedButton.icon(
              onPressed: () => OAuthService.startOAuthLogin('naver'),
              icon: Icon(Icons.login),
              label: Text('Naver로 로그인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Google 로그인 버튼
            ElevatedButton.icon(
              onPressed: () => OAuthService.startOAuthLogin('google'),
              icon: Icon(Icons.login),
              label: Text('Google로 로그인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Kakao 로그인 버튼
            ElevatedButton.icon(
              onPressed: () => OAuthService.startOAuthLogin('kakao'),
              icon: Icon(Icons.login),
              label: Text('Kakao로 로그인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
