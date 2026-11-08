import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../services/gotrans_core_enginer.dart';
import '../services/gemini_service.dart';

class TranslationSegment {
  String speakerId;
  final String originalText;
  final String translatedText;
  final String timestamp;
  final String sourceLanguage;
  final String targetLanguage;
  Color speakerColor;

  TranslationSegment({
    required this.speakerId,
    required this.originalText,
    required this.translatedText,
    required this.timestamp,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.speakerColor,
  });
}

class TwoWayTranslationScreen extends StatefulWidget {
  final Function(String)? onHistoryAdded;
  final VoidCallback? onBack;
  final VoidCallback? onNewChat;
  final VoidCallback? onViewHistory;
  final Function(String)? onLoadFromHistory;
  final Function(bool isTwoWay)? onModeChanged;
  final List<String> historyItems;

  const TwoWayTranslationScreen({
    super.key,
    this.onHistoryAdded,
    this.onBack,
    this.onNewChat,
    this.onViewHistory,
    this.onLoadFromHistory,
    this.onModeChanged,
    this.historyItems = const [],
  });

  @override
  State<TwoWayTranslationScreen> createState() => TwoWayTranslationScreenState();
}

class TwoWayTranslationScreenState extends State<TwoWayTranslationScreen> with TickerProviderStateMixin {
  String _sourceLang = 'Tự động';
  String _targetLang = 'Việt';

  final List<TranslationSegment> _segments = [];
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  final _geminiService = GeminiService();


  final FlutterTts _flutterTts = FlutterTts();
  late final GoTransCoreEngine _gotransEngine;

  bool _isRecording = false;
  bool _isStarting = false;
  bool _isPaused = false;
  
  final TextEditingController _textController = TextEditingController();
  bool _isTranslatingText = false;
  // ignore: unused_field
  DateTime? _startTime;
  double _rmsLevel = 0.0;

  Timer? _timer;
  Duration _recordDuration = Duration.zero;

  bool _sourceTtsEnabled = false;
  bool _targetTtsEnabled = false;

  String _liveSourceText = "";
  String _liveTargetText = "";

  late AnimationController _btnAnimController;

  final Map<String, Color> _speakerColors = {};
  final List<Color> _availableSpeakerColors = [
    Colors.blueAccent,
    Colors.greenAccent.shade700,
    Colors.deepPurpleAccent,
    Colors.orangeAccent.shade700,
    Colors.tealAccent.shade700,
    Colors.pinkAccent,
    Colors.indigoAccent,
    Colors.cyanAccent.shade700,
  ];

  int _currentSpeakerId = 1;

  static const Color bgColor = Color(0xFFF9FAFB);
  static const Color panelBg = Colors.white;
  static const Color accentOrange = Color(0xFFFF7043);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color lightBlueBg = Color(0xFFF4F7FF);

  static const Map<String, String> _langToLocale = {
    'Tự động': 'auto',
    'Việt': 'vi-VN',
    'Anh': 'en-US',
    'Nhật': 'ja-JP',
    'Hàn': 'ko-KR',
    'Trung (Giản)': 'zh-CN',
    'Trung (Phồn)': 'zh-TW',
    'Pháp': 'fr-FR',
    'Đức': 'de-DE',
    'Tây Ban Nha': 'es-ES',
    'Ý': 'it-IT',
    'Nga': 'ru-RU',
    'Thái': 'th-TH',
    'Indonesia': 'id-ID',
  };

