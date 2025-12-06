import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../const/design_constants.dart';
import '../../models/chat_message.dart';
import '../../services/api_service.dart';
import '../../services/sleep_analysis_service.dart';

/// 수면 AI 채팅 화면
class SleepChatScreen extends StatefulWidget {
  const SleepChatScreen({super.key});

  @override
  State<SleepChatScreen> createState() => _SleepChatScreenState();
}

class _SleepChatScreenState extends State<SleepChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _currentAnalysisId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 채팅 초기화 - 분석 ID 확인 및 환영 메시지 표시
  Future<void> _initializeChat() async {
    try {
      // 분석 ID 조회
      final String? analysisId = await SleepAnalysisService.getValidAnalysisId();
      final Map<String, dynamic> status = await SleepAnalysisService.getAnalysisStatus();

      setState(() {
        _currentAnalysisId = analysisId;
      });

      // 채팅 히스토리 로드 시도
      await _loadChatHistory();

      // 히스토리가 없으면 환영 메시지 표시
      if (_messages.isEmpty) {
        setState(() {
          if (status['hasAnalysisId'] == true && status['isValid'] == true) {
            _messages.add(ChatMessage.ai(
              content: '안녕하세요! 수면 AI 어시스턴트입니다.\n\n'
                  '${status['detail']}\n\n'
                  '수면 패턴, 개선 방법 등 궁금하신 점을 자유롭게 물어보세요! 😊',
            ));
          } else {
            _messages.add(ChatMessage.ai(
              content: '안녕하세요! 수면 AI 어시스턴트입니다.\n\n'
                  '⚠️ ${status['message']}\n\n'
                  '수면 데이터를 동기화하면 더 정확한 맞춤 조언을 받을 수 있어요.',
            ));
          }
        });
      }
    } catch (error) {
      print('SleepChat - 초기화 실패: $error');
      setState(() {
        _messages.add(ChatMessage.error(
          errorMessage: '초기화 중 오류가 발생했습니다.',
        ));
      });
    }
  }

  /// 채팅 히스토리 로드 (최근 10개)
  Future<void> _loadChatHistory() async {
    try {
      print('SleepChat - 채팅 히스토리 로드 시도...');
      
      final response = await ApiService.getLlmFeedbackHistory(limit: 10);
      
      if (response.data != null && response.data is List) {
        final List<dynamic> historyData = response.data;
        
        if (historyData.isEmpty) {
          print('SleepChat - 이전 대화 내역이 없습니다');
          return;
        }

        print('SleepChat - ${historyData.length}개의 이전 대화 로드됨');

        // 히스토리를 메시지로 변환 (오래된 순서대로)
        final List<ChatMessage> historyMessages = [];
        for (final item in historyData.reversed) {
          // 사용자 질문 추가
          historyMessages.add(ChatMessage(
            id: '${item['feedback_id']}_user',
            content: item['user_prompt'] ?? '',
            isUser: true,
            timestamp: item['timestamp'] != null
                ? DateTime.parse(item['timestamp'])
                : DateTime.now(),
          ));

          // AI 응답 추가
          historyMessages.add(ChatMessage.fromApiResponse(item));
        }

        setState(() {
          _messages.addAll(historyMessages);
        });

        _scrollToBottom();
      }
    } catch (error) {
      print('SleepChat - 히스토리 로드 실패: $error');
      // 히스토리 로드 실패는 치명적이지 않으므로 에러 메시지 표시하지 않음
    }
  }

  /// 메시지 전송
  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 사용자 메시지 추가
    final ChatMessage userMessage = ChatMessage.user(content: text);
    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
    });

    _scrollToBottom();

    // 분석 ID 확인
    if (_currentAnalysisId == null) {
      final String? analysisId = await SleepAnalysisService.getValidAnalysisId();
      if (analysisId == null) {
        setState(() {
          _messages.add(ChatMessage.error(
            errorMessage: '수면 분석 데이터가 없습니다.\n\n'
                '먼저 "수면 데이터 확인하기"에서 HealthKit 데이터를 동기화해주세요.',
          ));
        });
        return;
      }
      _currentAnalysisId = analysisId;
    }

    // 로딩 메시지 추가
    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage.loading());
    });

    _scrollToBottom();

    try {
      // API 호출
      final response = await ApiService.sendLlmFeedback(
        analysisId: _currentAnalysisId!,
        userPrompt: text,
      );

      // 로딩 메시지 제거
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
      });

      // AI 응답 추가
      final ChatMessage aiMessage = ChatMessage.fromApiResponse(response.data);
      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (error) {
      print('SleepChat - 메시지 전송 실패: $error');

      // 로딩 메시지 제거
      setState(() {
        _messages.removeWhere((msg) => msg.isLoading);
      });

      // 에러 메시지 추가
      String errorMessage = '죄송합니다. 일시적인 오류가 발생했습니다.';
      
      if (error.toString().contains('분석 데이터를 찾을 수 없습니다')) {
        // 404 에러: analysis_id가 서버에 없음
        // 저장된 analysis_id를 초기화
        _currentAnalysisId = null;
        await SleepAnalysisService.clearLastAnalysisId();
        
        errorMessage = '⚠️ 수면 분석 데이터를 찾을 수 없습니다.\n\n'
            '저장된 분석 ID가 서버에 존재하지 않습니다.\n'
            '아래 단계를 따라주세요:\n\n'
            '1️⃣ 뒤로가기 버튼을 누르세요\n'
            '2️⃣ "내 프로필" → "수면 데이터 확인하기"로 이동\n'
            '3️⃣ "서버 동기화 (최근 7일)" 버튼을 눌러주세요\n'
            '4️⃣ 동기화가 완료되면 다시 질문해주세요';
      } else if (error.toString().contains('인증')) {
        errorMessage = '인증에 실패했습니다.\n다시 로그인해주세요.';
      }

      setState(() {
        _messages.add(ChatMessage.error(errorMessage: errorMessage));
        _isLoading = false;
      });
    }
  }

  /// 스크롤을 최하단으로 이동
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
            // 배경 이미지
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(DesignConstants.defaultBackgroundPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    onError: (exception, stackTrace) {
                      print('수면 채팅 배경 이미지 로드 실패: $exception');
                    },
                  ),
                  color: const Color(0xFF2D1B69),
                ),
              ),
            ),
            // 채팅 UI
            SafeArea(
              child: Column(
                children: [
                  // 헤더
                  _buildHeader(),
                  // 채팅 메시지 리스트
                  Expanded(
                    child: _buildMessageList(),
                  ),
                  // 입력창
                  _buildInputArea(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 위젯
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // 뒤로가기 버튼
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFAF99FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bedtime,
              color: Color(0xFFAF99FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '수면 AI 어시스턴트',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'suit',
                  ),
                ),
                Text(
                  '수면 전문가가 답변드려요',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
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

  /// 메시지 리스트 위젯
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFAF99FF),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  /// 메시지 버블 위젯
  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    final bool isLoading = message.isLoading;
    final bool isError = message.isError;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI 아바타
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFAF99FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Color(0xFFAF99FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 메시지 내용
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFFAF99FF)
                    : isError
                        ? Colors.red.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isError
                      ? Colors.red.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isUser ? const Color(0xFF2D1B69) : const Color(0xFFAF99FF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isUser ? const Color(0xFF2D1B69) : Colors.white,
                            fontSize: 14,
                            fontFamily: 'suit',
                          ),
                        ),
                      ],
                    )
                  else if (isUser)
                    // 사용자 메시지는 일반 텍스트
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? const Color(0xFF2D1B69) : Colors.white,
                        fontSize: 14,
                        fontFamily: 'suit',
                        height: 1.5,
                      ),
                    )
                  else
                    // AI 메시지는 마크다운 렌더링
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'suit',
                          height: 1.5,
                        ),
                        h1: const TextStyle(
                          color: Color(0xFFAF99FF),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'suit',
                        ),
                        h2: const TextStyle(
                          color: Color(0xFFAF99FF),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'suit',
                        ),
                        h3: const TextStyle(
                          color: Color(0xFFAF99FF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'suit',
                        ),
                        strong: const TextStyle(
                          color: Color(0xFFAF99FF),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'suit',
                        ),
                        em: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                          fontFamily: 'suit',
                        ),
                        code: TextStyle(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          color: const Color(0xFFAF99FF),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        blockquote: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontFamily: 'suit',
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(
                            left: BorderSide(
                              color: const Color(0xFFAF99FF),
                              width: 4,
                            ),
                          ),
                        ),
                        listBullet: const TextStyle(
                          color: Color(0xFFAF99FF),
                          fontFamily: 'suit',
                        ),
                        a: const TextStyle(
                          color: Color(0xFFAF99FF),
                          decoration: TextDecoration.underline,
                          fontFamily: 'suit',
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    message.formattedTime,
                    style: TextStyle(
                      color: isUser
                          ? const Color(0xFF2D1B69).withOpacity(0.6)
                          : Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontFamily: 'suit',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 입력창 위젯
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !_isLoading,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'suit',
                ),
                decoration: InputDecoration(
                  hintText: '수면에 대해 궁금한 점을 물어보세요...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontFamily: 'suit',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFAF99FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: Icon(
                _isLoading ? Icons.hourglass_empty : Icons.send,
                color: const Color(0xFF2D1B69),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

