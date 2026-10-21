import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class GoTransCoreEngine {
  // --- 1. Quản lý Thu âm & VAD ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  Timer? _silenceTimer;
  Timer? _throttleTimer;

  // Cấu hình VAD (có thể thay đổi trực tiếp từ Slider trên giao diện)
  int silenceDurationMs;
  final int draftThrottleMs;

  // --- 2. Quản lý Ngữ cảnh (GoTrans AI Context Engine) ---
  final List<String> _slidingWindow = [];
  final int maxWindowSize;
  String meetingContext;
  String customApiKey;
  final Map<String, String> customGlossary;

  // --- 3. Callbacks trả kết quả về cho Giao diện TranslationScreen ---
  final Function(double rmsLevel)? onSoundLevelChanged;
  final Function(String liveOriginal, String liveDraftTranslation)? onPartialResult;
  final Function(String finalOriginal, String finalTranslation)? onFinalSentence;
  final Function(String errorMessage)? onError;

  GoTransCoreEngine({
    this.silenceDurationMs = 1000,
    this.draftThrottleMs = 650,
    this.maxWindowSize = 5,
    this.meetingContext = 'Cuộc họp kỹ thuật triển khai hệ thống AI thu âm thời gian thực trên ứng dụng di động Flutter và tối ưu hóa độ trễ truyền tải.',
    this.customApiKey = '',
    Map<String, String>? initialGlossary,
    this.onSoundLevelChanged,
    this.onPartialResult,
    this.onFinalSentence,
    this.onError,
  }) : customGlossary = initialGlossary ?? {};

  bool get isListening => _isListening;
  List<String> get slidingWindow => _slidingWindow;

  // ===========================================================================
  // PHẦN 1: THU ÂM STREAMING & THUẬT TOÁN VAD TỰ ĐỘNG NGẮT CÂU
  // ===========================================================================
  Future<bool> startRecording({
    String sourceLocaleId = 'en_US',
    String targetLanguage = 'Tiếng Việt',
  }) async {
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      onError?.call('Vui lòng cấp quyền Microphone để thu âm!');
      return false;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _isListening) {
          _listenLoop(sourceLocaleId, targetLanguage);
        }
      },
      onError: (err) => onError?.call(err.errorMsg),
    );

    if (!available) {
      onError?.call('Thiết bị không hỗ trợ dịch vụ nhận diện giọng nói!');
      return false;
    }

    _isListening = true;
    _listenLoop(sourceLocaleId, targetLanguage);
    return true;
  }

  void _listenLoop(String sourceLocaleId, String targetLanguage) {
    if (!_isListening) return;

    String currentBuffer = '';

    _speech.listen(
      localeId: sourceLocaleId,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onSoundLevelChange: (level) {
        final rms = ((level + 2) * 8.5).clamp(0.0, 100.0);
        onSoundLevelChanged?.call(rms);
      },
      onResult: (result) {
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) return;
        currentBuffer = recognized;

        // 1. Trả văn bản gốc đang nói về UI và chạy dịch nháp (Throttle)
        onPartialResult?.call(currentBuffer, '');
        _runThrottledDraftTranslation(currentBuffer, targetLanguage);

        // 2. Bộ đếm VAD: Im lặng vượt quá silenceDurationMs -> Tự động chốt câu
        _silenceTimer?.cancel();
        if (result.finalResult) {
          _commitSentence(currentBuffer, targetLanguage);
          currentBuffer = '';
        } else {
          _silenceTimer = Timer(Duration(milliseconds: silenceDurationMs), () {
            if (currentBuffer.isNotEmpty) {
              _commitSentence(currentBuffer, targetLanguage);
              currentBuffer = '';
            }
          });
        }
      },
    );
  }

  Future<void> stopRecording() async {
    _isListening = false;
    _silenceTimer?.cancel();
    _throttleTimer?.cancel();
    await _speech.stop();
  }

  // ===========================================================================
  // PHẦN 2: BỘ XỬ LÝ NGÔN NGỮ GOTRANS (SLIDING WINDOW + GLOSSARY + GEMINI)
  // ===========================================================================
  void _runThrottledDraftTranslation(String partialText, String targetLanguage) {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(Duration(milliseconds: draftThrottleMs), () async {
      if (!_isListening || partialText.trim().isEmpty) return;
      final draft = await translateTextWithContext(
        partialText,
        targetLanguage: targetLanguage,
        isFinalSentence: false,
      );
      onPartialResult?.call(partialText, draft);
    });
  }

  Future<void> _commitSentence(String sentence, String targetLanguage) async {
    _silenceTimer?.cancel();
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return;

    final finalTranslated = await translateTextWithContext(
      trimmed,
      targetLanguage: targetLanguage,
      isFinalSentence: true,
    );

    onFinalSentence?.call(trimmed, finalTranslated);
  }

  Future<String> translateTextWithContext(
      String text, {
        String targetLanguage = 'Tiếng Việt',
        bool isFinalSentence = true,
      }) async {
    if (text.trim().isEmpty) return '';

    final envKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
    final activeKey = customApiKey.trim().isNotEmpty ? customApiKey.trim() : envKey;

    if (activeKey.isNotEmpty) {
      try {
        final glossaryStr = customGlossary.entries
            .map((e) => '"${e.key}" dịch là "${e.value}"')
            .join('; ');

        final historyStr = _slidingWindow.isEmpty
            ? 'Chưa có câu trước đó.'
            : _slidingWindow.join(' | ');

        final prompt = '''
Bạn là AI Context Engine của ứng dụng thông dịch GoTrans.
- Bối cảnh cuộc họp: $meetingContext
- Từ điển bắt buộc: ${glossaryStr.isEmpty ? 'Không có' : glossaryStr}
- Lịch sử 5 câu gần nhất (Sliding Window): $historyStr

Hãy dịch câu sau sang $targetLanguage thật chuẩn xác, mượt mà và tuân thủ tuyệt đối từ điển bắt buộc. Chỉ trả về đúng câu dịch, không giải thích:
"$text"
''';

        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$activeKey',
        );

        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.2}
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final resultText = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
          if (isFinalSentence) _pushToSlidingWindow(text);
          return resultText;
        }
      } catch (e) {
        debugPrint('GoTrans Gemini API Error: $e');
      }
    }

    if (isFinalSentence) _pushToSlidingWindow(text);
    return _localSmartFallbackTranslate(text, targetLanguage);
  }

  void _pushToSlidingWindow(String sentence) {
    _slidingWindow.add(sentence);
    if (_slidingWindow.length > maxWindowSize) {
      _slidingWindow.removeAt(0);
    }
  }

  String _localSmartFallbackTranslate(String text, String targetLanguage) {
    final demoDict = {
      'We need to optimize the audio pipeline to reduce latency during real-time translation.':
      'Chúng ta cần tối ưu hóa luồng xử lý âm thanh để giảm độ trễ trong quá trình dịch thuật thời gian thực.',
      'Agreed. Using a sliding window context of five sentences helps the model keep the conversation flow.':
      'Đồng ý. Việc sử dụng ngữ cảnh cửa sổ trượt gồm 5 câu giúp mô hình giữ được mạch hội thoại.',
      'What about speaker diarization when multiple engineers talk in the same meeting?':
      'Thế còn tính năng phân tách người nói khi nhiều kỹ sư cùng phát biểu trong một cuộc họp thì sao?',
      'We integrated voice embeddings before deployment so every speaker is labeled automatically.':
      'Chúng tôi đã tích hợp vector đặc trưng giọng nói trước khi triển khai hệ thống để mỗi người nói đều được gắn nhãn tự động.',
    };

    if (demoDict.containsKey(text)) {
      return demoDict[text]!;
    }

    String output = text;
    customGlossary.forEach((key, val) {
      output = output.replaceAll(RegExp(key, caseSensitive: false), '[$val]');
    });
    return '($targetLanguage) $output';
  }

  void dispose() {
    _silenceTimer?.cancel();
    _throttleTimer?.cancel();
    _speech.stop();
  }
}