# NEULBO API 명세서

## 개요
NEULBO 프로젝트는 수면 분석 AI 서비스를 제공하는 시스템으로, 두 개의 주요 서버로 구성됩니다:
- **NEULBO-ML-SERVER**: FastAPI 기반 ML 수면 분석 서버 (스마트폰 센서 분석 + 웨어러블 기기 데이터 처리)
- **NEULBO-SERVER**: Spring Boot 기반 사용자 관리 및 음악 스트리밍 서버

### 🔄 이중 데이터 아키텍처
NEULBO는 두 가지 수면 데이터 소스를 지원합니다:

1. **스마트폰 센서 기반 분석** (`/api/ml/sleep/*`)
   - 가속도계, 마이크 등 스마트폰 센서 데이터를 실시간 분석
   - XGBoost ML 모델을 통한 수면 단계 예측
   - 원시 센서 데이터부터 완전한 분석 파이프라인 제공

2. **웨어러블 기기 데이터 처리** (`/api/ml/wearable/*`)
   - Apple Watch (HealthKit), Galaxy Watch (Samsung Health) 등에서 사전 분석된 데이터 활용
   - 심박수, 수면 단계, 움직임 데이터 통합 처리
   - 웨어러블 앱에서 이미 분석된 고품질 수면 데이터 활용

두 시스템 모두 동일한 LLM 피드백 엔진을 통해 일관된 수면 개선 조언을 제공합니다.

## 서버 구성

### 도메인 및 프록시 설정
- **Base URL**: `https://neulbo1.com`
- **ML 서버**: `/api/ml/*` → `localhost:8000`
- **Spring Boot 서버**: `/api/v1/*` → `localhost:8080`

---

## 1. NEULBO-ML-SERVER (FastAPI)

### 1.1 헬스체크 API

#### GET /api/ml/health/check
시스템 헬스체크

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/health/check` |
| **Authentication** | 불필요 |
| **Content-Type** | N/A |

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/health/check"
```

**Response:**

