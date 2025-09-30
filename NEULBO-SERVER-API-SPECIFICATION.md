# NEULBO-SERVER (Spring Boot) API 명세서

## 🏗️ **시스템 개요**

**서버 타입**: Spring Boot (REST API)  
**베이스 URL**: `https://neulbo1.com`  
**API 버전**: v1  
**인증 방식**: JWT Bearer Token  
**응답 형식**: JSON  

모든 API 엔드포인트는 자동으로 `/api/v1` prefix가 적용됩니다.

---

## 🔐 **인증 시스템**

### **1. OAuth 로그인**

#### **OAuth 로그인 (리액티브)**
```http
POST /api/v1/oauth/login/{provider}
```

**지원 제공자**: `google`, `kakao`, `naver`

**요청 바디**:
```json
{
  "code": "authorization_code_from_oauth_provider"
}
```

**응답 성공 (200)**:
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "isNewUser": true
}
```

**오류 응답**:
- `400`: 잘못된 요청 (코드 누락)
- `401`: 인증 실패 (잘못된 코드)
- `404`: 지원하지 않는 OAuth 제공자

---

### **2. 토큰 관리**

#### **액세스 토큰 갱신**
```http
POST /api/v1/auth/tokens/refresh
```

**헤더**:
```
Authorization: Bearer {refresh_token}
```

**응답 성공 (200)**:
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**오류 응답**:
- `400`: 리프레시 토큰 누락
- `401`: 유효하지 않은 리프레시 토큰

#### **로그아웃**
```http
POST /api/v1/auth/logout
```

**헤더**:
```
Authorization: Bearer {access_token}
```

**응답 성공 (200)**:
```json
{
  "message": "로그아웃 되었습니다"
}
```

---

## 👤 **사용자 관리**

### **1. 프로필 조회**
```http
GET /api/v1/users/me/profile
```

**헤더**:
```
Authorization: Bearer {access_token}
```

**응답 성공 (200)**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "사용자닉네임",
  "email": "user@example.com",
  "fullName": "홍길동",
  "profileImage": "https://example.com/profile.jpg",
  "birth": "1990-01-01",
  "isPrivate": false,
  "currentPoints": 1250,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**오류 응답**:
- `401`: 인증되지 않은 사용자
- `404`: 사용자를 찾을 수 없음

### **2. 프로필 수정**
```http
PUT /api/v1/users/me/profile
```

**요청 바디**:
```json
{
  "username": "새닉네임",
  "fullName": "홍길동",
  "email": "newemail@example.com",
  "birth": "1990-01-01",
  "isPrivate": false
}
```

**응답 성공 (200)**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "새닉네임",
  "email": "newemail@example.com",
  "fullName": "홍길동",
  "profileImage": "https://example.com/profile.jpg",
  "birth": "1990-01-01",
  "isPrivate": false,
  "currentPoints": 1250,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### **3. 계정 정보 조회**
```http
GET /api/v1/users/me/account
```

**응답 성공 (200)**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "provider": "google",
  "providerId": "google_user_id_123",
  "username": "사용자닉네임",
  "email": "user@example.com",
  "fullName": "홍길동",
  "isPrivate": false,
  "profileImage": "https://example.com/profile.jpg"
}
```

### **4. 계정 삭제**
```http
DELETE /api/v1/users/me/account
```

**응답 성공 (200)**:
```json
{
  "message": "계정이 삭제되었습니다"
}
```

### **5. 프로필 이미지 수정**
```http
PUT /api/v1/users/me/profile-image
```

**요청 바디**:
```json
{
  "profileImage": "https://example.com/new-profile.jpg"
}
```

**응답 성공 (200)**:
```json
{
  "profileImage": "https://example.com/new-profile.jpg"
}
```

---

## 🎵 **음악 관리**

### **1. 음악 목록 조회 (페이지네이션)**
```http
GET /api/v1/music?page=0&size=20&sort=title,asc
```

**쿼리 파라미터**:
- `page`: 페이지 번호 (기본값: 0)
- `size`: 페이지 크기 (기본값: 20)
- `sort`: 정렬 기준 (title, artist, duration 등)

