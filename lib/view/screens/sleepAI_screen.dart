import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../const/design_constants.dart';
import 'sleep_chat_screen.dart';

class SleepaiScreen extends StatelessWidget {
  const SleepaiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 반응형 배경 이미지
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(DesignConstants.defaultBackgroundPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    onError: (exception, stackTrace) {
                      print('수면 AI 배경 이미지 로드 실패: $exception');
                    },
                  ),
                  // 이미지가 작을 경우를 대비한 fallback 색상
                  color: const Color(0xFF2D1B69),
                ),
                child: Container(
                  // 이미지 위에 약간의 오버레이 (선택사항)
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 콘텐츠 - 화면 중앙
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 그라데이션 텍스트 1줄
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFEDE2FF),
                            Color(0xFFAF99FF),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds);
                      },
                      child: const Text(
                        '궁금하신 수면 정보,',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'suit',
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // 그라데이션 텍스트 2줄
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFEDE2FF),
                            Color(0xFFAF99FF),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds);
                      },
                      child: const Text(
                        '지금 바로 알려드릴게요!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'suit',
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 설명 텍스트
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        '수면 패턴, 꿀잠 방법, 어떤 정보든 알고 싶으신 걸 말씀해주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontFamily: 'suit',
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 질문하기 버튼
                    ElevatedButton(
                      onPressed: () {
                        // 채팅 화면으로 이동
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SleepChatScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFAF99FF),
                        foregroundColor: const Color(0xFF2D1B69),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            '질문하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'suit',
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
