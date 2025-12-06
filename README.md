# 🌙 NEULBO (쿨쿨)

수면 분석 AI 서비스를 제공하는 Flutter 기반 모바일 애플리케이션입니다.

## 📱 프로젝트 개요

NEULBO는 스마트폰 센서와 웨어러블 기기를 활용하여 사용자의 수면 패턴을 분석하고, AI 기반 피드백을 제공하는 수면 관리 앱입니다. 커뮤니티 기능을 통해 친구들과 수면 점수를 공유하고 함께 건강한 수면 습관을 만들어갈 수 있습니다.

## ✨ 주요 기능

### 🛌 수면 추적 및 분석
- **스마트폰 센서 기반 측정**: 가속도계와 마이크를 활용한 실시간 수면 데이터 수집
- **웨어러블 기기 연동**: Apple Watch (HealthKit) 데이터 연동 지원
- **ML 기반 수면 단계 분석**: XGBoost 모델을 통한 수면 단계 예측 (깊은 수면, REM 수면, 얕은 수면 등)
- **수면 그래프 시각화**: 수면 단계별 시간대별 그래프 제공

### 🤖 AI 피드백
- **LLM 기반 수면 개선 조언**: 수면 패턴 분석 결과를 바탕으로 맞춤형 피드백 제공
- **수면 AI 챗봇**: 실시간으로 수면 관련 질문에 답변

### 👥 커뮤니티
- **게시글 작성 및 조회**: 카테고리별 게시글 작성 및 피드 조회
- **댓글 및 좋아요**: 게시글에 댓글 작성 및 좋아요 기능
- **친구 관리**: 친구 추가, 요청 관리, 친구 찾기
- **수면 점수 공유**: 친구들의 수면 점수 및 통계 확인

### 🔐 인증
- **소셜 로그인**: 카카오, 네이버, 구글 OAuth 로그인 지원
- **JWT 기반 인증**: 안전한 토큰 기반 인증 시스템

## 🛠️ 기술 스택

### Frontend
- **Flutter** 3.4.0+
- **Dart** SDK
- **상태 관리**: Riverpod
- **라우팅**: GoRouter
- **HTTP 통신**: Dio, http

### 주요 패키지
- `health`: HealthKit 연동 (iOS)
- `sensors_plus`: 가속도계 센서 데이터 수집
- `mic_stream`: 실시간 오디오 스트림
- `flutter_secure_storage`: 안전한 토큰 저장
- `shared_preferences`: 로컬 데이터 저장
- `google_sign_in`, `kakao_flutter_sdk_user`: 소셜 로그인

### Backend
- **NEULBO-ML-SERVER**: FastAPI 기반 ML 수면 분석 서버
- **NEULBO-SERVER**: Spring Boot 기반 사용자 관리 및 커뮤니티 서버

## 📁 프로젝트 구조

```
lib/
├── const/              # 상수 정의 (색상, 디자인, 라우트 등)
├── models/             # 데이터 모델
│   ├── sleep_data.dart
│   ├── sleep_recording_data.dart
│   ├── post.dart
│   ├── friend.dart
│   └── ...
├── services/           # 비즈니스 로직 및 API 통신
│   ├── api_service.dart
│   ├── sleep_recording_service.dart
│   ├── sleep_data_service.dart
│   ├── health_service.dart
│   ├── oauth_service.dart
│   ├── post_service.dart
│   ├── friend_service.dart
│   └── ...
└── view/               # UI 화면
    ├── screens/        # 화면 컴포넌트
    │   ├── home_screen.dart
    │   ├── sleep_tracking_screen.dart
    │   ├── community_screen.dart
    │   └── ...
    ├── features/       # 기능별 컴포넌트
    └── widgets/        # 재사용 가능한 위젯
```

## 🚀 시작하기

### 필수 요구사항
- Flutter SDK 3.4.0 이상
- Dart SDK
- iOS 개발: Xcode 14.0 이상
- Android 개발: Android Studio, Android SDK

### 설치 및 실행

1. **저장소 클론**
   ```bash
   git clone <repository-url>
   cd neulbo
   ```

2. **의존성 설치**
   ```bash
   flutter pub get
   ```

3. **환경 변수 설정**
   - 프로젝트 루트에 `.env` 파일 생성
   - 필요한 API 키 및 설정 값 추가:
     ```
     KAKAO_NATIVE_APP_KEY=your_kakao_app_key
     API_BASE_URL=your_api_base_url
     ```

4. **iOS 설정** (iOS 개발 시)
   ```bash
   cd ios
   pod install
   cd ..
   ```

5. **앱 실행**
   ```bash
   flutter run
   ```

## 📱 주요 화면

- **홈 화면**: 오늘의 수면 데이터 및 통계 표시
- **수면 측정 화면**: 실시간 센서 데이터 수집 및 측정
- **수면 분석 화면**: ML 분석 결과 및 그래프 시각화
- **커뮤니티 화면**: 게시글 피드 및 친구 목록
- **친구 관리 화면**: 친구 추가, 요청 관리
- **내 정보 화면**: 프로필 및 설정 관리
- **수면 AI 화면**: AI 챗봇과의 대화

## 🔧 개발 가이드

### 코드 스타일
- Dart 기본 코딩 컨벤션 준수
- Clean Architecture 패턴 적용
- Repository 패턴 사용
- Controller 패턴으로 비즈니스 로직 관리

### 주요 서비스 설명

#### SleepRecordingService
스마트폰 센서를 활용한 수면 데이터 수집 서비스
- 가속도계 데이터 수집
- 오디오 데이터 수집
- 데이터 통합 및 저장

#### HealthService
HealthKit 연동을 통한 웨어러블 기기 데이터 수집
- Apple Watch 수면 데이터 가져오기
- 권한 관리

#### ApiService
백엔드 서버와의 통신 관리
- JWT 토큰 자동 관리
- API 요청/응답 처리
- 에러 핸들링

## 📚 문서

- [API 명세서](documents/api%20명세서%20v3.md)
- [디바이스 수면 추적 구현 가이드](DEVICE_SLEEP_TRACKING_IMPLEMENTATION.md)
- [HealthKit 설정 가이드](documents/HEALTHKIT_SETUP_GUIDE.md)
- [데이터 흐름 검증](documents/DATA_FLOW_VERIFICATION.md)

## 🔒 보안

- JWT 토큰은 `flutter_secure_storage`를 통해 안전하게 저장
- OAuth 인증을 통한 안전한 로그인
- 민감한 정보는 환경 변수로 관리

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.

## 👥 팀

NEULBO 개발팀

---

**쿨쿨과 함께 건강한 수면 습관을 만들어보세요! 🌙✨**
