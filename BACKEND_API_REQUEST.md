# 백엔드 API 문제 해결 요청

## 📋 문제 상황 (업데이트)

현재 앱에서 **디바이스(스마트폰 센서)로 측정한 수면 데이터**를 `/api/ml/sleep/analyze`로 전송하여 분석을 요청하고 있습니다.

분석 요청은 성공하고 `analysis_id`도 정상적으로 받으며, **DB에 데이터가 저장된 것도 확인**했습니다.

하지만 **`GET /api/ml/sleep/history`로 조회 시 404 에러**가 발생합니다.

### ✅ API 명세서 v3 확인 결과

프론트엔드 코드는 API 명세서와 **완벽하게 일치**합니다:
- ✅ 엔드포인트: `GET /api/ml/sleep/history`
- ✅ JWT Bearer 토큰 사용
- ✅ `user_id`는 JWT 토큰에서 자동 추출 (백엔드에서 처리)
- ✅ 쿼리 파라미터: `page`, `page_size`

**결론**: 프론트엔드 구현은 정상이며, **백엔드에서 JWT 토큰 파싱 또는 DB 조회에 문제가 있을 가능성이 높습니다**.

## 🔍 현재 상황

### ✅ 작동하는 API
- `POST /api/ml/sleep/analyze` - 디바이스 수면 데이터 분석 요청 (200 OK, analysis_id 반환)
- `POST /api/ml/wearable/analyze` - 웨어러블 수면 데이터 저장 (정상 작동)

### ❌ 문제가 있는 API
- `GET /api/ml/sleep/history` - 디바이스 수면 분석 이력 조회 (**404 에러 발생**)

## 📝 요청 사항

### 문제 1: `/api/ml/sleep/history`가 데이터를 반환하지 않음

#### 증상
- `POST /api/ml/sleep/analyze` 요청 시 200 OK 응답과 `analysis_id` 정상 반환
- 하지만 `GET /api/ml/sleep/history` 요청 시 404 에러 발생

#### 가능한 원인 (우선순위 순)

1. **JWT 토큰 파싱 문제** ⭐ (가장 가능성 높음)
   - 백엔드에서 JWT 토큰의 `user_id` 추출 실패
   - JWT 페이로드의 필드명 불일치 (`user_id` vs `userId` vs `sub`)
   - 백엔드가 다른 `user_id`로 조회하고 있을 가능성

2. **DB 조회 쿼리 문제**
   - DB에 데이터는 있지만, 조회 쿼리가 잘못됨
   - 테이블명 또는 컬럼명 오류

3. **테이블 불일치**
   - 저장하는 테이블과 조회하는 테이블이 다름

4. **엔드포인트 미구현**
   - `/api/ml/sleep/history`가 아직 구현되지 않음

#### 확인 요청

**1단계: JWT 토큰 파싱 확인** ⭐ (최우선)

백엔드 로그에서 다음을 확인해주세요:
```python
# FastAPI 백엔드에서 로그 추가 필요
@router.get("/sleep/history")
async def get_sleep_history(
    request: Request,
    page: int = 1,
    page_size: int = 10
):
    # JWT 토큰에서 추출한 user_id 로깅
    user_id = extract_user_id_from_jwt(request)
    print(f"🔍 [DEBUG] JWT에서 추출한 user_id: {user_id}")
    print(f"🔍 [DEBUG] 조회 쿼리: SELECT * FROM sleep_analysis WHERE user_id = '{user_id}'")
    
    # DB 조회
    results = db.query(...).filter(user_id=user_id).all()
    print(f"🔍 [DEBUG] 조회된 데이터 수: {len(results)}")
    
    return results
```

**2단계: DB 직접 확인**

```sql
-- 1. DB에 저장된 모든 수면 분석 데이터 확인
SELECT user_id, analysis_id, analysis_timestamp, recording_start, recording_end
FROM sleep_analysis 
ORDER BY analysis_timestamp DESC
LIMIT 10;

-- 2. 특정 user_id로 조회 (앱에서 로그로 출력된 user_id 사용)
SELECT * FROM sleep_analysis 
WHERE user_id = '1e1b975a-e763-4db3-93d3-cccb10b87d82'
ORDER BY analysis_timestamp DESC;

-- 3. 최근 분석 ID로 직접 조회 (앱 로그에서 확인한 analysis_id)
SELECT * FROM sleep_analysis 
WHERE analysis_id = '[앱에서 받은 analysis_id]';
```