**응답 성공 (200)**:
```json
{
  "content": [
    {
      "id": "music-uuid-1",
      "title": "잔잔한 클래식",
      "artist": "베토벤",
      "duration": 300,
      "categoryId": "category-uuid-1",
      "categoryName": "클래식",
      "fileUrl": "https://example.com/music1.mp3",
      "thumbnailUrl": "https://example.com/thumb1.jpg"
    }
  ],
  "pageable": {
    "sort": {
      "sorted": true,
      "direction": "ASC"
    },
    "pageNumber": 0,
    "pageSize": 20
  },
  "totalElements": 100,
  "totalPages": 5
}
```

### **2. 카테고리별 음악 조회**
```http
GET /api/v1/music/category/{categoryId}?page=0&size=20
```

**응답**: 음악 목록 조회와 동일한 형식

### **3. 음악 검색**
```http
GET /api/v1/music/search?keyword=베토벤&page=0&size=20
```

**쿼리 파라미터**:
- `keyword`: 검색 키워드 (1-100자)
- `page`, `size`: 페이지네이션

### **4. 인기 음악 조회**
```http
GET /api/v1/music/popular?limit=10
```

**쿼리 파라미터**:
- `limit`: 조회할 음악 수 (1-100, 기본값: 10)

**응답 성공 (200)**:
```json
[
  {
    "id": "music-uuid-1",
    "title": "인기 음악 1",
    "artist": "아티스트",
    "duration": 240,
    "categoryId": "category-uuid-1",
    "categoryName": "팝",
    "fileUrl": "https://example.com/music1.mp3",
    "thumbnailUrl": "https://example.com/thumb1.jpg",
    "playCount": 1500
  }
]
```

### **5. 특정 음악 상세 조회**
```http
GET /api/v1/music/{musicId}
```

**응답 성공 (200)**:
```json
{
  "id": "music-uuid-1",
  "title": "음악 제목",
  "artist": "아티스트",
  "duration": 300,
  "categoryId": "category-uuid-1",
  "categoryName": "클래식",
  "fileUrl": "https://example.com/music1.mp3",
  "thumbnailUrl": "https://example.com/thumb1.jpg",
  "description": "음악 설명",
  "playCount": 1200
}
```

---

## 📂 **카테고리 관리**

### **1. 활성 카테고리 목록 조회**
```http
GET /api/v1/categories
```

**응답 성공 (200)**:
```json
[
  {
    "id": "category-uuid-1",
    "name": "클래식",
    "description": "클래식 음악 카테고리",
    "isActive": true,
    "musicCount": 25
  },
  {
    "id": "category-uuid-2",
    "name": "재즈",
    "description": "재즈 음악 카테고리",
    "isActive": true,
    "musicCount": 18
  }
]
```

### **2. 모든 카테고리 조회 (관리자 전용)**
```http
GET /api/v1/categories/all
```

**권한**: ADMIN 역할 필요

### **3. 특정 카테고리 조회**
```http
GET /api/v1/categories/{categoryId}
```

**응답 성공 (200)**:
```json
{
  "id": "category-uuid-1",
  "name": "클래식",
  "description": "클래식 음악 카테고리",
  "isActive": true,
  "musicCount": 25
}
```

---

## 🏆 **챌린지 시스템**

### **1. 챌린지 목록 조회**
```http
GET /api/v1/challenges
```

**응답 성공 (200)**:
```json
[
  {
    "id": "challenge-uuid-1",
    "title": "7일 연속 수면 기록",
    "description": "7일 동안 매일 수면을 기록하세요",
    "type": "STREAK",
    "targetValue": 7,
    "rewardPoints": 100,
    "isActive": true,
    "startDate": "2024-01-01",
    "endDate": "2024-12-31"
  }
]
```

### **2. 챌린지 참여**
```http
POST /api/v1/challenges/{challengeId}/join
```

**응답 성공 (200)**:
```json
{
  "id": "user-challenge-uuid-1",
  "challengeId": "challenge-uuid-1",
  "userId": "user-uuid-1",
  "joinedAt": "2024-01-01T00:00:00Z",
  "status": "IN_PROGRESS",
  "currentValue": 0,
  "isCompleted": false
}
```

### **3. 내 챌린지 진행 상황 조회**
```http
GET /api/v1/challenges/my-progress
```

**응답 성공 (200)**:
```json
[
  {
    "id": "user-challenge-uuid-1",
    "challenge": {
      "id": "challenge-uuid-1",
      "title": "7일 연속 수면 기록",
      "targetValue": 7,
      "rewardPoints": 100
    },
    "status": "IN_PROGRESS",
    "currentValue": 3,
    "progressPercentage": 42.8,
    "isCompleted": false,
    "joinedAt": "2024-01-01T00:00:00Z"
  }
]
```