**Success Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-19T10:30:00.123456",
  "version": "1.0.0",
  "database_status": "healthy",
  "model_status": "healthy"
}
```

**Fail Response (500 Internal Server Error):**
```json
{
  "error_code": "INTERNAL_SERVER_ERROR",
  "error_message": "헬스체크 실패",
  "timestamp": "2025-10-19T10:30:00.123456",
  "request_id": "abc12345-def6-7890-abcd-ef1234567890"
}
```

---

#### GET /api/ml/health/detailed
상세 헬스체크 정보

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/health/detailed` |
| **Authentication** | 불필요 |
| **Content-Type** | N/A |

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/health/detailed"
```

**Response:**

**Success Response (200 OK):**
```json
{
  "timestamp": "2025-10-02T06:54:57.032830",
  "app_version": "1.0.0",
  "environment": "development",
  "database": {
    "active_users": 15,
    "cpu_usage": 45.2,
    "memory_usage": 67.8,
    "disk_usage": 23.1,
    "active_analysis_count": 3,
    "last_health_check": "2025-10-02T06:54:45.123456"
  },
  "models": {
    "model_name": "XGBoost Sleep Stage Classifier",
    "model_version": "1.2.3",
    "is_ready": true
  },
  "configuration": {
    "model_confidence_threshold": 0.7,
    "max_recording_duration": 43200,
    "min_recording_duration": 3600,
    "stage_interval_seconds": 30
  }
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 500 | INTERNAL_SERVER_ERROR | 서버 내부 오류로 인한 메트릭 조회 실패 |
| 503 | SERVICE_UNAVAILABLE | 데이터베이스 연결 실패 |

**Error Response Example (500 Internal Server Error):**
```json
{
  "error_code": "HTTP_500",
  "error_message": "시스템 메트릭 조회 실패",
  "timestamp": "2025-10-02T06:54:57.032830",
  "request_id": "req_123457"
}
```

#### GET /api/ml/health/metrics
시스템 메트릭스 조회

**Request:**
- **Headers:** 없음
- **Query Parameters:**
  - `period` (string, optional): 조회 기간 (기본값: "24hours", 가능값: "1hour", "6hours", "24hours", "7days")
- **Request Body:** 없음

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/ml/health/metrics?period=24hours"
```

**Response:**

**Success Response (200 OK):**
```json
{
  "timestamp": "2025-10-02T06:54:57.032830",
  "period": "24hours",
  "metrics": {
    "cpu_usage": {
      "average": 42.5,
      "current": 45.2
    },
    "memory_usage": {
      "average": 65.3,
      "current": 67.8
    },
    "disk_usage": {
      "average": 21.7,
      "current": 23.1
    },
    "total_data_points": 1440
  }
}
```

**Error Response Example (400 Bad Request):**
```json
{
  "error_code": "HTTP_400",
  "error_message": "잘못된 period 값입니다. 허용값: 1hour, 6hours, 24hours, 7days",
  "timestamp": "2025-10-02T06:54:57.032830",
  "request_id": "req_123458"
}
```

---

#### POST /api/ml/health/record-metrics
시스템 메트릭스 기록

**Request:**
- **Headers:** 
  - `Content-Type: application/json`
- **Query Parameters:** 없음
- **Request Body:**
```json
{
  "cpu_usage": 45.2,
  "memory_usage": 67.8,
  "disk_usage": 23.1
}
```

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/ml/health/record-metrics" \
  -H "Content-Type: application/json" \
  -d '{
    "cpu_usage": 45.2,
    "memory_usage": 67.8,
    "disk_usage": 23.1
  }'
```

**Response:**

**Success Response (201 Created):**
```json
{
  "message": "메트릭스 기록 완료",
  "timestamp": "2025-10-02T06:54:57.032830"
}
```

**Error Response Example (400 Bad Request):**
```json
{
  "error_code": "HTTP_400", 
  "error_message": "CPU 사용률은 0-100 범위여야 합니다",
  "timestamp": "2025-10-02T06:54:57.032830",
  "request_id": "req_123459"
}
```

### 1.2 수면 분석 API

#### POST /api/ml/sleep/analyze
수면 데이터 분석 (JWT 인증)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/ml/sleep/analyze` |
| **Authentication** | JWT Bearer 토큰 필요 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {JWT_TOKEN}` (Spring Boot에서 발급된 토큰) |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| ~~`user_id`~~ | ~~string~~ | ~~✅~~ | ~~사용자 식별자~~ **JWT 토큰에서 자동 추출** |
| `recording_start` | datetime | ✅ | 녹음 시작 시간 (ISO 8601) |
| `recording_end` | datetime | ✅ | 녹음 종료 시간 (ISO 8601) |
| `accelerometer_data` | array | ✅ | 가속도계 센서 데이터 |
| `audio_data` | array | ✅ | 오디오 센서 데이터 |

**Request Example:**
```bash
curl -X POST "http://localhost:8000/api/ml/sleep/analyze" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "recording_start": "2025-10-01T22:00:00",
    "recording_end": "2025-10-02T06:00:00",
    "accelerometer_data": [
      {
        "timestamp": "2025-10-01T22:00:00",
        "x": -0.123,
        "y": 0.456,
        "z": 9.789
      },
      {
        "timestamp": "2025-10-01T22:00:30",
        "x": -0.098,
        "y": 0.423,
        "z": 9.812
      }
    ],
    "audio_data": [
      {
        "timestamp": "2025-10-01T22:00:00",
        "amplitude": 0.15,
        "frequency_bands": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
      },
      {
        "timestamp": "2025-10-01T22:00:30",
        "amplitude": 0.12,
        "frequency_bands": [0.08, 0.18, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75]
      }
    ]
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "user_id": "user123",
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "analysis_timestamp": "2025-10-19T06:15:30.123456",
  "recording_start": "2025-10-01T22:00:00",
  "recording_end": "2025-10-02T06:00:00",
  "stage_intervals": [
    {
      "start_time": "2025-10-01T22:00:00",
      "end_time": "2025-10-01T22:30:00",
      "stage": "Wake",
      "confidence": 0.92
    },
    {
      "start_time": "2025-10-01T22:30:00",
      "end_time": "2025-10-01T23:00:00",
      "stage": "N1",
      "confidence": 0.85
    },
    {
      "start_time": "2025-10-01T23:00:00",
      "end_time": "2025-10-02T02:00:00",
      "stage": "N2",
      "confidence": 0.88
    },
    {
      "start_time": "2025-10-02T02:00:00",
      "end_time": "2025-10-02T04:00:00",
      "stage": "N3",
      "confidence": 0.91
    },
    {
      "start_time": "2025-10-02T04:00:00",
      "end_time": "2025-10-02T05:30:00",
      "stage": "REM",
      "confidence": 0.89
    },
    {
      "start_time": "2025-10-02T05:30:00",
      "end_time": "2025-10-02T06:00:00",
      "stage": "Wake",
      "confidence": 0.93
    }
  ],
  "stage_probabilities": [
    {
      "timestamp": "2025-10-01T22:00:00",
      "wake": 0.92,
      "n1": 0.05,
      "n2": 0.02,
      "n3": 0.01,
      "rem": 0.00
    },
    {
      "timestamp": "2025-10-01T22:30:00",
      "wake": 0.10,
      "n1": 0.85,
      "n2": 0.03,
      "n3": 0.01,
      "rem": 0.01
    }
  ],
  "summary_statistics": {
    "total_sleep_time": 420,
    "sleep_efficiency": 0.875,
    "sleep_onset_latency": 15,
    "wake_after_sleep_onset": 45,
    "wake_time": 60,
    "n1_time": 30,
    "n2_time": 180,
    "n3_time": 120,
    "rem_time": 90,
    "wake_percentage": 12.5,
    "n1_percentage": 6.25,
    "n2_percentage": 37.5,
    "n3_percentage": 25.0,
    "rem_percentage": 18.75
  },
  "model_version": "1.2.3",
  "data_quality_score": 0.89
}
```

**Fail Response (422 Unprocessable Entity - 데이터 검증 실패):**
```json
{
  "error_code": "HTTP_422",
  "error_message": "센서 데이터 유효성 검사 실패: 녹화 시간이 너무 짧습니다 (최소 1시간 필요)",
  "timestamp": "2025-10-19T06:15:30.123456",
  "request_id": "abc12345-def6-7890-abcd-ef1234567890"
}
```

**Fail Response (500 Internal Server Error):**
```json
{
  "error_code": "INTERNAL_SERVER_ERROR", 
  "error_message": "수면 분석 중 내부 오류가 발생했습니다",
  "timestamp": "2025-10-19T06:15:30.123456",
  "request_id": "abc12345-def6-7890-abcd-ef1234567890"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | HTTP_400 | 잘못된 요청 데이터 (필수 필드 누락 등) |
| 422 | HTTP_422 | 데이터 검증 실패 (timestamp 형식 오류 등) |
| 500 | HTTP_500 | 수면 분석 처리 실패 |

**Error Response Example (400 Bad Request):**
```json
{
  "error_code": "HTTP_400",
  "error_message": "필수 필드가 누락되었습니다: user_id",
  "timestamp": "2025-10-02T06:15:30Z",
  "request_id": "req_123460"
}
```

---

#### GET /api/ml/sleep/history
현재 사용자의 수면 분석 이력 조회 (JWT 인증)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/sleep/history` |
| **Authentication** | JWT Bearer 토큰 필요 |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {JWT_TOKEN}` (Spring Boot에서 발급된 토큰) |

**Parameters:**
- ~~`user_id` (string): 사용자 ID~~ **JWT 토큰에서 자동 추출**
- `page` (int, optional): 페이지 번호 (기본값: 1)
- `page_size` (int, optional): 페이지 크기 (기본값: 10, 최대: 100)

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/sleep/history?page=1&page_size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**
```json
{
  "analyses": [
    {
      "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
      "recording_start": "2025-10-01T22:00:00Z",
      "recording_end": "2025-10-02T06:00:00Z",
      "analysis_timestamp": "2025-10-02T06:15:30Z",
      "status": "completed",
      "data_quality_score": 0.89,
      "model_version": "1.2.3",
      "summary_statistics": { /* 요약 통계 */ }
    }
  ],
  "total_count": 25,
  "page": 1,
  "page_size": 10
}
```

#### GET /api/ml/sleep/result/{analysis_id}
특정 분석 결과 상세 조회

**Parameters:**
- `analysis_id` (string): 분석 ID

**Response:**
분석 완료된 경우 `/api/ml/sleep/analyze`와 동일한 응답 구조

#### GET /api/ml/sleep/models
사용 가능한 ML 모델 목록 조회

**Response:**
```json
[
  {
    "model_name": "XGBoost Sleep Stage Classifier",
    "model_version": "1.2.3", 
    "training_date": "2025-09-15T10:30:00Z",
    "accuracy": 0.92,
    "status": "active"
  }
]
```

#### DELETE /api/ml/sleep/analysis/{analysis_id}
분석 결과 삭제

**Parameters:**
- `analysis_id` (string): 분석 ID

**Response:**
```json
{
  "message": "분석 결과가 삭제되었습니다"
}
```

### 1.3 LLM 피드백 API

#### POST /api/ml/llm/feedback
수면 분석 기반 LLM 피드백 생성 (JWT 인증)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/ml/llm/feedback` |
| **Authentication** | JWT Bearer 토큰 필요 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {JWT_TOKEN}` (Spring Boot에서 발급된 토큰) |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| ~~`user_id`~~ | ~~string~~ | ~~✅~~ | ~~사용자 ID~~ | **JWT 토큰에서 자동 추출** |
| `analysis_id` | string | ✅ | 수면 분석 ID | UUID 형식 |
| `user_prompt` | string | ✅ | 사용자 질문 | 1-1000자 |

**Request Example:**
```bash
curl -X POST "http://localhost:8000/api/ml/llm/feedback" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
    "user_prompt": "어떻게 하면 더 깊은 잠을 잘 수 있나요?"
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "feedback_id": "660e8400-e29b-41d4-a716-446655440001",
  "user_prompt": "어떻게 하면 더 깊은 잠을 잘 수 있나요?",
  "llm_response": "귀하의 수면 분석 결과를 바탕으로 다음과 같은 개선 방안을 제안드립니다. 현재 깊은 잠(N3) 단계가 120분으로 전체 수면의 25%를 차지하고 있어 양호한 수준입니다. 그러나 더 개선하기 위해서는 1) 잠자리에 들기 2-3시간 전 카페인 섭취를 피하고, 2) 침실 온도를 18-20도로 유지하며, 3) 규칙적인 수면 시간을 지키시기 바랍니다.",
  "llm_model": "llama3.1:8b",
  "response_time_ms": 1250.5,
  "timestamp": "2025-10-19T06:20:15.123456",
  "analysis_summary": "총 7.0시간 수면 분석 (수면효율: 87.5%, 총 수면시간: 420분)"
}
```

**Fail Response (404 Not Found - 분석 결과 없음):**
```json
{
  "error_code": "HTTP_404",
  "error_message": "해당하는 수면 분석 데이터를 찾을 수 없습니다",
  "timestamp": "2025-10-19T06:20:15.123456",
  "request_id": "abc12345-def6-7890-abcd-ef1234567890"
}
```

**Fail Response (500 Internal Server Error):**
```json
{
  "error_code": "INTERNAL_SERVER_ERROR",
  "error_message": "피드백 생성 중 오류가 발생했습니다",
  "timestamp": "2025-10-19T06:20:15.123456",
  "request_id": "abc12345-def6-7890-abcd-ef1234567890"
}
```

#### GET /api/ml/llm/feedback/history/{user_id}
사용자의 LLM 피드백 기록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/llm/feedback/history/{user_id}` |
| **Authentication** | 불필요 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| 없음 | - | - |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `limit` | int | ➖ | 조회할 피드백 개수 (기본값: 10) |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| 없음 | - | - | - | - |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `user_id` | string | ✅ | 사용자 ID |

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/llm/feedback/history/user123?limit=5"
```

**Response:**

**Success Response (200 OK):**
```json
[
  {
    "feedback_id": "660e8400-e29b-41d4-a716-446655440001",
    "user_prompt": "어떻게 하면 더 깊은 잠을 잘 수 있나요?",
    "llm_response": "귀하의 수면 분석 결과를 바탕으로...",
    "llm_model": "llama3.1:8b",
    "response_time_ms": 1250,
    "timestamp": "2025-10-02T06:20:15Z",
    "analysis_summary": "총 7.0시간 수면 분석 (수면효율: 87.5%, 총 수면시간: 420분)"
  }
]
```

#### GET /api/ml/llm/feedback/{feedback_id}
특정 LLM 피드백 상세 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/llm/feedback/{feedback_id}` |
| **Authentication** | 불필요 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| 없음 | - | - |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| 없음 | - | - | - | - |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `feedback_id` | string | ✅ | 피드백 ID (UUID 형식) |

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/llm/feedback/660e8400-e29b-41d4-a716-446655440001"
```

**Response:**

**Success Response (200 OK):**
단일 피드백 객체 (피드백 히스토리와 동일한 구조)

**Error Response Example (404 Not Found):**
```json
{
  "error_code": "HTTP_404",
  "error_message": "해당 피드백을 찾을 수 없습니다",
  "timestamp": "2025-01-15T10:30:00Z",
  "request_id": "req_abc123def456"
}
```

#### GET /api/ml/llm/health/llm
LLM 서비스 상태 확인

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/llm/health/llm` |
| **Authentication** | 불필요 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| 없음 | - | - |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| 없음 | - | - | - | - |

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/llm/health/llm"
```

**Response:**

**Success Response (200 OK):**
```json
{
  "status": "healthy",
  "model": "gpt-oss:20b",
  "ollama_url": "http://localhost:11434",
  "available": true,
  "timestamp": "2025-10-02T06:20:15Z"
}
```

**Error Response Example (500 Internal Server Error):**
```json
{
  "error_code": "INTERNAL_SERVER_ERROR",
  "error_message": "LLM 서비스 상태 확인 실패",
  "timestamp": "2025-01-15T10:30:00Z",
  "request_id": "req_abc123def456"
}
```

### 1.4 웨어러블 기기 수면 분석 API

웨어러블 기기(Apple Watch, Galaxy Watch 등)에서 수집된 사전 분석된 수면 데이터를 처리합니다.

#### POST /api/ml/wearable/analyze
웨어러블 기기 수면 데이터 분석 및 저장 (JWT 인증)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/ml/wearable/analyze` |
| **Authentication** | JWT Bearer 토큰 필요 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {JWT_TOKEN}` (Spring Boot에서 발급된 토큰) |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| ~~`user_id`~~ | ~~string~~ | ~~✅~~ | ~~사용자 ID~~ | **JWT 토큰에서 자동 추출** |
| `device_type` | string | ✅ | 웨어러블 기기 타입 | "apple_watch", "galaxy_watch" |
| `sleep_start` | datetime | ✅ | 수면 시작 시간 | ISO 8601 형식 |
| `sleep_end` | datetime | ✅ | 수면 종료 시간 | ISO 8601 형식 |
| `sleep_stages` | array | ✅ | 수면 단계별 데이터 | 최소 1개 이상 |
| `heart_rate` | float | ➖ | 평균 심박수 | 30.0-200.0 bpm |
| `sleep_analysis_metadata` | object | ➖ | 기기별 메타데이터 | - |
| `device_id` | string | ➖ | 기기 고유 ID | 최대 50자 |

**Request Example:**
```bash
curl -X POST "http://localhost:8000/api/ml/wearable/analyze" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "device_type": "apple_watch",
    "sleep_start": "2025-10-01T22:00:00Z",
    "sleep_end": "2025-10-02T06:00:00Z",
    "sleep_stages": [
      {
        "start_time": "2025-10-01T22:00:00Z",
        "end_time": "2025-10-01T22:30:00Z",
        "sleep_stage": "inbed"
      },
      {
        "start_time": "2025-10-01T22:30:00Z",
        "end_time": "2025-10-01T23:00:00Z",
        "sleep_stage": "core"
      },
      {
        "start_time": "2025-10-01T23:00:00Z",
        "end_time": "2025-10-02T01:00:00Z",
        "sleep_stage": "deep"
      },
      {
        "start_time": "2025-10-02T01:00:00Z",
        "end_time": "2025-10-02T03:00:00Z",
        "sleep_stage": "rem"
      }
    ],
    "heart_rate": 61.5,
    "sleep_analysis_metadata": {
      "source": "HealthKit",
      "device_model": "Apple Watch Series 8"
    },
    "device_id": "AW-12345"
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "analysis_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "device_type": "apple_watch",
  "status": "processed",
  "processed_at": "2025-10-02T06:15:30Z",
  "calculated_metrics": {
    "total_sleep_time": 420,
    "sleep_efficiency": 87.5,
    "wake_time": 30,
    "n2_time": 210,
    "n3_time": 120,
    "rem_time": 120,
    "wake_percentage": 7.1,
    "n2_percentage": 50.0,
    "n3_percentage": 28.6,
    "rem_percentage": 28.6
  },
  "llm_analysis_ready": true
}
```

**Error Response Example (400 Bad Request - 데이터 검증 실패):**
```json
{
  "error_code": "HTTP_400",
  "error_message": "데이터 검증 실패: 비정상적인 수면 시간: 25.2시간",
  "timestamp": "2025-01-15T10:30:00Z",
  "request_id": "req_abc123def456"
}
```

**Error Response Example (500 Internal Server Error):**
```json
{
  "error_code": "INTERNAL_SERVER_ERROR",
  "error_message": "웨어러블 수면 데이터 분석 중 오류가 발생했습니다",
  "timestamp": "2025-01-15T10:30:00Z",
  "request_id": "req_abc123def456"
}
```

#### GET /api/ml/wearable/devices
지원하는 웨어러블 기기 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/ml/wearable/devices` |
| **Authentication** | 불필요 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| 없음 | - | - |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| 없음 | - | - | - | - |

