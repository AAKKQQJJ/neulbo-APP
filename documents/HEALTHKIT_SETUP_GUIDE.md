# iOS HealthKit 수면 데이터 연동 설정 가이드

## 📋 개요

이 가이드는 iOS HealthKit과 연동하여 수면 데이터를 가져오는 기능의 설정과 사용법을 설명합니다.

## 🛠️ 설정 완료 사항

### 1. 플러그인 설치
- `health: ^10.2.0` 플러그인이 `pubspec.yaml`에 추가되었습니다.

### 2. iOS 권한 설정
`ios/Runner/Info.plist`에 다음 권한이 추가되었습니다:
```xml
<key>NSHealthShareUsageDescription</key>
<string>수면 패턴 분석 및 개인 맞춤형 수면 도움을 위해 건강 앱의 수면 데이터에 접근합니다.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>수면 기록을 업데이트하여 더 나은 수면 분석을 제공합니다.</string>
```

### 3. 생성된 파일들

#### 📁 서비스 파일들
- `lib/services/health_service.dart` - HealthKit 연동 기본 서비스
- `lib/services/sleep_data_service.dart` - 수면 데이터 통합 관리 서비스
- `lib/services/api_service.dart` - 서버 API 통신 (수면 데이터 API 추가)

#### 📁 모델 파일들
- `lib/models/sleep_data.dart` - 수면 데이터 모델 클래스

#### 📁 화면 파일들
- `lib/view/screens/sleep_data_demo_screen.dart` - HealthKit 연동 데모 화면
- `lib/view/screens/home_screen.dart` - 홈 화면 (데모 버튼 추가)

#### 📁 라우팅
- `lib/const/routes.dart` - 데모 화면 라우트 추가

## 🚀 사용 방법

### 1. 앱 실행 및 데모 화면 접근
1. 앱을 실행합니다
2. 홈 화면에서 "HealthKit 연동 시작하기" 버튼을 클릭합니다
3. 수면 데이터 연동 데모 화면으로 이동합니다

### 2. HealthKit 권한 허용
1. "HealthKit 권한 요청" 버튼을 클릭합니다
2. iOS에서 권한 요청 팝업이 나타나면 "허용"을 선택합니다
3. 수면 관련 데이터 항목들을 모두 허용합니다

### 3. 수면 데이터 가져오기
1. 권한 허용 후 "수면 데이터 가져오기" 버튼을 클릭합니다
2. 최근 7일간의 수면 데이터가 표시됩니다
3. 각 수면 데이터 카드에서 다음 정보를 확인할 수 있습니다:
   - 수면 날짜
   - 수면 품질 점수 (A~F 등급)
   - 총 수면시간
   - 취침시간 / 기상시간
   - 수면 효율성
   - 깊은잠 / REM 수면 비율

### 4. 서버 동기화
1. "서버 동기화" 버튼을 클릭합니다
2. 가져온 수면 데이터가 백엔드 서버로 전송됩니다

## 🔧 주요 기능

### HealthService 클래스
```dart
// HealthKit 권한 요청
await HealthService().requestHealthPermissions();

// 수면 데이터 가져오기
final sleepData = await HealthService().getSleepData(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);
```

### SleepDataService 클래스
```dart
// HealthKit 초기화
await SleepDataService().initializeHealthKit();

// 수면 데이터 동기화
await SleepDataService().syncWeeklySleepData();

// 상태 확인
final status = await SleepDataService().checkSleepDataStatus();
```

### SleepData 모델
```dart
// 수면 데이터 접근
print('총 수면시간: ${sleepData.formattedTotalSleepTime}');
print('수면 품질: ${sleepData.sleepQualityGrade}');
print('수면 효율: ${sleepData.sleepEfficiency}%');
```

## 🎯 수집되는 수면 데이터 타입

- `SLEEP_IN_BED` - 침대에 있던 시간
- `SLEEP_ASLEEP` - 실제 수면 시간
- `SLEEP_AWAKE` - 수면 중 깬 시간
- `SLEEP_DEEP` - 깊은 잠 시간
- `SLEEP_LIGHT` - 얕은 잠 시간
- `SLEEP_REM` - REM 수면 시간

## 🔮 향후 백엔드 API 엔드포인트

현재 구현된 API 메서드들이 백엔드에서 구현되어야 합니다:

```
POST /api/v1/sleep/upload - 수면 데이터 업로드
POST /api/v1/sleep/upload-batch - 여러 수면 데이터 일괄 업로드
GET /api/v1/sleep/data - 수면 데이터 조회
GET /api/v1/sleep/statistics - 수면 통계 조회
POST /api/v1/sleep/goal - 수면 목표 설정
GET /api/v1/sleep/goal - 수면 목표 조회
GET /api/v1/sleep/analysis - 수면 분석 리포트 조회
POST /api/v1/sleep/healthkit-status - HealthKit 연동 상태 업데이트
```

## ⚠️ 주의사항

1. **실제 iOS 기기에서만 테스트 가능**: 시뮬레이터에서는 HealthKit 데이터를 사용할 수 없습니다.

2. **건강 앱 데이터 필요**: iPhone의 건강 앱에 수면 데이터가 기록되어 있어야 합니다.

3. **개발자 계정 필요**: HealthKit을 사용하려면 Apple Developer 계정이 필요할 수 있습니다.

4. **백엔드 API 구현 필요**: 현재 API 서비스는 프론트엔드만 구현되어 있으며, 백엔드 엔드포인트는 별도로 구현해야 합니다.

## 🐛 문제 해결

### 권한 요청이 나타나지 않는 경우
1. iOS 설정 > 개인정보 보호 및 보안 > 건강에서 앱 권한을 확인합니다
2. 앱을 삭제 후 재설치해봅니다

### 수면 데이터가 없는 경우
1. iPhone의 건강 앱에서 수면 데이터가 기록되어 있는지 확인합니다
2. Apple Watch나 다른 연동된 기기에서 수면 데이터를 수집하고 있는지 확인합니다

### 빌드 오류 발생 시
1. `flutter clean` 후 `flutter pub get`을 실행합니다
2. iOS 프로젝트를 Xcode에서 Clean Build Folder를 실행합니다

## 📱 테스트 방법

1. **실제 iOS 기기에서 앱 실행**
2. **건강 앱에 수면 데이터 추가** (Apple Watch 착용 또는 수동 입력)
3. **앱에서 권한 허용 후 데이터 확인**
4. **서버 동기화 테스트** (백엔드 구현 후)

---

**참고**: 이 설정은 iOS HealthKit 연동을 위한 기본 구조를 제공합니다. 실제 운영 환경에서는 보안, 개인정보 보호, 오류 처리 등을 추가로 고려해야 합니다.
