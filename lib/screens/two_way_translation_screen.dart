import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../services/gotrans_core_enginer.dart';

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
  final List<String> historyItems;

  const TwoWayTranslationScreen({
    super.key,
    this.onHistoryAdded,
    this.onBack,
    this.onNewChat,
    this.onViewHistory,
    this.onLoadFromHistory,
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

  final FlutterTts _flutterTts = FlutterTts();
  late final GoTransCoreEngine _gotransEngine;

  bool _isRecording = false;
  bool _isStarting = false;
  bool _isPaused = false;
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

  final GlobalKey _sourceLangBtnKey = GlobalKey();
  final GlobalKey _targetLangBtnKey = GlobalKey();

  String get currentConversationSummary => _segments.isNotEmpty ? _segments.last.originalText : "";

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
    _initTts();
    _initGoTransEngine();
    _btnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _initGoTransEngine() {
    _gotransEngine = GoTransCoreEngine(
      vadThreshold: 15.0,
      silenceDurationMs: 750,       // Nhạy bén chốt câu ngay khi bạn bấm dừng video (750ms)
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
      // QUAN TRỌNG: Không dùng `if (_isPaused) return;` ở đây để khi vừa bấm Pause,
      // câu đang dịch dở vẫn được đẩy vào danh sách kết quả mà không bị mất chữ!
      onFinalSentence: (finalOriginal, finalTranslation, speakerId, latency) async {
        if (!mounted) return;

        String timestamp = _formatDuration(_recordDuration);
        String sId = "Speaker ${speakerId.toString().padLeft(2, '0')}";

        setState(() {
          _segments.add(TranslationSegment(
            speakerId: sId,
            originalText: finalOriginal,
            translatedText: finalTranslation,
            timestamp: timestamp,
            sourceLanguage: _sourceLang == 'Tự động'
                ? (_gotransEngine.currentSourceLocale.startsWith('vi') ? 'Việt' : 'Anh')
                : _sourceLang,
            targetLanguage: _targetLang,
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
          await _gotransEngine.speakNative(finalOriginal, targetLanguage: _gotransEngine.currentSourceLocale);
        }
        if (_targetTtsEnabled) {
          await _gotransEngine.speakNative(finalTranslation, targetLanguage: _gotransEngine.currentTargetLang);
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
    _timer?.cancel();
    _btnAnimController.dispose();
    super.dispose();
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
      final started = await _gotransEngine.startRecording(sourceLocaleId: localeId, targetLanguage: _targetLang);
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

  /// Khi bấm nút Pause/Resume trên thanh điều khiển:
  /// Chốt ngay các chữ đang treo trước khi tạm dừng để không bị mất chữ
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
          const Text('Dịch hai chiều', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildLanguageBar() {
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
              Expanded(flex: 4, child: _buildPanel(isLeft: false)),
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
                if (!isEmpty)
                  IconButton(
                    onPressed: () {
                      final text = isLeft
                          ? _segments.map((s) => s.originalText).join(". ")
                          : _segments.map((s) => s.translatedText).join(". ");
                      final lang = isLeft ? _gotransEngine.currentSourceLocale : _gotransEngine.currentTargetLang;
                      _gotransEngine.speakNative(text, targetLanguage: lang);
                    },
                    icon: Icon(Icons.play_circle_outline, color: isVoiceEnabled ? blueAccent : textLight, size: 22),
                    tooltip: 'Nghe lại',
                  )
                else
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
    final itemCount =
        _segments.length + (isLeft ? (_liveSourceText.isNotEmpty ? 1 : 0) : (_liveTargetText.isNotEmpty ? 1 : 0));
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
              speaker: segment.speakerId,
              timestamp: segment.timestamp,
              language: isLeft ? segment.sourceLanguage : segment.targetLanguage,
              isLeft: isLeft,
              speakerColor: segment.speakerColor,
            ),
          );
        } else {
          String sId = "Speaker ${_currentSpeakerId.toString().padLeft(2, '0')}";
          return _buildSegmentItem(
            text: isLeft ? _liveSourceText : _liveTargetText,
            speaker: sId,
            timestamp: "--:--",
            language: isLeft ? _sourceLang : _targetLang,
            isLeft: isLeft,
            isLive: true,
            speakerColor: _getSpeakerColor(sId),
          );
        }
      },
    );
  }

  Widget _buildSegmentItem({
    required String text,
    required String speaker,
    required String timestamp,
    required String language,
    required bool isLeft,
    required Color speakerColor,
    bool isLive = false,
  }) {
    final Color textColor = isLeft ? textDark : const Color(0xFFFF5722);
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
                decoration: BoxDecoration(color: speakerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: isLive ? textColor.withOpacity(0.5) : textColor,
                    height: 1.5,
                    fontWeight: isLeft ? FontWeight.normal : FontWeight.w500,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('How It Works?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
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
          'Tự động nhận diện giọng nói',
          'Chỉ cần bắt đầu nói. Hệ thống tự động phân tách nhiều người nói (Speaker 01, 02, 03...) theo thời gian thực.',
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
    return Row(
      children: [
        _buildBottomIconButton(Icons.mic_none),
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleMicTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _btnAnimController,
              builder: (context, child) {
                final Color speakerColor = _getSpeakerColor("Speaker ${_currentSpeakerId.toString().padLeft(2, '0')}");
                final double offset = _btnAnimController.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        speakerColor,
                        speakerColor.withOpacity(0.7),
                        speakerColor.withOpacity(0.4),
                        speakerColor.withOpacity(0.7),
                        speakerColor,
                      ],
                      stops: [
                        0.0,
                        (offset - 0.2).clamp(0.0, 1.0),
                        offset,
                        (offset + 0.2).clamp(0.0, 1.0),
                        1.0
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 10),
                      const Text(
                        'Bắt đầu nói',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            _buildBottomIconButton(Icons.keyboard_alt_outlined),
            const SizedBox(width: 12),
            _buildBottomIconButton(Icons.fullscreen),
          ],
        ),
      ],
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
    double top = widget.spawnPosition.dy + widget.buttonSize.height + 6;
    double? left = widget.isSource ? widget.spawnPosition.dx : null;
    double? right = widget.isSource
        ? null
        : (MediaQuery.of(context).size.width - widget.spawnPosition.dx - widget.buttonSize.width);
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          right: right,
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
                        if (widget.isSource && _searchQuery.isEmpty)
                          _buildLanguageItem('Tự động', isSelected: widget.currentLanguage == 'Tự động'),
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