**Request Example:**
```bash
curl -X GET "http://localhost:8000/api/ml/wearable/devices"
```

**Response:**

**Success Response (200 OK):**
```json
[
  {
    "device_type": "APPLE_WATCH",
    "device_name": "Apple Watch",
    "supported_features": [
      "수면 단계 분석",
      "심박수 모니터링", 
      "호흡수 측정",
      "체온 측정",
      "수면 효율성 계산"
    ],
    "data_source": "HealthKit"
  },
  {
    "device_type": "GALAXY_WATCH",
    "device_name": "Samsung Galaxy Watch",
    "supported_features": [
      "수면 단계 분석",
      "심박수 모니터링",
      "혈중산소포화도",
      "스트레스 레벨",
      "수면 효율성 계산"
    ],
    "data_source": "Samsung Health"
  }
]
```

---

## 2. NEULBO-SERVER (Spring Boot)

### 2.1 OAuth 인증 API

#### POST /api/v1/oauth/login
OAuth 로그인 (리액티브 방식 - **권장**)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/oauth/login` |
| **Authentication** | 불필요 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `provider` | string | ✅ | OAuth 제공자 | google, kakao, naver |
| `providerId` | string | ✅ | 제공자에서 발급한 사용자 ID | 1-100자 |
| `email` | string | ⚠️ | 이메일 (Google 필수) | 유효한 이메일 형식, 100자 이하 |
| `name` | string | ➖ | 사용자 실명 | 100자 이하 |
| `profileImageUrl` | string | ➖ | 프로필 이미지 URL | 500자 이하 |
| `nickname` | string | ➖ | 사용자 닉네임 | 50자 이하 |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/oauth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "google",
    "providerId": "12345678901234567890", 
    "email": "user@example.com",
    "name": "홍길동",
    "profileImageUrl": "https://example.com/profile.jpg",
    "nickname": "길동이"
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "OAuth 로그인 성공",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "isNewUser": true
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E604 | 유효하지 않은 OAuth 사용자 데이터 |
| 400 | E601 | 지원하지 않는 OAuth 제공자 |  
| 409 | E605 | 이미 존재하는 이메일 |
| 500 | E607 | OAuth 로그인 실패 |
| 500 | E606 | 사용자 생성 실패 |

**Error Response Example (400 Bad Request):**
```json
{
  "success": false,
  "message": "유효하지 않은 OAuth 사용자 데이터입니다.",
  "data": {
    "code": "E604",
    "message": "필수 필드(provider, providerId)가 누락되었습니다",
    "fieldErrors": [
      {
        "field": "provider",
        "value": "",
        "reason": "OAuth 제공자는 필수입니다"
      }
    ]
  },
  "timestamp": "2025-10-14T15:30:00"
}
```

#### POST /api/v1/oauth/login/blocking
OAuth 로그인 (블로킹 방식 - 하위 호환성)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/oauth/login/blocking` |
| **Authentication** | 불필요 |
| **Content-Type** | `application/json` |
| **참고** | ⚠️ **DEPRECATED** - 리액티브 방식 사용 권장 |

**Request Body:** 위 리액티브 방식과 동일

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/oauth/login/blocking" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "google",
    "providerId": "12345678901234567890",
    "email": "user@example.com"
  }'
```

**Response:** 리액티브 방식과 동일한 `ApiResponse<LoginResponse>` 구조

### � Request 필드 설명

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `provider` | string | ✅ | OAuth 제공자 (google, kakao, naver) |
| `providerId` | string | ✅ | OAuth 제공자에서 발급한 사용자 고유 ID |
| `email` | string | 📧 | 사용자 이메일 (Google은 필수, 다른 제공자는 선택) |
| `name` | string | ➖ | 사용자 실명 |
| `profileImageUrl` | string | ➖ | 프로필 이미지 URL |
| `nickname` | string | ➖ | 사용자 닉네임 |

### 🔄 OAuth 로그인 플로우

#### 새로운 User Data Direct 방식 ⭐
1. **프론트엔드**: OAuth 제공자에서 사용자 데이터까지 직접 획득
2. **백엔드**: 사용자 데이터 검증 → DB 조회/생성 → JWT 발급  
3. **장점**: 
   - ⚡ 더 빠른 응답 시간
   - 🔗 네트워크 호출 감소  
   - 🎛️ 프론트엔드에서 더 많은 제어 가능
   - 🎯 단순하고 직관적인 API 구조

#### ~~기존 방식 (인가 코드 기반)~~ **DEPRECATED**
- Authorization Code 방식은 더 이상 지원되지 않습니다
- 기존 코드는 deprecated 처리되었으며 향후 제거 예정입니다

---

#### POST /api/v1/auth/tokens/refresh
액세스 토큰 갱신

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/auth/tokens/refresh` |
| **Authentication** | Refresh Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {refresh_token}` |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/auth/tokens/refresh" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "토큰 갱신 성공",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 리프레시 토큰이 필요합니다 |
| 401 | E102 | 유효하지 않은 리프레시 토큰입니다 |
| 401 | E103 | 만료되었거나 조작된 토큰입니다 |

---

#### POST /api/v1/auth/logout
로그아웃

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/auth/logout` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/auth/logout" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "로그아웃이 성공적으로 처리되었습니다.",
  "data": null,
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | Access Token이 필요합니다 |
| 401 | E102 | 잘못된 토큰입니다 |

---

### 2.2 사용자 관리 API

모든 사용자 API는 JWT 토큰 인증이 필요합니다.
**Header:** `Authorization: Bearer {access_token}`