  static const List<String> _suggestedLangs = ['Việt', 'Anh', 'Nhật', 'Hàn', 'Trung (Giản)'];
  static const List<String> _allLangs = [
    'Afrikaans', 'Albania', 'Amharic', 'Ả Rập', 'Armenia', 'Azerbaijan',
    'Ba Lan', 'Ba Tư', 'Bantu', 'Belarus', 'Bengal', 'Bosnia', 'Bồ Đào Nha',
    'Bulgaria', 'Catalan', 'Cebuano', 'Chichewa', 'Corsica', 'Croatia',
    'Do Thái', 'Đan Mạch', 'Đức', 'Estonia', 'Filipino', 'Phần Lan',
    'Pháp', 'Frisia', 'Gaelic Scotland', 'Galician', 'Georgia', 'Gujarati',
    'Hà Lan', 'Haiti', 'Hausa', 'Hawaii', 'Hindi', 'Hmong', 'Hy Lạp',
    'Hungary', 'Iceland', 'Igbo', 'Indonesia', 'Ireland', 'Ý', 'Java',
    'Kannada', 'Kazakh', 'Khmer', 'Kinyarwanda', 'Hàn', 'Kurd', 'Kyrgyz',
    'Lào', 'Latinh', 'Latvia', 'Litva', 'Luxembourg', 'Macedonia', 'Malagasy',
    'Mã Lai', 'Malayalam', 'Malta', 'Maori', 'Marathi', 'Mông Cổ', 'Myanmar',
    'Na Uy', 'Nepal', 'Nhật', 'Pashto', 'Pháp', 'Punjabi', 'Rumani',
    'Nga', 'Samoa', 'Séc', 'Serbia', 'Sesotho', 'Shona', 'Sindhi',
    'Sinhala', 'Slovak', 'Slovenia', 'Somali', 'Tây Ban Nha', 'Sunda', 'Swahili',
    'Thụy Điển', 'Tajik', 'Tamil', 'Tatar', 'Telugu', 'Thái', 'Thổ Nhĩ Kỳ',
    'Turkmen', 'Triều Tiên', 'Trung (Giản)', 'Trung (Phồn)', 'Ukraine', 'Urdu',
    'Uyghur', 'Uzbek', 'Việt', 'Xhosa', 'Yiddish', 'Yoruba', 'Zulu'
  ];

  final GlobalKey _sourceLangBtnKey = GlobalKey(); // Cho 1 chiều
  final GlobalKey _targetLangBtnKey = GlobalKey(); // Cho 1 chiều
  
  final GlobalKey _leftSpeakBtnKey = GlobalKey();
  final GlobalKey _leftTransBtnKey = GlobalKey();
  final GlobalKey _rightSpeakBtnKey = GlobalKey();
  final GlobalKey _rightTransBtnKey = GlobalKey();

  bool _isTwoWayMode = false;

  String get currentConversationSummary => _segments.isNotEmpty ? _segments.last.originalText : "";

  void forceOneWayMode() {
    if (!mounted) return;
    setState(() {
      _isTwoWayMode = false;
      if (_sourceLang != 'Tự động') {
        _sourceLang = 'Tự động';
      }
    });
  }

  void forceTwoWayMode() {
    if (!mounted) return;
    setState(() {
      _isTwoWayMode = true;
      if (_sourceLang == 'Tự động') {
        _sourceLang = 'Việt';
      }
    });
  }