### **4. 챌린지 포기**
```http
DELETE /api/v1/challenges/{challengeId}/quit
```

**응답 성공 (200)**:
```json
{
  "message": "챌린지를 포기했습니다"
}
```

---

## 🎧 **플레이리스트 관리**

### **1. 내 플레이리스트 목록 조회**
```http
GET /api/v1/playlists/my
```

**응답 성공 (200)**:
```json
[
  {
    "id": "playlist-uuid-1",
    "name": "내가 만든 플레이리스트",
    "description": "잠들기 전 듣는 음악",
    "isPublic": false,
    "musicCount": 12,
    "totalDuration": 3600,
    "createdAt": "2024-01-01T00:00:00Z"
  }
]
```

### **2. 플레이리스트 생성**
```http
POST /api/v1/playlists
```

**요청 바디**:
```json
{
  "name": "새 플레이리스트",
  "description": "설명",
  "isPublic": false
}
```

### **3. 플레이리스트에 음악 추가**
```http
POST /api/v1/playlists/{playlistId}/music/{musicId}
```

### **4. 플레이리스트에서 음악 제거**
```http
DELETE /api/v1/playlists/{playlistId}/music/{musicId}
```

---

## 🏥 **시스템 헬스체크**

### **1. 기본 헬스체크**
```http
GET /actuator/health
```

**응답 성공 (200)**:
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    },
    "redis": {
      "status": "UP",
      "details": {
        "version": "7.0"
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 250685575168,
        "free": 176885571584,
        "threshold": 10485760
      }
    }
  }
}
```

**오류 상황**:
- `503`: 일부 또는 전체 시스템 장애

---

## ⚠️ **공통 오류 응답**

### **인증 오류**
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "status": 401,
  "error": "Unauthorized",
  "message": "인증이 필요합니다",
  "path": "/api/v1/users/me/profile"
}
```

### **권한 오류**
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "status": 403,
  "error": "Forbidden",
  "message": "권한이 없습니다",
  "path": "/api/v1/categories/all"
}
```

### **리소스 없음**
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "status": 404,
  "error": "Not Found",
  "message": "리소스를 찾을 수 없습니다",
  "path": "/api/v1/music/non-existent-id"
}
```

### **유효성 검사 실패**
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "유효성 검사 실패",
  "errors": [
    {
      "field": "username",
      "message": "사용자명은 필수입니다"
    }
  ]
}
```

### **서버 내부 오류**
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "status": 500,
  "error": "Internal Server Error",
  "message": "서버 내부 오류가 발생했습니다"
}
```

---

## 📝 **사용 예시**

### **1. 사용자 로그인 및 프로필 조회**
```bash
# 1. OAuth 로그인
curl -X POST http://localhost:8080/api/v1/oauth/login/google \
  -H "Content-Type: application/json" \
  -d '{"code": "google_auth_code"}'

# 2. 응답에서 accessToken 추출하여 프로필 조회
curl -X GET http://localhost:8080/api/v1/users/me/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### **2. 음악 검색 및 플레이리스트 추가**
```bash
# 1. 음악 검색
curl -X GET "http://localhost:8080/api/v1/music/search?keyword=베토벤" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# 2. 플레이리스트 생성
curl -X POST http://localhost:8080/api/v1/playlists \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "클래식 모음", "description": "좋아하는 클래식", "isPublic": false}'

# 3. 플레이리스트에 음악 추가
curl -X POST http://localhost:8080/api/v1/playlists/PLAYLIST_ID/music/MUSIC_ID \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 🔧 **개발 환경 설정**

### **로컬 서버 실행**
```bash
# Docker Compose로 실행
docker compose -f docker-compose.clean.yml up -d

# 서버 상태 확인
curl http://localhost:8080/actuator/health
```

### **환경 변수**
- `SPRING_PROFILES_ACTIVE`: 실행 프로필 (local, production)
- `JWT_SECRET_KEY`: JWT 토큰 암호화 키
- `DB_URL`: PostgreSQL 연결 URL
- `SPRING_REDIS_HOST`: Redis 서버 호스트
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`: Google OAuth 설정


