/// 채팅 메시지 데이터 모델
/// 
/// 사용자와 AI 간의 대화 메시지를 표현합니다.
class ChatMessage {
  /// 메시지 고유 ID
  final String id;

  /// 메시지 내용
  final String content;

  /// 사용자 메시지 여부 (true: 사용자, false: AI)
  final bool isUser;

  /// 메시지 생성 시간
  final DateTime timestamp;

  /// 로딩 중 여부 (AI 응답 대기 중)
  final bool isLoading;

  /// 에러 메시지 여부
  final bool isError;

  /// 피드백 ID (AI 응답인 경우)
  final String? feedbackId;

  /// 분석 요약 정보 (AI 응답인 경우)
  final String? analysisSummary;

  /// LLM 모델 정보 (AI 응답인 경우)
  final String? llmModel;

  /// 응답 시간 (밀리초, AI 응답인 경우)
  final double? responseTimeMs;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.isError = false,
    this.feedbackId,
    this.analysisSummary,
    this.llmModel,
    this.responseTimeMs,
  });

  /// 사용자 메시지 생성
  factory ChatMessage.user({
    required String content,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      isLoading: false,
      isError: false,
    );
  }

  /// AI 메시지 생성
  factory ChatMessage.ai({
    required String content,
    String? feedbackId,
    String? analysisSummary,
    String? llmModel,
    double? responseTimeMs,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: false,
      isError: false,
      feedbackId: feedbackId,
      analysisSummary: analysisSummary,
      llmModel: llmModel,
      responseTimeMs: responseTimeMs,
    );
  }

  /// 로딩 메시지 생성 (AI 응답 대기 중)
  factory ChatMessage.loading() {
    return ChatMessage(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      content: 'AI가 답변을 생성하고 있습니다...',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
      isError: false,
    );
  }

  /// 에러 메시지 생성
  factory ChatMessage.error({
    required String errorMessage,
  }) {
    return ChatMessage(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      content: errorMessage,
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: false,
      isError: true,
    );
  }

  /// API 응답으로부터 AI 메시지 생성
  factory ChatMessage.fromApiResponse(Map<String, dynamic> response) {
    return ChatMessage(
      id: response['feedback_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: response['llm_response'] ?? '',
      isUser: false,
      timestamp: response['timestamp'] != null
          ? DateTime.parse(response['timestamp'])
          : DateTime.now(),
      isLoading: false,
      isError: false,
      feedbackId: response['feedback_id'],
      analysisSummary: response['analysis_summary'],
      llmModel: response['llm_model'],
      responseTimeMs: response['response_time_ms']?.toDouble(),
    );
  }

  /// 시간 포맷팅 (HH:mm)
  String get formattedTime {
    final String hour = timestamp.hour.toString().padLeft(2, '0');
    final String minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 날짜 포맷팅 (yyyy-MM-dd)
  String get formattedDate {
    final String year = timestamp.year.toString();
    final String month = timestamp.month.toString().padLeft(2, '0');
    final String day = timestamp.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 오늘 메시지인지 확인
  bool get isToday {
    final DateTime now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  /// 복사 메서드 (불변성 유지)
  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
    bool? isError,
    String? feedbackId,
    String? analysisSummary,
    String? llmModel,
    double? responseTimeMs,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      feedbackId: feedbackId ?? this.feedbackId,
      analysisSummary: analysisSummary ?? this.analysisSummary,
      llmModel: llmModel ?? this.llmModel,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
    );
  }

  /// JSON 변환 (로컬 저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isLoading': isLoading,
      'isError': isError,
      'feedbackId': feedbackId,
      'analysisSummary': analysisSummary,
      'llmModel': llmModel,
      'responseTimeMs': responseTimeMs,
    };
  }

  /// JSON으로부터 생성 (로컬 저장 복원용)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLoading: json['isLoading'] as bool? ?? false,
      isError: json['isError'] as bool? ?? false,
      feedbackId: json['feedbackId'] as String?,
      analysisSummary: json['analysisSummary'] as String?,
      llmModel: json['llmModel'] as String?,
      responseTimeMs: json['responseTimeMs']?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, content: $content, isUser: $isUser, timestamp: $timestamp, isLoading: $isLoading, isError: $isError)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage &&
        other.id == id &&
        other.content == content &&
        other.isUser == isUser &&
        other.timestamp == timestamp &&
        other.isLoading == isLoading &&
        other.isError == isError;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        content.hashCode ^
        isUser.hashCode ^
        timestamp.hashCode ^
        isLoading.hashCode ^
        isError.hashCode;
  }
}