  void stopRecordingAndTTS() {
    if (_isRecording) {
      _gotransEngine.stopRecording();
      _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
      }
    }
  }

  void resetChat() {
    if (!mounted) return;
    setState(() {
      _segments.clear();
      _liveSourceText = "";
      _liveTargetText = "";
      _recordDuration = Duration.zero;
      _gotransEngine.slidingWindow.clear();
      _gotransEngine.resetSpeakerProfiles();
      _speakerColors.clear();
      _currentSpeakerId = 1;
      _gotransEngine.setSpeaker(1);
    });
  }

  void loadConversation(String text) {
    if (!mounted) return;
    setState(() {
      _segments.clear();
      String sId = "Speaker 01";
      _segments.add(TranslationSegment(
        speakerId: sId,
        originalText: text,
        translatedText: text,
        timestamp: "00:00",
        sourceLanguage: _sourceLang,
        targetLanguage: _targetLang,
        speakerColor: _getSpeakerColor(sId),
      ));
      _liveSourceText = "";
      _liveTargetText = "";
    });
  }

  Color _getSpeakerColor(String speakerId) {
    if (!_speakerColors.containsKey(speakerId)) {
      _speakerColors[speakerId] = _availableSpeakerColors[_speakerColors.length % _availableSpeakerColors.length];
    }
    return _speakerColors[speakerId]!;
  }

  Future<List<InputDevice>> getAvailableInputDevices() => _gotransEngine.getInputDevices();
  void setInputDevice(InputDevice device) => _gotransEngine.setInputDevice(device);
  void setTtsVolume(double volume) => _gotransEngine.setTtsVolume(volume);
  void setTtsSpeechRate(double rate) => _gotransEngine.setTtsSpeechRate(rate);
  double get ttsVolume => _gotransEngine.ttsVolume;
  double get ttsSpeechRate => _gotransEngine.ttsSpeechRate;

  @override
  void initState() {
    super.initState();
    _isTwoWayMode = _sourceLang != 'Tự động';
    _initTts();
    _initGoTransEngine();
    _btnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  void _initGoTransEngine() {
    _gotransEngine = GoTransCoreEngine(
      vadThreshold: 11.0,
      silenceDurationMs: 850,
      speakerSwitchSilenceMs: 2600,
      autoDiarization: true,
      maxSpeakers: _availableSpeakerColors.length,
      onVadStatsChanged: (rms, silence, state) {
        if (!mounted || _isPaused) return;
        setState(() {
          _rmsLevel = rms * 3.5;
        });
      },
      onPartialResult: (liveOriginal, liveDraft, latency) {
        if (!mounted) return;
        setState(() {
          _liveSourceText = liveOriginal;
          if (liveDraft.isNotEmpty) {
            _liveTargetText = liveDraft;
          } else if (_liveTargetText.isEmpty) {
            _liveTargetText = "...";
          }
        });
        _scrollToBottom();
      },
      onFinalSentence: (finalOriginal, finalTranslation, speakerId, sourceLang, targetLang, latency) async {
        if (!mounted) return;

        String timestamp = _formatDuration(_recordDuration);
        String sId = "Speaker ${speakerId.toString().padLeft(2, '0')}";

        setState(() {
          _segments.add(TranslationSegment(
            speakerId: sId,
            originalText: finalOriginal,
            translatedText: finalTranslation, // Nếu nói trùng ngôn ngữ đích ở chế độ Tự động, cột này giữ nguyên văn bản!
            timestamp: timestamp,
            sourceLanguage: sourceLang,
            targetLanguage: targetLang,
            speakerColor: _getSpeakerColor(sId),
          ));
          _liveSourceText = "";
          _liveTargetText = "";
          _currentSpeakerId = speakerId;
        });
        _scrollToBottom();

        if (widget.onHistoryAdded != null) {
          widget.onHistoryAdded!(finalOriginal);
        }

        if (_sourceTtsEnabled) {
          await _gotransEngine.speakNative(finalOriginal, targetLanguage: sourceLang);
        }
        if (_targetTtsEnabled) {
          await _gotransEngine.speakNative(finalTranslation, targetLanguage: targetLang);
        }
      },
      onError: (msg) {
        _debugNotify("Lỗi Engine: $msg", color: Colors.red);
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isStarting = false;
            _rmsLevel = 0.0;
          });
          _timer?.cancel();
        }
      },
      onSpeakerChanged: (newSpeakerId) {
        if (mounted) {
          setState(() {
            _currentSpeakerId = newSpeakerId;
          });
        }
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      String hours = twoDigits(duration.inHours);
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftScrollController.hasClients) {
        _leftScrollController.animateTo(
          _leftScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      if (_rightScrollController.hasClients) {
        _rightScrollController.animateTo(
          _rightScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _debugNotify(String message, {Color color = Colors.black87}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.95);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _gotransEngine.dispose();
    _flutterTts.stop();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    _textController.dispose();
    _timer?.cancel();
    _btnAnimController.dispose();
    super.dispose();
  }

  void _handleTextSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTranslatingText = true;
    });

    final targetLang = _sourceLang == 'Tự động' ? 'Việt' : _targetLang;
    final sourceLang = _sourceLang; 

    // Gửi lên Gemini
    final translated = await _geminiService.translate(text, sourceLang, targetLang);

    if (!mounted) return;

    setState(() {
      _isTranslatingText = false;
      _textController.clear();
      
      String sId = "Speaker ${_currentSpeakerId.toString().padLeft(2, '0')}";
      _segments.add(TranslationSegment(
        speakerId: sId,
        originalText: text,
        translatedText: translated,
        timestamp: "Now",
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
        speakerColor: _getSpeakerColor(sId),
      ));
      
      // Chuyển lượt (Tuỳ chọn: Nếu đang ở chế độ 2 chiều thì luân phiên)
      if (sourceLang != 'Tự động') {
         _currentSpeakerId = _currentSpeakerId == 1 ? 2 : 1;
      }
    });
    
    _scrollToBottom();
    
    if (widget.onHistoryAdded != null) {
      widget.onHistoryAdded!(text);
    }
    
    // Gọi TTS nếu bật
    if (_targetTtsEnabled) {
      await _gotransEngine.speakNative(translated, targetLanguage: targetLang);
    }
  }

  void _handleMicTap() {
    if (_isStarting) return;
    if (!_isRecording) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() => _isStarting = true);
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() => _isStarting = false);
      _debugNotify("Quyền truy cập Micro bị từ chối.", color: Colors.red);
      return;
    }
    try {
      String localeId = _langToLocale[_sourceLang] ?? 'auto';
      final started = await _gotransEngine.startRecording(
        sourceLocaleId: localeId,
        targetLanguage: _targetLang,
        sourceLangName: _sourceLang,
      );
      if (mounted) {
        setState(() {
          _isStarting = false;
          if (started) {
            _isRecording = true;
            _isPaused = false;
            _startTime = DateTime.now();
            _liveSourceText = "";
            _liveTargetText = "";
            _recordDuration = Duration.zero;
            _startTimer();
          } else {
            _debugNotify("Không thể khởi động Micro.", color: Colors.red);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        _debugNotify("Lỗi: ${e.toString()}", color: Colors.red);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _togglePause() async {
    final bool nextPauseState = !_isPaused;
    setState(() {
      _isPaused = nextPauseState;
      if (nextPauseState) _rmsLevel = 0.0;
    });
    await _gotransEngine.setPaused(nextPauseState);
  }

  Future<void> _stopListening() async {
    _timer?.cancel();
    try {
      await _gotransEngine.forceFinalizeCurrentSentence();
      await _gotransEngine.stopRecording();
    } catch (e) {
      debugPrint("Lỗi khi dừng ghi âm: $e");
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isStarting = false;
        _isPaused = false;
        _liveSourceText = "";
        _liveTargetText = "";
        _rmsLevel = 0.0;
      });
    }
  }

  void _toggleSegmentSpeaker(int index) {
    setState(() {
      final segment = _segments[index];
      final currentNum = int.tryParse(segment.speakerId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final maxCycle = (_gotransEngine.detectedSpeakerCount + 1).clamp(2, _availableSpeakerColors.length);
      final nextNum = (currentNum % maxCycle) + 1;

      segment.speakerId = "Speaker ${nextNum.toString().padLeft(2, '0')}";
      segment.speakerColor = _getSpeakerColor(segment.speakerId);

      if (index == _segments.length - 1) {
        _currentSpeakerId = nextNum;
        _gotransEngine.setSpeaker(nextNum);
      }
    });
  }

  void _showSummaryDialog() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có nội dung hội thoại để tóm tắt!')),
      );
      return;
    }

    final buffer = StringBuffer();
    for (var seg in _segments) {
      buffer.writeln('${seg.speakerId}: ${seg.originalText}');
    }
    
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 600 ? 500 : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: FutureBuilder<String>(
              future: _geminiService.summarizeConversation(buffer.toString()),
              builder: (context, snapshot) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        const Text('AI Tóm tắt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (snapshot.hasError)
                      Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            snapshot.data ?? 'Không có dữ liệu',
                            style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Column(
                children: [
                  _buildLanguageBar(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildMainTranslationArea()),
                  const SizedBox(height: 12),
                  _buildBottomActionBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String title = !_isTwoWayMode ? 'Dịch một chiều' : 'Dịch 2 chiều';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, color: textDark, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
          const Spacer(),
          IconButton(
            onPressed: _showSummaryDialog,
            icon: const Icon(Icons.summarize, color: Colors.blueAccent),
            tooltip: 'Tóm tắt hội thoại',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBar() {
    if (_isTwoWayMode) return const SizedBox.shrink(); // Ẩn thanh ngôn ngữ chung ở chế độ 2 chiều
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          const Text('Nói', style: TextStyle(color: textLight, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          _buildDropdownButton(_sourceLang, isSource: true, key: _sourceLangBtnKey),
          const Spacer(),
          const Text('Dịch', style: TextStyle(color: textLight, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          _buildDropdownButton(_targetLang, isSource: false, key: _targetLangBtnKey),
        ],
      ),
    );
  }

  Widget _buildDropdownButton(String currentLabel, {required bool isSource, required GlobalKey key}) {
    return GestureDetector(
      key: key,
      onTap: () => _showLanguagePickerShootOut(isSource, key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textDark)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: textLight),
          ],
        ),
      ),
    );
  }

  void _showLanguagePickerShootOut(bool isSource, GlobalKey key) {
    final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "LanguagePicker",
      barrierColor: Colors.black.withOpacity(0.05),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return LanguagePickerDialog(
          currentLanguage: isSource ? _sourceLang : _targetLang,
          isSource: isSource,
          suggestedLanguages: _suggestedLangs,
          allLanguages: _allLangs,
          onSelected: (lang) {
            setState(() {
              if (isSource) {
                _sourceLang = lang;
                // Nếu đang ở 1 chiều mà chọn ngôn ngữ cụ thể, vẫn giữ nguyên 1 chiều.
                // Nếu đang ở 2 chiều mà chọn Tự động (mặc dù đã ẩn nhưng phòng hờ), thì ép về 1 chiều.
                if (_isTwoWayMode && _sourceLang == 'Tự động') {
                   _isTwoWayMode = false;
                   widget.onModeChanged?.call(false);
                }
              } else {
                _targetLang = lang;
              }
              resetChat();
            });
          },
          spawnPosition: position,
          buttonSize: size,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          alignment: isSource ? Alignment.topLeft : Alignment.topRight,
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _buildMainTranslationArea() {
    if (!_isTwoWayMode) {
      // CHẾ ĐỘ 1 CHIỀU: Dùng 2 Panel song song nhưng logic khác
      // Cột trái: Chỉ hiện văn bản Gốc
      // Cột phải: Chỉ hiện văn bản Dịch
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _buildPanel(isLeft: true)),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: _buildPanel(isLeft: false)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF1F2937),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ),
          ],
        ),
      );
    }
    
    // CHẾ ĐỘ 2 CHIỀU: 2 Panel song song
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildPanel(isLeft: true)),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: _buildPanel(isLeft: false)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF1F2937),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.compare_arrows, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required bool isLeft}) {
    final bool isEmpty = _segments.isEmpty && _liveSourceText.isEmpty;
    final bool isVoiceEnabled = isLeft ? _sourceTtsEnabled : _targetTtsEnabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isVoiceEnabled ? blueAccent : borderColor, width: isVoiceEnabled ? 2.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isVoiceEnabled ? blueAccent.withOpacity(0.12) : Colors.black.withOpacity(0.01),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isTwoWayMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  const Text('Nói', style: TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  _buildDropdownButton(
                    isLeft ? _sourceLang : _targetLang,
                    isSource: isLeft, // Người 1 (trái) nói tiếng source, Người 2 (phải) nói tiếng target
                    key: isLeft ? _leftSpeakBtnKey : _rightSpeakBtnKey,
                  ),
                  const Spacer(),
                  const Text('Dịch', style: TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  _buildDropdownButton(
                    isLeft ? _targetLang : _sourceLang,
                    isSource: !isLeft, // Người 1 (trái) dịch sang target, Người 2 (phải) dịch sang source
                    key: isLeft ? _leftTransBtnKey : _rightTransBtnKey,
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: isLeft && isEmpty ? _buildHowItWorks() : _buildSegmentsList(isLeft: isLeft),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 44),
                InkWell(
                  onTap: () => setState(() {
                    if (isLeft) {
                      _sourceTtsEnabled = !_sourceTtsEnabled;
                    } else {
                      _targetTtsEnabled = !_targetTtsEnabled;
                    }
                  }),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isVoiceEnabled ? blueAccent.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isVoiceEnabled ? blueAccent.withOpacity(0.3) : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                            color: isVoiceEnabled ? blueAccent : textLight, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          isVoiceEnabled ? 'BẬT' : 'TẮT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isVoiceEnabled ? blueAccent : textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsList({required bool isLeft}) {
    if (!_isTwoWayMode) {
      // CHẾ ĐỘ 1 CHIỀU: 
      // Cột trái (isLeft = true) hiển thị toàn bộ văn bản GỐC (nhận diện).
      // Cột phải (isLeft = false) hiển thị toàn bộ văn bản DỊCH.
      final itemCount = _segments.length + ((_liveSourceText.isNotEmpty || _liveTargetText.isNotEmpty) ? 1 : 0);
      return ListView.separated(
        controller: isLeft ? _leftScrollController : _rightScrollController,
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          if (index < _segments.length) {
            final segment = _segments[index];
            return GestureDetector(
              onTap: () => _toggleSegmentSpeaker(index),
              behavior: HitTestBehavior.opaque,
              child: _buildSegmentItem(
                text: isLeft ? segment.originalText : segment.translatedText,
                speaker: "Người nói", // 1 chiều nên ẩn ID người dùng đi cho đỡ rối, hoặc ghi chung
                timestamp: segment.timestamp,
                language: isLeft ? segment.sourceLanguage : segment.targetLanguage,
                isOriginal: isLeft, // Ở 1 chiều, cột trái luôn gốc (đen), cột phải luôn dịch (xanh)
                speakerColor: const Color(0xFF94A3B8), // Màu trung tính
              ),
            );
          } else {
            return _buildSegmentItem(
              text: isLeft ? _liveSourceText : _liveTargetText,
              speaker: "Người nói",
              timestamp: "--:--",
              language: isLeft ? _sourceLang : _targetLang,
              isOriginal: isLeft,
              isLive: true,
              speakerColor: const Color(0xFF94A3B8),
            );
          }
        },
      );
    } else {
      // CHẾ ĐỘ 2 CHIỀU:
      // Lọc ra các segments thuộc về cột hiện tại
      // isLeft = true -> Chỉ lấy Speaker 01
      // isLeft = false -> Chỉ lấy Speaker 02
      final filteredSegments = _segments.where((seg) {
        if (isLeft) return seg.speakerId == "Speaker 01";
        return seg.speakerId == "Speaker 02";
      }).toList();

      // Xác định xem có văn bản live (đang nói) phù hợp với cột hiện tại không
      String sIdLive = "Speaker ${_currentSpeakerId.toString().padLeft(2, '0')}";
      bool showLiveHere = isLeft ? (sIdLive == "Speaker 01") : (sIdLive == "Speaker 02");
      bool hasLiveText = showLiveHere && (_liveSourceText.isNotEmpty || _liveTargetText.isNotEmpty);

      final itemCount = filteredSegments.length + (hasLiveText ? 1 : 0);

      return ListView.separated(
        controller: isLeft ? _leftScrollController : _rightScrollController,
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          if (index < filteredSegments.length) {
            final segment = filteredSegments[index];
            // Trong cùng 1 cột của 1 người: hiển thị 2 dòng (Dòng 1: Gốc, Dòng 2: Dịch)
            return GestureDetector(
              onTap: () => _toggleSegmentSpeaker(_segments.indexOf(segment)),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSegmentItem(
                    text: segment.originalText,
                    speaker: segment.speakerId,
                    timestamp: segment.timestamp,
                    language: segment.sourceLanguage,
                    isOriginal: true,
                    speakerColor: segment.speakerColor,
                  ),
                  const SizedBox(height: 12),
                  _buildSegmentItem(
                    text: segment.translatedText,
                    speaker: segment.speakerId,
                    timestamp: segment.timestamp,
                    language: segment.targetLanguage,
                    isOriginal: false,
                    speakerColor: segment.speakerColor,
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
                ],
              ),
            );
          } else {
            // Hiển thị phần Live (đang nói)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSegmentItem(
                  text: _liveSourceText,
                  speaker: sIdLive,
                  timestamp: "--:--",
                  language: _sourceLang,
                  isOriginal: true,
                  isLive: true,
                  speakerColor: _getSpeakerColor(sIdLive),
                ),
                const SizedBox(height: 12),
                _buildSegmentItem(
                  text: _liveTargetText,
                  speaker: sIdLive,
                  timestamp: "--:--",
                  language: _targetLang,
                  isOriginal: false,
                  isLive: true,
                  speakerColor: _getSpeakerColor(sIdLive),
                ),
              ],
            );
          }
        },
      );
    }
  }

  Widget _buildSegmentItem({
    required String text,
    required String speaker,
    required String timestamp,
    required String language,
    required bool isOriginal,
    required Color speakerColor,
    bool isLive = false,
  }) {
    // Màu chữ phân biệt: 
    // Văn bản gốc (nhận diện) -> textDark
    // Văn bản dịch -> màu xanh dương (hoặc màu cam tuỳ bạn chọn, ở đây chọn blueAccent hoặc màu khác để nổi bật)
    final Color textColor = isOriginal ? textDark : const Color(0xFF03A9F4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: speakerColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text("$timestamp  ", style: const TextStyle(color: textLight, fontSize: 11, fontWeight: FontWeight.w500)),
            Text("$speaker • $language",
                style: TextStyle(color: speakerColor, fontSize: 12, fontWeight: FontWeight.bold)),
            if (!isLive) ...[const SizedBox(width: 6), const Icon(Icons.touch_app, size: 10, color: textLight)],
          ],
        ),
        const SizedBox(height: 6),
        IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                margin: const EdgeInsets.only(left: 3, right: 12),
                decoration: BoxDecoration(color: isOriginal ? speakerColor.withOpacity(0.3) : const Color(0xFF03A9F4).withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: isLive ? textColor.withOpacity(0.5) : textColor,
                    height: 1.5,
                    fontWeight: isOriginal ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks() {
    final String modeText = !_isTwoWayMode ? 'một chiều' : '2 chiều';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Cách hoạt động ($modeText)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 20),
        _buildHowItWorksStep(
          1,
          'Chọn ngôn ngữ dịch',
          'Chọn ngôn ngữ bạn muốn đọc hoặc nghe ở bảng bên phải.',
          dropdownLabel: _targetLang,
        ),
        const SizedBox(height: 16),
        _buildHowItWorksStep(
          2,
          !_isTwoWayMode ? 'Tự động nhận diện ngôn ngữ & người nói' : 'Dịch song phương',
          !_isTwoWayMode
              ? 'Nếu bạn nói ngôn ngữ khác ngôn ngữ đích, hệ thống sẽ tự động dịch. Nếu bạn nói cùng ngôn ngữ đích, văn bản sẽ được giữ nguyên.'
              : 'Nói bất kỳ ngôn ngữ nào trong hai ngôn ngữ đã chọn. Hệ thống sẽ tự động chuyển đổi ngôn ngữ đích.',
        ),
        const SizedBox(height: 16),
        _buildHowItWorksStep(
          3,
          'Chạm để sửa',
          'Nếu nhận diện nhầm người nói, chỉ cần chạm vào bong bóng hội thoại để chuyển đổi Speaker.',
        ),
      ],
    );
  }

  Widget _buildHowItWorksStep(int step, String title, String desc, {String? dropdownLabel}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$step', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
                  if (dropdownLabel != null) _buildDropdownButton(dropdownLabel, isSource: false, key: GlobalKey()),
                ],
              ),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 13, color: textLight, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _isRecording ? _buildVoiceControlBar() : _buildIdleActionBar(),
    );
  }

  Widget _buildIdleActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Nhập văn bản để dịch hoặc bấm mic...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (text) => setState(() {}), // Gây render lại để hiển thị icon Gửi
              onSubmitted: (_) => _handleTextSend(),
            ),
          ),
          if (_textController.text.isNotEmpty || _isTranslatingText)
             IconButton(
               icon: _isTranslatingText 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: blueAccent),
               onPressed: _isTranslatingText ? null : _handleTextSend,
             )
          else
            AnimatedBuilder(
              animation: _btnAnimController,
              builder: (context, child) {
                final Color speakerColor = _getSpeakerColor("Speaker ${_currentSpeakerId.toString().padLeft(2, '0')}");
                final double offset = _btnAnimController.value;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleMicTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(offset * 2 - 1, -1),
                          end: Alignment(offset * 2 + 1, 1),
                          tileMode: TileMode.repeated,
                          colors: [
                            speakerColor,
                            speakerColor.withOpacity(0.8),
                            speakerColor.withOpacity(0.5),
                            speakerColor.withOpacity(0.8),
                            speakerColor,
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: speakerColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isStarting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          else
                            const Icon(Icons.mic, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Nói',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor.withOpacity(0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          Row(
            children: [
              Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFFF5252), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(
                _formatDuration(_recordDuration),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textDark, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          SizedBox(width: 50, child: _buildMultiBarWave()),
          const SizedBox(width: 8),
          _buildControlBtn(
            onTap: _togglePause,
            icon: _isPaused ? Icons.play_arrow : Icons.pause,
            label: _isPaused ? 'Resume' : 'Pause',
            bgColor: blueAccent.withOpacity(0.12),
            contentColor: blueAccent,
          ),
          const SizedBox(width: 4),
          _buildControlBtn(
            onTap: _stopListening,
            icon: Icons.check,
            label: 'Done',
            bgColor: blueAccent.withOpacity(0.08),
            contentColor: blueAccent,
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: resetChat,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: blueAccent.withOpacity(0.06), shape: BoxShape.circle),
              child: const Icon(Icons.refresh, size: 16, color: blueAccent),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color contentColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: contentColor),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(color: contentColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiBarWave() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        double factor = _isPaused ? 0 : (_rmsLevel / 100.0);
        double variance = (index % 3 == 0) ? 0.95 : (index % 2 == 0) ? 0.45 : 0.75;
        double height = 3.5 + (factor * 25 * variance);
        if (!_isPaused && _isRecording && factor > 0.05) height += math.Random().nextDouble() * 5.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          margin: const EdgeInsets.symmetric(horizontal: 0.8),
          width: 2.6,
          height: height.clamp(3.5, 22.0),
          decoration: BoxDecoration(
            color: _getSpeakerColor("Speaker ${_currentSpeakerId.toString().padLeft(2, '0')}").withOpacity(0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildBottomIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, size: 18, color: textDark),
    );
  }
}

class LanguagePickerDialog extends StatefulWidget {
  final String currentLanguage;
  final bool isSource;
  final List<String> suggestedLanguages;
  final List<String> allLanguages;
  final Function(String) onSelected;
  final Offset spawnPosition;
  final Size buttonSize;

  const LanguagePickerDialog({
    super.key,
    required this.currentLanguage,
    required this.isSource,
    required this.suggestedLanguages,
    required this.allLanguages,
    required this.onSelected,
    required this.spawnPosition,
    required this.buttonSize,
  });

  @override
  State<LanguagePickerDialog> createState() => _LanguagePickerDialogState();
}

class _LanguagePickerDialogState extends State<LanguagePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    List<String> filteredSuggested =
    widget.suggestedLanguages.where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    List<String> filteredAll =
    widget.allLanguages.where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    double screenWidth = MediaQuery.of(context).size.width;
    double top = widget.spawnPosition.dy + widget.buttonSize.height + 6;
    
    // Đảm bảo Dialog không bị tràn lề phải màn hình
    double dialogWidth = 250.0;
    double left = widget.spawnPosition.dx;
    if (left + dialogWidth > screenWidth - 16) {
       left = screenWidth - dialogWidth - 16; 
    }
    
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 250,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Tìm...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (filteredSuggested.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Text(
                              'GỢI Ý',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...filteredSuggested.map((l) => _buildLanguageItem(l, isSelected: widget.currentLanguage == l)),
                        ],
                        if (filteredAll.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Text(
                              'TẤT CẢ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...filteredAll.map((l) => _buildLanguageItem(l, isSelected: widget.currentLanguage == l)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageItem(String language, {required bool isSelected}) {
    return InkWell(
      onTap: () {
        widget.onSelected(language);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF3F4F6) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                language,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.black : const Color(0xFF374151),
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check, size: 16, color: Colors.black),
          ],
        ),
      ),
    );
  }
}