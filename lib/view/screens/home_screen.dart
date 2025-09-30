import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NEULBO',
          style: TextStyle(
            fontFamily: 'malang',
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.blue[50],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // 환영 메시지
            const Text(
              '안녕하세요! 👋',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'malang',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '좋은 수면을 위한 여정을 시작해보세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'suit',
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 수면 데이터 연동 데모 버튼
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.health_and_safety,
                          size: 32,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'iOS 건강 앱 연동',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'suit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'iPhone 건강 앱의 수면 데이터를 가져와서\n개인 맞춤형 수면 분석을 받아보세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontFamily: 'suit',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/sleep-data-demo');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'HealthKit 연동 시작하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'suit',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 추가 기능들 (향후 개발 예정)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '곧 만날 수 있는 기능들',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'suit',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem('🎵', '수면 음악 추천', '수면 패턴에 맞는 음악을 추천해드려요'),
                    _buildFeatureItem('🤖', 'AI 수면 코치', '개인 맞춤형 수면 개선 조언을 받아보세요'),
                    _buildFeatureItem('👥', '수면 커뮤니티', '다른 사용자들과 수면 경험을 공유해보세요'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'suit',
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFamily: 'suit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