#### GET /api/v1/users/me/profile
현재 사용자 프로필 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/users/me/profile` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/users/me/profile" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "프로필 조회 성공",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "홍길동",
    "profileImage": "https://example.com/profile.jpg",
    "birth": "1990-01-01",
    "isPrivate": false,
    "provider": "google"
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E302 | 사용자를 찾을 수 없음 |

**Error Response Examples:**

**401 Unauthorized:**
```json
{
  "success": false,
  "message": "유효하지 않은 토큰입니다.",
  "data": {
    "code": "E102",
    "message": "유효하지 않은 토큰입니다."
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**404 Not Found:**
```json
{
  "success": false,
  "message": "사용자를 찾을 수 없습니다.",
  "data": {
    "code": "E302",
    "message": "사용자를 찾을 수 없습니다."
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

#### PUT /api/v1/users/me/profile
현재 사용자 프로필 수정

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | PUT |
| **URL** | `/api/v1/users/me/profile` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `username` | string | ➖ | 사용자명 | 100자 이하 |
| `profileImage` | string | ➖ | 프로필 이미지 URL | - |
| `birth` | string | ➖ | 생년월일 | YYYY-MM-DD 형식 |
| `isPrivate` | boolean | ➖ | 프로필 공개 여부 | true/false |

**Request Example:**
```bash
curl -X PUT "https://neulbo1.com/api/v1/users/me/profile" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "username": "홍길동",
    "profileImage": "https://example.com/new-profile.jpg",
    "birth": "1990-01-01",
    "isPrivate": false
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "프로필이 성공적으로 수정되었습니다.",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "홍길동",
    "profileImage": "https://example.com/new-profile.jpg",
    "birth": "1990-01-01",
    "isPrivate": false,
    "provider": "google"
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 입력값 |
| 401 | E102 | 유효하지 않은 토큰 |

**Error Response Examples:**

**400 Bad Request:**
```json
{
  "success": false,
  "message": "잘못된 입력값입니다.",
  "data": {
    "code": "E001",
    "message": "잘못된 입력값입니다."
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**401 Unauthorized:**
```json
{
  "success": false,
  "message": "유효하지 않은 토큰입니다.",
  "data": {
    "code": "E102",
    "message": "유효하지 않은 토큰입니다."
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

#### GET /api/v1/users/me/account
현재 사용자 계정 정보 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/users/me/account` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/users/me/account" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "계정 정보 조회 성공",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "provider": "google",
    "providerId": "12345678901234567890",
    "username": "홍길동",
    "createdAt": "2025-01-15T10:30:00",
    "updatedAt": "2025-10-15T11:30:00"
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E302 | 사용자를 찾을 수 없음 |

**Error Response Example (401 Unauthorized):**
```json
{
  "success": false,
  "message": "유효하지 않은 토큰입니다.",
  "data": {
    "code": "E102",
    "message": "유효하지 않은 토큰입니다."
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

#### PUT /api/v1/users/me/account
현재 사용자 계정 정보 수정

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | PUT |
| **URL** | `/api/v1/users/me/account` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `username` | string | ✅ | 사용자명 | 1-100자 |

**Request Example:**
```bash
curl -X PUT "https://neulbo1.com/api/v1/users/me/account" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "username": "새로운사용자명"
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "계정 정보가 성공적으로 수정되었습니다.",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "newemail@example.com",
    "provider": "google",
    "is_active": true,
    "is_verified": true,
    "subscription_type": "premium",
    "created_at": "2025-01-15T10:30:00Z",
    "last_login_at": "2025-10-02T09:15:00Z"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 입력값 (유효성 검사 실패) |
| 401 | E102 | 유효하지 않은 토큰 |
| 409 | E605 | 이미 존재하는 이메일 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (409 Conflict):**
```json
{
  "success": false,
  "message": "이미 존재하는 이메일입니다.",
  "data": {
    "code": "E605",
    "message": "이미 존재하는 이메일입니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### DELETE /api/v1/users/me
현재 사용자 계정 삭제 (탈퇴)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | DELETE |
| **URL** | `/api/v1/users/me` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X DELETE "https://neulbo1.com/api/v1/users/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "계정이 성공적으로 삭제되었습니다.",
  "data": null,
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E302 | 사용자를 찾을 수 없음 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (401 Unauthorized):**
```json
{
  "success": false,
  "message": "유효하지 않은 토큰입니다.",
  "data": {
    "code": "E102",
    "message": "유효하지 않은 토큰입니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### GET /api/v1/users/me/settings
현재 사용자 설정 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/users/me/settings` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/users/me/settings" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "사용자 설정 조회 성공",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "isPrivate": false
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E302 | 사용자를 찾을 수 없음 |

**Error Response Example (401 Unauthorized):**
```json
{
  "success": false,
  "message": "유효하지 않은 토큰입니다.",
  "data": {
    "code": "E102",
    "message": "유효하지 않은 토큰입니다."
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

#### PUT /api/v1/users/me/settings
현재 사용자 설정 수정

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | PUT |
| **URL** | `/api/v1/users/me/settings` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `isPrivate` | boolean | ✅ | 프로필 공개 여부 | true/false |

**Request Example:**
```bash
curl -X PUT "https://neulbo1.com/api/v1/users/me/settings" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "notification_enabled": true,
    "email_notification": true,
    "push_notification": false,
    "sleep_reminder_time": "23:00",
    "wake_up_time": "06:30",
    "timezone": "Asia/Seoul",
    "language": "en",
    "theme": "light"
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "설정이 성공적으로 수정되었습니다.",
  "data": {
    "notification_enabled": true,
    "email_notification": true,
    "push_notification": false,
    "sleep_reminder_time": "23:00",
    "wake_up_time": "06:30",
    "timezone": "Asia/Seoul",
    "language": "en",
    "theme": "light"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 입력값 (유효성 검사 실패) |
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E302 | 사용자를 찾을 수 없음 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (400 Bad Request):**
```json
{
  "success": false,
  "message": "잘못된 입력값입니다.",
  "data": {
    "code": "E001",
    "message": "잘못된 입력값입니다.",
    "fieldErrors": [
      {
        "field": "endTime",
        "value": "invalid-time",
        "reason": "올바른 시간 형식을 입력해주세요 (HH:mm:ss)"
      }
    ]
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

### 2.3 음악 스트리밍 API

모든 음악 API는 JWT 토큰 인증이 필요합니다.

#### GET /api/v1/music
모든 음악 조회 (페이지네이션)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music?page=0&size=20" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "음악 목록 조회 성공",
  "data": {
    "content": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440000",
        "title": "잔잔한 수면 음악",
        "artist": "Sleep Music Studio",
        "album": "Deep Sleep Collection",
        "durationSeconds": 600,
        "fileUrl": "https://example.com/music/sleep-music-1.mp3",
        "thumbnailUrl": "https://example.com/covers/sleep-music-1.jpg",
        "description": "깊은 잠에 도움이 되는 편안한 앰비언트 음악입니다.",
        "playCount": 1250,
        "isPremium": false,
        "isActive": true,
        "category": {
          "id": "880e8400-e29b-41d4-a716-446655440000",
          "name": "수면 음악",
          "description": "깊은 잠에 도움이 되는 음악",
          "iconUrl": "https://example.com/category-icons/sleep.png",
          "colorCode": "#4A90E2",
          "sortOrder": 1,
          "isActive": true,
          "musicCount": 50,
          "createdAt": "2025-01-15T10:00:00",
          "updatedAt": "2025-10-15T11:00:00"
        },
        "createdAt": "2025-01-15T10:30:00",
        "updatedAt": "2025-10-15T11:30:00"
      }
    ],
    "pageable": {
      "sort": {
        "empty": false,
        "sorted": true,
        "unsorted": false
      },
      "offset": 0,
      "pageSize": 20,
      "pageNumber": 0,
      "paged": true,
      "unpaged": false
    },
    "last": false,
    "totalPages": 8,
    "totalElements": 150,
    "size": 20,
    "number": 0,
    "sort": {
      "empty": false,
      "sorted": true,
      "unsorted": false
    },
    "first": true,
    "numberOfElements": 20,
    "empty": false
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 페이지 파라미터 |
| 401 | E102 | 유효하지 않은 토큰 |
| 403 | E201 | 접근이 거부됨 (구독 필요) |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (400 Bad Request):**
```json
{
  "success": false,
  "message": "잘못된 입력값입니다.",
  "data": {
    "code": "E001",
    "message": "잘못된 입력값입니다.",
    "fieldErrors": [
      {
        "field": "page",
        "value": "-1",
        "reason": "0 이상의 값이어야 합니다"
      }
    ]
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

#### GET /api/v1/music/category/{categoryId}
카테고리별 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/category/{categoryId}` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `categoryId` | UUID | ✅ | 카테고리 ID |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/category/660e8400-e29b-41d4-a716-446655440000?page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "카테고리별 음악 조회 성공",
  "data": {
    "content": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440000",
        "title": "잔잔한 수면 음악",
        "artist": "Sleep Music Studio",
        "album": "Deep Sleep Collection",
        "durationSeconds": 600,
        "fileUrl": "https://example.com/music/sleep-music-1.mp3",
        "thumbnailUrl": "https://example.com/covers/sleep-music-1.jpg",
        "description": "깊은 잠에 도움이 되는 편안한 앰비언트 음악입니다.",
        "playCount": 1520,
        "isPremium": false,
        "isActive": true,
        "category": {
          "id": "660e8400-e29b-41d4-a716-446655440000",
          "name": "수면 음악",
          "description": "깊은 잠에 도움이 되는 음악",
          "iconUrl": "https://example.com/category-icons/sleep.png",
          "colorCode": "#4A90E2",
          "sortOrder": 1,
          "isActive": true,
          "musicCount": 25,
          "createdAt": "2025-01-15T10:00:00",
          "updatedAt": "2025-10-15T11:00:00"
        },
        "createdAt": "2025-01-15T10:30:00",
        "updatedAt": "2025-10-15T11:30:00"
      }
    ],
    "pageable": {
      "sort": {
        "empty": false,
        "sorted": true,
        "unsorted": false
      },
      "offset": 0,
      "pageSize": 10,
      "pageNumber": 0,
      "paged": true,
      "unpaged": false
    },
    "last": false,
    "totalPages": 5,
    "totalElements": 50,
    "size": 10,
    "number": 0,
    "sort": {
      "empty": false,
      "sorted": true,
      "unsorted": false
    },
    "first": true,
    "numberOfElements": 10,
    "empty": false
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 카테고리 ID 형식 |
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E404 | 카테고리를 찾을 수 없음 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (404 Not Found):**
```json
{
  "success": false,
  "message": "카테고리를 찾을 수 없습니다.",
  "data": {
    "code": "E404",
    "message": "카테고리를 찾을 수 없습니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### GET /api/v1/music/search
음악 검색

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/search` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default | Validation |
|------------------|------|----------|-------------|---------|------------|
| `keyword` | string | ✅ | 검색 키워드 | - | 1-100자 |
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 | 0 이상 |
| `size` | integer | ➖ | 페이지 크기 | 20 | 1-100 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/search?keyword=수면&page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
음악 목록과 동일한 구조 (카테고리별 조회 참조)

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 검색 키워드 (길이 초과 등) |
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

---

#### GET /api/v1/music/popular
인기 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/popular` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/popular?page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
음악 목록과 동일한 구조 (카테고리별 조회 참조)

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

---

#### GET /api/v1/music/latest
최신 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/latest` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/latest?page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
음악 목록과 동일한 구조 (카테고리별 조회 참조)

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

---

#### GET /api/v1/music/free
무료 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/free` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/free?page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
음악 목록과 동일한 구조 (카테고리별 조회 참조)

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

---

#### GET /api/v1/music/premium
프리미엄 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/premium` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/premium?page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
음악 목록과 동일한 구조 (카테고리별 조회 참조)

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 403 | E103 | 프리미엄 구독 필요 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (403 Forbidden):**
```json
{
  "success": false,
  "message": "프리미엄 구독이 필요합니다.",
  "data": {
    "code": "E103",
    "message": "프리미엄 구독이 필요합니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### GET /api/v1/music/{musicId}
특정 음악 상세 조회

**Parameters:**
- `musicId` (UUID): 음악 ID

**Response:**
```json
{
  "id": "770e8400-e29b-41d4-a716-446655440000",
  "title": "잔잔한 수면 음악",
  "artist": "Sleep Music Studio", 
  "album": "Deep Sleep Collection",
  "duration": 600,
  "genre": "Ambient",
  "release_date": "2025-01-01",
  "file_url": "https://example.com/music/sleep-music-1.mp3",
  "cover_image_url": "https://example.com/covers/sleep-music-1.jpg",
  "is_premium": false,
  "play_count": 1250,
  "category": {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "name": "수면 음악"
  },
  "description": "깊은 잠에 도움이 되는 편안한 앰비언트 음악입니다."
}
```

#### GET /api/v1/music/duration
재생시간 범위로 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/duration` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default | Validation |
|------------------|------|----------|-------------|---------|------------|
| `minDuration` | integer | ✅ | 최소 재생시간 (초) | - | 1 이상 |
| `maxDuration` | integer | ✅ | 최대 재생시간 (초) | - | minDuration보다 큰 값 |
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 | 0 이상 |
| `size` | integer | ➖ | 페이지 크기 | 20 | 1-100 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/duration?minDuration=300&maxDuration=600&page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
음악 목록과 동일한 구조 (카테고리별 조회 참조)

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 재생시간 파라미터 (minDuration >= maxDuration 등) |
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (400 Bad Request):**
```json
{
  "success": false,
  "message": "최소 재생시간이 최대 재생시간보다 클 수 없습니다.",
  "data": {
    "code": "E001",
    "message": "최소 재생시간이 최대 재생시간보다 클 수 없습니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### GET /api/v1/music/category/{categoryId}/popular
카테고리별 인기 음악 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/music/category/{categoryId}/popular` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `categoryId` | UUID | ✅ | 카테고리 ID |

| Query Parameters | Type | Required | Description | Default | Validation |
|------------------|------|----------|-------------|---------|------------|
| `limit` | integer | ➖ | 조회할 음악 개수 | 10 | 1-100 |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/music/category/660e8400-e29b-41d4-a716-446655440000/popular?limit=5" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "카테고리별 인기 음악 조회 성공",
  "data": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440000",
      "title": "잔잔한 수면 음악",
      "artist": "Sleep Music Studio",
      "album": "Deep Sleep Collection",
      "duration": 600,
      "genre": "Ambient",
      "release_date": "2025-01-01",
      "file_url": "https://example.com/music/sleep-music-1.mp3",
      "cover_image_url": "https://example.com/covers/sleep-music-1.jpg",
      "is_premium": false,
      "play_count": 1250,
      "category": {
        "id": "660e8400-e29b-41d4-a716-446655440000", 
        "name": "수면 음악"
      }
    }
  ],
  "timestamp": "2025-10-15T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 카테고리 ID 형식 또는 limit 값 |
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E404 | 카테고리를 찾을 수 없음 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (404 Not Found):**
```json
{
  "success": false,
  "message": "카테고리를 찾을 수 없습니다.",
  "data": {
    "code": "E404",
    "message": "카테고리를 찾을 수 없습니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### POST /api/v1/music/{musicId}/play
음악 재생수 증가

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/music/{musicId}/play` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `musicId` | UUID | ✅ | 음악 고유 식별자 |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/music/770e8400-e29b-41d4-a716-446655440000/play" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "재생수가 증가되었습니다.",
  "data": {
    "musicId": "770e8400-e29b-41d4-a716-446655440000",
    "playCount": 1251,
    "playedAt": "2025-10-16T12:30:00"
  },
  "timestamp": "2025-10-16T12:30:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 404 | E301 | 음악을 찾을 수 없음 |
| 403 | E201 | 프리미엄 음악 접근 권한 없음 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (404 Not Found):**
```json
{
  "success": false,
  "message": "요청한 리소스를 찾을 수 없습니다.",
  "data": {
    "code": "E301",
    "message": "음악을 찾을 수 없습니다"
  },
  "timestamp": "2025-10-15T12:30:00"
}
```

---

### 2.4 플레이리스트 API

#### GET /api/v1/playlists/my
내 플레이리스트 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/playlists/my` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/playlists/my" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "플레이리스트 목록 조회 성공",
  "data": [
    {
      "id": "990e8400-e29b-41d4-a716-446655440000",
      "name": "내 수면 플레이리스트",
      "description": "잠자기 전 듣는 음악 모음",
      "thumbnailUrl": "https://example.com/playlist-covers/1.jpg",
      "isPublic": false,
      "isDefault": false,
      "totalDurationSeconds": 9000,
      "musicCount": 15,
      "userId": "550e8400-e29b-41d4-a716-446655440000",
      "userName": "사용자1",
      "musicList": [],
      "createdAt": "2025-09-15T10:30:00",
      "updatedAt": "2025-10-01T15:45:00"
    }
  ],
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

---

#### POST /api/v1/playlists
새 플레이리스트 생성

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/playlists` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `name` | string | ✅ | 플레이리스트 이름 | 1-100자 |
| `description` | string | ➖ | 플레이리스트 설명 | 최대 300자 |
| `thumbnailUrl` | string | ➖ | 썸네일 URL | 최대 500자 |
| `isPublic` | boolean | ➖ | 공개 여부 | true/false (기본값: false) |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/playlists" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "새 플레이리스트",
    "description": "플레이리스트 설명",
    "thumbnailUrl": "https://example.com/thumbnail.jpg",
    "isPublic": false
  }'
```

**Response:**

**Success Response (201 Created):**
```json
{
  "success": true,
  "message": "플레이리스트가 성공적으로 생성되었습니다",
  "data": {
    "id": "990e8400-e29b-41d4-a716-446655440000",
    "name": "새 플레이리스트",
    "description": "플레이리스트 설명",
    "thumbnailUrl": null,
    "isPublic": false,
    "isDefault": false,
    "totalDurationSeconds": 0,
    "musicCount": 0,
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "userName": "사용자1",
    "musicList": [],
    "createdAt": "2025-10-16T12:00:00",
    "updatedAt": "2025-10-16T12:00:00"
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 입력값 (이름 필수, 길이 제한 등) |
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (400 Bad Request):**
```json
{
  "success": false,
  "message": "잘못된 입력값입니다.",
  "data": {
    "code": "E001",
    "message": "잘못된 입력값입니다.",
    "fieldErrors": [
      {
        "field": "name",
        "value": "",
        "reason": "플레이리스트 이름은 필수입니다"
      }
    ]
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

---

#### GET /api/v1/playlists/{playlistId}
특정 플레이리스트 상세 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/playlists/{playlistId}` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `playlistId` | UUID | ✅ | 플레이리스트 ID |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/playlists/990e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "플레이리스트 상세 조회 성공",
  "data": {
    "id": "990e8400-e29b-41d4-a716-446655440000",
    "name": "내 수면 플레이리스트",
    "description": "잠자기 전 듣는 음악 모음",
    "thumbnailUrl": "https://example.com/playlist-covers/1.jpg",
    "isPublic": false,
    "isDefault": false,
    "totalDurationSeconds": 9000,
    "musicCount": 15,
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "userName": "사용자1",
    "musicList": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440000",
        "title": "잔잔한 수면 음악",
        "artist": "Sleep Music Studio",
        "album": "Deep Sleep Collection",
        "durationSeconds": 600,
        "fileUrl": "https://example.com/music/sleep-music-1.mp3",
        "thumbnailUrl": "https://example.com/covers/sleep-music-1.jpg",
        "description": "깊은 잠에 도움이 되는 편안한 앰비언트 음악입니다.",
        "playCount": 1250,
        "isPremium": false,
        "isActive": true,
        "createdAt": "2025-01-15T10:30:00",
        "updatedAt": "2025-10-15T11:30:00"
      }
    ],
    "createdAt": "2025-09-15T10:30:00",
    "updatedAt": "2025-10-01T15:45:00"
  },
  "timestamp": "2025-10-16T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 잘못된 플레이리스트 ID 형식 |
| 401 | E102 | 유효하지 않은 토큰 |
| 403 | E403 | 플레이리스트 접근 권한 없음 |
| 404 | E404 | 플레이리스트를 찾을 수 없음 |
| 500 | E501 | 서버 내부 오류 |

**Error Response Example (404 Not Found):**
```json
{
  "success": false,
  "message": "플레이리스트를 찾을 수 없습니다.",
  "data": {
    "code": "E404",
    "message": "플레이리스트를 찾을 수 없습니다"
  },
  "timestamp": "2025-10-15T12:00:00"
}
```

---

#### POST /api/v1/playlists/{playlistId}/music
플레이리스트에 음악 추가

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/playlists/{playlistId}/music` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `playlistId` | UUID | ✅ | 플레이리스트 ID |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `musicId` | UUID | ✅ | 추가할 음악 ID | - |
| `sortOrder` | integer | ➖ | 정렬 순서 | - |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/playlists/990e8400-e29b-41d4-a716-446655440000/music" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "musicId": "770e8400-e29b-41d4-a716-446655440000",
    "sortOrder": 1
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "음악이 플레이리스트에 추가되었습니다",
  "data": null,
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 음악 추가에 실패했습니다 |
| 401 | E102 | 유효하지 않은 토큰 |
| 403 | E403 | 플레이리스트 접근 권한 없음 |
| 404 | E404 | 플레이리스트 또는 음악을 찾을 수 없음 |

---

#### DELETE /api/v1/playlists/{playlistId}/music/{musicId}
플레이리스트에서 음악 제거

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | DELETE |
| **URL** | `/api/v1/playlists/{playlistId}/music/{musicId}` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `playlistId` | UUID | ✅ | 플레이리스트 ID |
| `musicId` | UUID | ✅ | 제거할 음악 ID |

**Request Example:**
```bash
curl -X DELETE "https://neulbo1.com/api/v1/playlists/990e8400-e29b-41d4-a716-446655440000/music/770e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "음악이 플레이리스트에서 제거되었습니다",
  "data": null,
  "timestamp": "2025-10-17T12:00:00"
}
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 400 | E001 | 음악 제거에 실패했습니다 |
| 401 | E102 | 유효하지 않은 토큰 |
| 403 | E403 | 플레이리스트 접근 권한 없음 |
| 404 | E404 | 플레이리스트 또는 음악을 찾을 수 없음 |

---

#### GET /api/v1/playlists/public
공개 플레이리스트 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/playlists/public` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | integer | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | integer | ➖ | 페이지 크기 | 20 |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/playlists/public?page=0&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "공개 플레이리스트 목록 조회 성공",
  "data": {
    "content": [
      {
        "id": "990e8400-e29b-41d4-a716-446655440000",
        "name": "편안한 수면 음악 모음",
        "description": "누구나 들을 수 있는 수면 음악 플레이리스트",
        "thumbnailUrl": "https://example.com/playlist-covers/public1.jpg",
        "isPublic": true,
        "isDefault": false,
        "totalDurationSeconds": 7200,
        "musicCount": 12,
        "userId": "550e8400-e29b-41d4-a716-446655440000",
        "userName": "관리자",
        "musicList": [],
        "createdAt": "2025-09-15T10:30:00",
        "updatedAt": "2025-10-01T15:45:00"
      }
    ],
    "pageable": {
      "page": 0,
      "size": 10,
      "sort": {
        "sorted": false,
        "unsorted": true
      }
    },
    "totalElements": 25,
    "totalPages": 3,
    "first": true,
    "last": false
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

---

#### GET /api/v1/playlists/popular
인기 플레이리스트 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/playlists/popular` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `limit` | integer | ➖ | 조회할 개수 | 10 |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/playlists/popular?limit=5" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "인기 플레이리스트 조회 성공",
  "data": {
    "content": [
      {
        "id": "990e8400-e29b-41d4-a716-446655440000",
        "name": "최고 인기 수면 음악",
        "description": "가장 많이 재생된 수면 음악들",
        "thumbnailUrl": "https://example.com/playlist-covers/popular1.jpg",
        "isPublic": true,
        "isDefault": false,
        "totalDurationSeconds": 5400,
        "musicCount": 9,
        "userId": "550e8400-e29b-41d4-a716-446655440000",
        "userName": "관리자",
        "musicList": [],
        "createdAt": "2025-08-15T10:30:00",
        "updatedAt": "2025-10-15T15:45:00"
      }
    ],
    "pageable": {
      "page": 0,
      "size": 20,
      "sort": {
        "sorted": false,
        "unsorted": true
      }
    },
    "totalElements": 15,
    "totalPages": 1,
    "first": true,
    "last": true
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

---

### 2.5 카테고리 API

#### GET /api/v1/categories
음악 카테고리 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/categories` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Query Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| 없음 | - | - | - |

| Request Body | Type | Required | Description |
|--------------|------|----------|-------------|
| 없음 | - | - | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/categories" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "카테고리 목록 조회 성공",
  "data": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440000",
      "name": "수면 음악",
      "description": "깊은 잠에 도움이 되는 음악",
      "iconUrl": "https://example.com/category-icons/sleep.png",
      "colorCode": "#4A90E2",
      "sortOrder": 1,
      "isActive": true,
      "musicCount": 50,
      "createdAt": "2025-01-15T10:00:00",
      "updatedAt": "2025-10-15T11:00:00"
    },
    {
      "id": "990e8400-e29b-41d4-a716-446655440001",
      "name": "집중 음악",
      "description": "업무와 학습에 도움이 되는 음악",
      "iconUrl": "https://example.com/category-icons/focus.png",
      "colorCode": "#28A745",
      "sortOrder": 2,
      "isActive": true,
      "musicCount": 35,
      "createdAt": "2025-01-15T10:30:00",
      "updatedAt": "2025-10-15T11:30:00"
    }
  ],
  "timestamp": "2025-10-17T12:00:00"
}
```
```

**Error Responses:**

| Status Code | Error Code | Description |
|-------------|------------|-------------|
| 401 | E102 | 유효하지 않은 토큰 |
| 500 | E501 | 서버 내부 오류 |

---

#### GET /api/v1/categories/all
모든 카테고리 목록 조회 (관리자용)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/categories/all` |
| **Authentication** | Bearer Token 필수 (Admin 권한) |
| **Content-Type** | N/A |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "전체 카테고리 목록 조회 성공",
  "data": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440000",
      "name": "수면 음악",
      "description": "깊은 잠에 도움이 되는 음악",
      "iconUrl": "https://example.com/category-icons/sleep.png",
      "colorCode": "#4A90E2",
      "sortOrder": 1,
      "isActive": true,
      "musicCount": 50,
      "createdAt": "2025-01-15T10:00:00",
      "updatedAt": "2025-10-15T11:00:00"
    }
  ],
  "timestamp": "2025-10-17T12:00:00"
}
```

---

#### GET /api/v1/categories/{categoryId}
특정 카테고리 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/categories/{categoryId}` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `categoryId` | UUID | ✅ | 카테고리 ID |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "카테고리 조회 성공",
  "data": {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "name": "수면 음악",
    "description": "깊은 잠에 도움이 되는 음악",
    "iconUrl": "https://example.com/category-icons/sleep.png",
    "colorCode": "#4A90E2",
    "sortOrder": 1,
    "isActive": true,
    "musicCount": 50,
    "createdAt": "2025-01-15T10:00:00",
    "updatedAt": "2025-10-15T11:00:00"
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

---

#### GET /api/v1/categories/name/{name}
이름으로 카테고리 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/categories/name/{name}` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `name` | string | ✅ | 카테고리 이름 |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "카테고리 조회 성공",
  "data": {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "name": "수면 음악",
    "description": "깊은 잠에 도움이 되는 음악",
    "iconUrl": "https://example.com/category-icons/sleep.png",
    "colorCode": "#4A90E2",
    "sortOrder": 1,
    "isActive": true,
    "musicCount": 50,
    "createdAt": "2025-01-15T10:00:00",
    "updatedAt": "2025-10-15T11:00:00"
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

---

### 2.6 챌린지 API

#### GET /api/v1/challenges
전체 챌린지 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/challenges` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "챌린지 목록 조회 성공",
  "data": [
    {
      "id": "770e7300-d19a-31c3-9606-335544330000",
      "title": "30일 수면 챌린지",
      "description": "매일 밤 10시에 잠들기 챌린지",
      "startDate": "2025-01-01",
      "endDate": "2025-01-31",
      "maxParticipants": 100,
      "currentParticipants": 45,
      "rewardPoints": 500,
      "isActive": true,
      "createdAt": "2024-12-15T10:00:00",
      "updatedAt": "2025-01-10T14:30:00"
    }
  ],
  "timestamp": "2025-10-17T12:00:00"
}
```

**Fail Response (401 Unauthorized):**
```json
{
  "success": false,
  "message": "유효하지 않은 토큰입니다",
  "data": null,
  "timestamp": "2025-10-17T12:00:00"
}
```

---

#### POST /api/v1/challenges/{challengeId}/join
챌린지 참여

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/challenges/{challengeId}/join` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | application/json |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `challengeId` | UUID | ✅ | 참여할 챌린지 ID |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "챌린지 참여 성공",
  "data": {
    "id": "990e9500-f39c-51e5-b828-557766550000",
    "challengeId": "770e7300-d19a-31c3-9606-335544330000",
    "userId": "550e5500-e29b-41d4-a716-446655440000",
    "joinDate": "2025-01-15",
    "currentProgress": 0,
    "targetProgress": 30,
    "isCompleted": false,
    "completionDate": null,
    "earnedPoints": 0
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

**Fail Response (409 Conflict - 이미 참여중):**
```json
{
  "success": false,
  "message": "이미 참여 중인 챌린지입니다",
  "data": null,
  "timestamp": "2025-10-17T12:00:00"
}
```

---

#### GET /api/v1/challenges/my-progress
내 챌린지 진행상황 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/challenges/my-progress` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "내 챌린지 진행상황 조회 성공",
  "data": [
    {
      "id": "990e9500-f39c-51e5-b828-557766550000",
      "challengeId": "770e7300-d19a-31c3-9606-335544330000",
      "userId": "550e5500-e29b-41d4-a716-446655440000",
      "joinDate": "2025-01-15",
      "currentProgress": 15,
      "targetProgress": 30,
      "isCompleted": false,
      "completionDate": null,
      "earnedPoints": 0
    }
  ],
  "timestamp": "2025-10-17T12:00:00"
}
```

---

#### GET /api/v1/challenges/{challengeId}/progress
특정 챌린지 진행상황 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/challenges/{challengeId}/progress` |
| **Authentication** | Bearer Token 필수 |
| **Content-Type** | N/A |

| Path Parameters | Type | Required | Description |
|-----------------|------|----------|-------------|
| `challengeId` | UUID | ✅ | 조회할 챌린지 ID |

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "챌린지 진행상황 조회 성공",
  "data": {
    "id": "990e9500-f39c-51e5-b828-557766550000",
    "challengeId": "770e7300-d19a-31c3-9606-335544330000",
    "userId": "550e5500-e29b-41d4-a716-446655440000",
    "joinDate": "2025-01-15",
    "currentProgress": 15,
    "targetProgress": 30,
    "isCompleted": false,
    "completionDate": null,
    "earnedPoints": 0
  },
  "timestamp": "2025-10-17T12:00:00"
}
```

**Fail Response (404 Not Found - 참여하지 않은 챌린지):**
```json
{
  "success": false,
  "message": "참여하지 않은 챌린지입니다",
  "data": null,
  "timestamp": "2025-10-17T12:00:00"
}
```

---

### 2.7 게시물 관리 API

#### POST /api/v1/posts
새 게시물 작성

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/posts` |
| **Authentication** | ✅ Required (JWT Bearer Token) |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `title` | string | ✅ | 게시물 제목 | 1-100자 |
| `content` | string | ✅ | 게시물 내용 | 1-5000자 |
| `category` | string | ➖ | 카테고리 | sleep_tip, question, experience, challenge |
| `tags` | array | ➖ | 태그 목록 | 최대 10개, 각 태그 20자 이하 |
| `isPublic` | boolean | ➖ | 공개 여부 | 기본값: true |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/posts" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "깊은 잠을 위한 나만의 루틴",
    "content": "오늘은 제가 3개월 동안 실천해온 수면 루틴을 공유하려고 합니다. 매일 밤 10시에 핸드폰을 멀리 두고, 따뜻한 차를 마시며 독서를 15분 정도 하고 있어요. 이 루틴을 시작한 후로 수면의 질이 많이 개선되었습니다.",
    "category": "sleep_tip",
    "tags": ["수면루틴", "수면팁", "건강"],
    "isPublic": true
  }'
```

**Response:**

**Success Response (201 Created):**
```json
{
  "success": true,
  "message": "게시물이 성공적으로 작성되었습니다",
  "data": {
    "postId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "깊은 잠을 위한 나만의 루틴",
    "content": "오늘은 제가 3개월 동안 실천해온 수면 루틴을 공유하려고 합니다...",
    "category": "sleep_tip",
    "tags": ["수면루틴", "수면팁", "건강"],
    "isPublic": true,
    "authorId": "660e8400-e29b-41d4-a716-446655440001",
    "authorNickname": "수면왕",
    "createdAt": "2025-10-20T10:30:00Z",
    "updatedAt": "2025-10-20T10:30:00Z",
    "viewCount": 0,
    "likeCount": 0,
    "commentCount": 0
  },
  "timestamp": "2025-10-20T10:30:00Z"
}
```

**Error Response Example (400 Bad Request):**
```json
{
  "success": false,
  "message": "잘못된 요청 데이터입니다",
  "data": {
    "code": "E201",
    "message": "게시물 제목과 내용은 필수입니다",
    "fieldErrors": [
      {
        "field": "title",
        "value": "",
        "reason": "제목은 1자 이상 100자 이하여야 합니다"
      }
    ]
  },
  "timestamp": "2025-10-20T10:30:00Z"
}
```

---

#### GET /api/v1/posts
게시물 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/posts` |
| **Authentication** | ➖ Optional (인증시 더 많은 정보 제공) |
| **Content-Type** | N/A |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `page` | int | ➖ | 페이지 번호 (0부터 시작) | 0 |
| `size` | int | ➖ | 페이지 크기 | 20 |
| `category` | string | ➖ | 카테고리 필터 | all |
| `sort` | string | ➖ | 정렬 기준 | latest (latest, popular, oldest) |
| `search` | string | ➖ | 검색 키워드 | - |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/posts?page=0&size=10&category=sleep_tip&sort=popular"
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "게시물 목록 조회 성공",
  "data": {
    "posts": [
      {
        "postId": "550e8400-e29b-41d4-a716-446655440000",
        "title": "깊은 잠을 위한 나만의 루틴",
        "content": "오늘은 제가 3개월 동안 실천해온 수면 루틴을 공유하려고...",
        "category": "sleep_tip",
        "tags": ["수면루틴", "수면팁", "건강"],
        "authorId": "660e8400-e29b-41d4-a716-446655440001",
        "authorNickname": "수면왕",
        "authorProfileImage": "https://example.com/profile1.jpg",
        "createdAt": "2025-10-20T10:30:00Z",
        "viewCount": 45,
        "likeCount": 12,
        "commentCount": 3,
        "isLiked": false
      }
    ],
    "pagination": {
      "currentPage": 0,
      "totalPages": 5,
      "totalElements": 89,
      "size": 10,
      "hasNext": true,
      "hasPrevious": false
    }
  },
  "timestamp": "2025-10-20T10:30:00Z"
}
```

---

#### GET /api/v1/posts/{postId}
특정 게시물 상세 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/posts/{postId}` |
| **Authentication** | ➖ Optional |
| **Content-Type** | N/A |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `postId` | string | ✅ | 게시물 UUID |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/posts/550e8400-e29b-41d4-a716-446655440000"
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "게시물 조회 성공",
  "data": {
    "postId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "깊은 잠을 위한 나만의 루틴",
    "content": "오늘은 제가 3개월 동안 실천해온 수면 루틴을 공유하려고 합니다. 매일 밤 10시에 핸드폰을 멀리 두고, 따뜻한 차를 마시며 독서를 15분 정도 하고 있어요...",
    "category": "sleep_tip",
    "tags": ["수면루틴", "수면팁", "건강"],
    "authorId": "660e8400-e29b-41d4-a716-446655440001",
    "authorNickname": "수면왕",
    "authorProfileImage": "https://example.com/profile1.jpg",
    "createdAt": "2025-10-20T10:30:00Z",
    "updatedAt": "2025-10-20T10:30:00Z",
    "viewCount": 46,
    "likeCount": 12,
    "commentCount": 3,
    "isLiked": false,
    "comments": [
      {
        "commentId": "770e8400-e29b-41d4-a716-446655440002",
        "content": "정말 좋은 정보네요! 저도 따라해봐야겠어요.",
        "authorId": "880e8400-e29b-41d4-a716-446655440003",
        "authorNickname": "잠꾸러기",
        "authorProfileImage": "https://example.com/profile2.jpg",
        "createdAt": "2025-10-20T11:00:00Z",
        "likeCount": 2,
        "isLiked": false
      }
    ]
  },
  "timestamp": "2025-10-20T10:30:00Z"
}
```

**Error Response Example (404 Not Found):**
```json
{
  "success": false,
  "message": "게시물을 찾을 수 없습니다",
  "data": {
    "code": "E202",
    "message": "존재하지 않거나 삭제된 게시물입니다"
  },
  "timestamp": "2025-10-20T10:30:00Z"
}
```

---

#### PUT /api/v1/posts/{postId}
게시물 수정

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | PUT |
| **URL** | `/api/v1/posts/{postId}` |
| **Authentication** | ✅ Required (작성자만 가능) |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `postId` | string | ✅ | 게시물 UUID |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `title` | string | ✅ | 게시물 제목 | 1-100자 |
| `content` | string | ✅ | 게시물 내용 | 1-5000자 |
| `category` | string | ➖ | 카테고리 | sleep_tip, question, experience, challenge |
| `tags` | array | ➖ | 태그 목록 | 최대 10개, 각 태그 20자 이하 |
| `isPublic` | boolean | ➖ | 공개 여부 | - |

**Request Example:**
```bash
curl -X PUT "https://neulbo1.com/api/v1/posts/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "깊은 잠을 위한 나만의 수면 루틴 (업데이트)",
    "content": "수정된 내용입니다...",
    "category": "sleep_tip",
    "tags": ["수면루틴", "수면팁", "건강", "업데이트"],
    "isPublic": true
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "게시물이 성공적으로 수정되었습니다",
  "data": {
    "postId": "550e8400-e29b-41d4-a716-446655440000",
    "title": "깊은 잠을 위한 나만의 수면 루틴 (업데이트)",
    "content": "수정된 내용입니다...",
    "category": "sleep_tip",
    "tags": ["수면루틴", "수면팁", "건강", "업데이트"],
    "isPublic": true,
    "authorId": "660e8400-e29b-41d4-a716-446655440001",
    "authorNickname": "수면왕",
    "createdAt": "2025-10-20T10:30:00Z",
    "updatedAt": "2025-10-20T12:00:00Z",
    "viewCount": 46,
    "likeCount": 12,
    "commentCount": 3
  },
  "timestamp": "2025-10-20T12:00:00Z"
}
```

**Error Response Example (403 Forbidden):**
```json
{
  "success": false,
  "message": "권한이 없습니다",
  "data": {
    "code": "E203",
    "message": "본인이 작성한 게시물만 수정할 수 있습니다"
  },
  "timestamp": "2025-10-20T12:00:00Z"
}
```

---

#### DELETE /api/v1/posts/{postId}
게시물 삭제

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | DELETE |
| **URL** | `/api/v1/posts/{postId}` |
| **Authentication** | ✅ Required (작성자만 가능) |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `postId` | string | ✅ | 게시물 UUID |

**Request Example:**
```bash
curl -X DELETE "https://neulbo1.com/api/v1/posts/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "게시물이 성공적으로 삭제되었습니다",
  "data": null,
  "timestamp": "2025-10-20T12:00:00Z"
}
```

---

#### POST /api/v1/posts/{postId}/like
게시물 좋아요/취소

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/posts/{postId}/like` |
| **Authentication** | ✅ Required |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `postId` | string | ✅ | 게시물 UUID |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/posts/550e8400-e29b-41d4-a716-446655440000/like" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "좋아요가 추가되었습니다",
  "data": {
    "postId": "550e8400-e29b-41d4-a716-446655440000",
    "isLiked": true,
    "likeCount": 13
  },
  "timestamp": "2025-10-20T12:00:00Z"
}
```

---

#### POST /api/v1/posts/{postId}/comments
댓글 작성

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/posts/{postId}/comments` |
| **Authentication** | ✅ Required |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `postId` | string | ✅ | 게시물 UUID |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `content` | string | ✅ | 댓글 내용 | 1-500자 |
| `parentCommentId` | string | ➖ | 부모 댓글 ID (대댓글인 경우) | UUID |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/posts/550e8400-e29b-41d4-a716-446655440000/comments" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "content": "정말 유용한 정보네요! 감사합니다."
  }'
```

**Response:**

**Success Response (201 Created):**
```json
{
  "success": true,
  "message": "댓글이 성공적으로 작성되었습니다",
  "data": {
    "commentId": "770e8400-e29b-41d4-a716-446655440002",
    "content": "정말 유용한 정보네요! 감사합니다.",
    "postId": "550e8400-e29b-41d4-a716-446655440000",
    "authorId": "880e8400-e29b-41d4-a716-446655440003",
    "authorNickname": "잠꾸러기",
    "authorProfileImage": "https://example.com/profile2.jpg",
    "parentCommentId": null,
    "createdAt": "2025-10-20T12:30:00Z",
    "likeCount": 0,
    "isLiked": false
  },
  "timestamp": "2025-10-20T12:30:00Z"
}
```

---

### 2.8 친구 관리 API

#### POST /api/v1/friends/request
친구 요청 보내기

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | POST |
| **URL** | `/api/v1/friends/request` |
| **Authentication** | ✅ Required |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `targetUserId` | string | ✅ | 친구 요청을 받을 사용자 ID | UUID 형식 |
| `message` | string | ➖ | 친구 요청 메시지 | 최대 200자 |

**Request Example:**
```bash
curl -X POST "https://neulbo1.com/api/v1/friends/request" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "targetUserId": "990e8400-e29b-41d4-a716-446655440004",
    "message": "안녕하세요! 같이 수면 챌린지 하실래요?"
  }'
```

**Response:**

**Success Response (201 Created):**
```json
{
  "success": true,
  "message": "친구 요청이 성공적으로 전송되었습니다",
  "data": {
    "friendRequestId": "aa0e8400-e29b-41d4-a716-446655440005",
    "fromUserId": "660e8400-e29b-41d4-a716-446655440001",
    "toUserId": "990e8400-e29b-41d4-a716-446655440004",
    "message": "안녕하세요! 같이 수면 챌린지 하실래요?",
    "status": "PENDING",
    "createdAt": "2025-10-20T13:00:00Z"
  },
  "timestamp": "2025-10-20T13:00:00Z"
}
```

**Error Response Example (409 Conflict):**
```json
{
  "success": false,
  "message": "이미 친구 요청을 보낸 사용자입니다",
  "data": {
    "code": "E301",
    "message": "중복된 친구 요청입니다"
  },
  "timestamp": "2025-10-20T13:00:00Z"
}
```

---

#### GET /api/v1/friends/requests
받은 친구 요청 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/friends/requests` |
| **Authentication** | ✅ Required |
| **Content-Type** | N/A |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `type` | string | ➖ | 요청 타입 | received (received, sent) |
| `status` | string | ➖ | 상태 필터 | all (all, pending, accepted, rejected) |
| `page` | int | ➖ | 페이지 번호 | 0 |
| `size` | int | ➖ | 페이지 크기 | 20 |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/friends/requests?type=received&status=pending" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "친구 요청 목록 조회 성공",
  "data": {
    "friendRequests": [
      {
        "friendRequestId": "aa0e8400-e29b-41d4-a716-446655440005",
        "fromUser": {
          "userId": "660e8400-e29b-41d4-a716-446655440001",
          "nickname": "수면왕",
          "profileImage": "https://example.com/profile1.jpg"
        },
        "toUser": {
          "userId": "990e8400-e29b-41d4-a716-446655440004",
          "nickname": "잠꾸러기",
          "profileImage": "https://example.com/profile2.jpg"
        },
        "message": "안녕하세요! 같이 수면 챌린지 하실래요?",
        "status": "PENDING",
        "createdAt": "2025-10-20T13:00:00Z",
        "processedAt": null
      }
    ],
    "pagination": {
      "currentPage": 0,
      "totalPages": 1,
      "totalElements": 1,
      "size": 20,
      "hasNext": false,
      "hasPrevious": false
    }
  },
  "timestamp": "2025-10-20T13:00:00Z"
}
```

---

#### PUT /api/v1/friends/requests/{requestId}
친구 요청 응답 (수락/거절)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | PUT |
| **URL** | `/api/v1/friends/requests/{requestId}` |
| **Authentication** | ✅ Required |
| **Content-Type** | `application/json` |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |
| `Content-Type` | ✅ | `application/json` |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `requestId` | string | ✅ | 친구 요청 ID |

| Request Body | Type | Required | Description | Validation |
|--------------|------|----------|-------------|------------|
| `action` | string | ✅ | 응답 액션 | ACCEPT, REJECT |

**Request Example:**
```bash
curl -X PUT "https://neulbo1.com/api/v1/friends/requests/aa0e8400-e29b-41d4-a716-446655440005" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "action": "ACCEPT"
  }'
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "친구 요청을 수락했습니다",
  "data": {
    "friendRequestId": "aa0e8400-e29b-41d4-a716-446655440005",
    "status": "ACCEPTED",
    "processedAt": "2025-10-20T13:30:00Z",
    "friendship": {
      "friendshipId": "bb0e8400-e29b-41d4-a716-446655440006",
      "user1Id": "660e8400-e29b-41d4-a716-446655440001",
      "user2Id": "990e8400-e29b-41d4-a716-446655440004",
      "createdAt": "2025-10-20T13:30:00Z"
    }
  },
  "timestamp": "2025-10-20T13:30:00Z"
}
```

---

#### GET /api/v1/friends
친구 목록 조회

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/friends` |
| **Authentication** | ✅ Required |
| **Content-Type** | N/A |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `search` | string | ➖ | 닉네임 검색 | - |
| `page` | int | ➖ | 페이지 번호 | 0 |
| `size` | int | ➖ | 페이지 크기 | 20 |
| `sort` | string | ➖ | 정렬 기준 | name (name, recent) |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/friends?search=수면&sort=name" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "친구 목록 조회 성공",
  "data": {
    "friends": [
      {
        "friendshipId": "bb0e8400-e29b-41d4-a716-446655440006",
        "friend": {
          "userId": "990e8400-e29b-41d4-a716-446655440004",
          "nickname": "수면왕",
          "profileImage": "https://example.com/profile1.jpg",
          "isOnline": true,
          "lastSeenAt": "2025-10-20T13:25:00Z"
        },
        "friendshipDate": "2025-10-20T13:30:00Z",
        "mutualFriendsCount": 5
      }
    ],
    "pagination": {
      "currentPage": 0,
      "totalPages": 1,
      "totalElements": 1,
      "size": 20,
      "hasNext": false,
      "hasPrevious": false
    }
  },
  "timestamp": "2025-10-20T13:30:00Z"
}
```

---

#### DELETE /api/v1/friends/{friendshipId}
친구 삭제

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | DELETE |
| **URL** | `/api/v1/friends/{friendshipId}` |
| **Authentication** | ✅ Required |
| **Content-Type** | N/A |

| Headers | Required | Description |
|---------|----------|-------------|
| `Authorization` | ✅ | `Bearer {access_token}` |

| Path Parameters | Type | Required | Description |
|------------------|------|----------|-------------|
| `friendshipId` | string | ✅ | 친구 관계 ID |

**Request Example:**
```bash
curl -X DELETE "https://neulbo1.com/api/v1/friends/bb0e8400-e29b-41d4-a716-446655440006" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "친구가 성공적으로 삭제되었습니다",
  "data": null,
  "timestamp": "2025-10-20T14:00:00Z"
}
```

---

#### GET /api/v1/users/search
사용자 검색 (친구 추가용)

**Request:**

| 구분 | 내용 |
|------|------|
| **Method** | GET |
| **URL** | `/api/v1/users/search` |
| **Authentication** | ✅ Required |
| **Content-Type** | N/A |

| Query Parameters | Type | Required | Description | Default |
|------------------|------|----------|-------------|---------|
| `query` | string | ✅ | 검색어 (닉네임, 이메일) | - |
| `page` | int | ➖ | 페이지 번호 | 0 |
| `size` | int | ➖ | 페이지 크기 | 10 |

**Request Example:**
```bash
curl -X GET "https://neulbo1.com/api/v1/users/search?query=수면왕" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "사용자 검색 성공",
  "data": {
    "users": [
      {
        "userId": "990e8400-e29b-41d4-a716-446655440004",
        "nickname": "수면왕",
        "profileImage": "https://example.com/profile1.jpg",
        "friendshipStatus": "NONE",
        "mutualFriendsCount": 3
      }
    ],
    "pagination": {
      "currentPage": 0,
      "totalPages": 1,
      "totalElements": 1,
      "size": 10,
      "hasNext": false,
      "hasPrevious": false
    }
  },
  "timestamp": "2025-10-20T14:00:00Z"
}
```

**Note:** `friendshipStatus` 값:
- `NONE`: 친구 관계 없음
- `PENDING_SENT`: 내가 친구 요청을 보낸 상태
- `PENDING_RECEIVED`: 상대방이 친구 요청을 보낸 상태
- `FRIENDS`: 이미 친구 관계

---

---

## 공통 사항

### 인증
- **ML 서버**: 인증 불필요 (내부 서비스)
  - 스마트폰 센서 분석: `/api/ml/sleep/*`
  - 웨어러블 데이터 처리: `/api/ml/wearable/*`  
  - LLM 피드백: `/api/ml/llm/*`
- **Spring Boot 서버**: JWT 토큰 기반 인증 필요
  - Header: `Authorization: Bearer {access_token}`

### 에러 응답 형식

#### 4xx 클라이언트 오류
```json
{
  "error": "Bad Request",
  "message": "요청 데이터가 올바르지 않습니다",
  "timestamp": "2025-10-02T09:15:00Z",
  "path": "/api/v1/music/search"
}
```

#### 5xx 서버 오류  
```json
{
  "error": "Internal Server Error",
  "message": "서버 내부 오류가 발생했습니다",
  "timestamp": "2025-10-02T09:15:00Z",
  "path": "/api/ml/sleep/analyze"
}
```

### 페이지네이션
Spring Boot API는 표준 Spring Data 페이지네이션을 사용:
- `page`: 페이지 번호 (0부터 시작)
- `size`: 페이지 크기
- `sort`: 정렬 기준 (예: `created_at,desc`)

### 타임존
모든 timestamp는 UTC 기준으로 ISO 8601 형식 사용:
`YYYY-MM-DDTHH:mm:ss.sssZ`

### UUID 형식
모든 ID는 UUID v4 형식 사용:
`550e8400-e29b-41d4-a716-446655440000`

---

## 테스트 환경

### 도메인
- **Production**: `https://neulbo1.com`
- **Development**: `http://localhost` (개별 포트 사용)

### 서버 포트
- **ML Server**: 8000
- **Spring Boot Server**: 8080
- **Nginx Proxy**: 80, 443

### SSL 인증서
- **Provider**: Let's Encrypt
- **Domain**: neulbo1.com
- **유효기간**: 2025-12-14까지

이 명세서는 실제 코드 분석과 테스트를 통해 작성되었으며, 프로젝트 개발 시 참조용으로 활용할 수 있습니다.