**3단계: JWT 페이로드 구조 확인**

프론트엔드에서 전송하는 JWT 토큰의 페이로드 구조:
```json
{
  "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",  // 또는 "userId" 또는 "sub"
  "iat": 1730019600,
  "exp": 1730106000
}
```

백엔드에서 어떤 필드명으로 `user_id`를 추출하고 있는지 확인 필요!

### 문제 2: 웨어러블 데이터 조회 API 부재 (낮은 우선순위)

웨어러블 데이터는 현재 정상 작동 중이지만, 조회 API가 없어 향후 필요할 수 있습니다.

#### 제안 API: `GET /api/ml/wearable/history`

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/wearable/history` |
| **Authentication** | JWT Bearer 토큰 필요 |

**Response (제안):**
```json
{
  "analyses": [
    {
      "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "1e1b975a-e763-4db3-93d3-cccb10b87d82",
      "device_type": "apple_watch",
      "sleep_start": "2025-10-28T14:00:00Z",
      "sleep_end": "2025-10-29T21:30:00Z",
      "analysis_timestamp": "2025-10-29T06:15:30Z"
    }
  ],
  "total_count": 25,
  "page": 1,
  "page_size": 10
}
```

## 🔍 디버깅 정보

### 현재 사용자 정보
- **user_id**: `1e1b975a-e763-4db3-93d3-cccb10b87d82`
- **JWT 토큰 길이**: 188자

### DB 확인 쿼리 (백엔드 개발자용)

```sql
-- 웨어러블 수면 분석 데이터 확인
SELECT * FROM wearable_sleep_analysis 
WHERE user_id = '1e1b975a-e763-4db3-93d3-cccb10b87d82'
ORDER BY sleep_start DESC;

-- 또는 테이블명이 다를 경우
SELECT * FROM sleep_analysis 
WHERE user_id = '1e1b975a-e763-4db3-93d3-cccb10b87d82' 
  AND source = 'wearable'
ORDER BY analysis_timestamp DESC;
```

## 🧪 테스트 방법

### 1단계: 디바이스 수면 분석 실행
1. 앱에서 "수면 측정 시작" 버튼 클릭
2. 최소 1시간 이상 측정
3. "측정 종료" 버튼 클릭
4. 홈 화면에서 "오늘 수면 분석하기" 버튼 클릭

### 2단계: 로그 확인
콘솔에서 다음 정보를 확인하세요:
```
✅ ========== 디바이스 수면 분석 성공 ==========
ApiService - 분석 ID: [여기에 analysis_id가 표시됨]
ApiService - 사용자 ID: 1e1b975a-e763-4db3-93d3-cccb10b87d82
```

### 3단계: DB 확인 (백엔드 개발자)
위에서 확인한 `analysis_id`로 DB를 조회하세요:
```sql
SELECT * FROM sleep_analysis 
WHERE analysis_id = '[로그에서 확인한 analysis_id]';
```

### 4단계: 데이터 조회 테스트
앱에서 "수면 데이터 확인하기" 버튼을 눌러 404 에러가 발생하는지 확인

## 🎯 임시 해결책

API 수정 전까지는 다음과 같이 대응합니다:

1. **로컬 저장소 활용**: 앱에서 분석 ID를 로컬에 저장하고 필요 시 `GET /api/ml/sleep/result/{analysis_id}`로 개별 조회
2. **개별 조회 API 사용**: 분석 성공 시 받은 `analysis_id`를 저장하여 개별 조회

## ⏰ 우선순위

**중요도**: 높음 (High)  
**이유**: 
- 디바이스로 측정한 수면 데이터를 조회할 수 없어 핵심 기능이 작동하지 않음
- 분석은 성공하지만 저장된 데이터를 확인할 방법이 없음

---

**작성일**: 2025-01-15  
**작성자**: Frontend Developer (Flutter)

