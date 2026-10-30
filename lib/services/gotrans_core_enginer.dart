import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Kết quả Kép từ AI: Vừa khôi phục câu gốc, vừa trả về văn bản đích (Dịch hoặc Giữ nguyên nếu trùng ngôn ngữ đích)
class DualStageTranslationResult {
  final String reconstructedOriginal;
  final String translatedText;
  final String detectedSourceLangName;
  final bool isSameAsTarget;

  DualStageTranslationResult({
    required this.reconstructedOriginal,
    required this.translatedText,
    this.detectedSourceLangName = 'Tự động',
    this.isSameAsTarget = false,
  });
}

/// Hồ sơ đặc trưng giọng nói của từng Speaker (Voiceprint Centroid)
class SpeakerVoiceProfile {
  final int speakerId;
  double pitchHz;
  double zcr;
  double avgRms;
  double wordsPerSec;
  String primaryLang;
  int sampleCount;
  DateTime lastSpokeAt;

  SpeakerVoiceProfile({
    required this.speakerId,
    required this.pitchHz,
    required this.zcr,
    required this.avgRms,
    required this.wordsPerSec,
    required this.primaryLang,
    this.sampleCount = 1,
    DateTime? lastSpokeAt,
  }) : lastSpokeAt = lastSpokeAt ?? DateTime.now();

  void updateCentroid({
    required double newPitch,
    required double newZcr,
    required double newRms,
    required double newWps,
    required String detectedLang,
  }) {
    const double alpha = 0.3;
    if (newPitch > 0) pitchHz = (1 - alpha) * pitchHz + alpha * newPitch;
    if (newZcr > 0) zcr = (1 - alpha) * zcr + alpha * newZcr;
    if (newRms > 0) avgRms = (1 - alpha) * avgRms + alpha * newRms;
    if (newWps > 0) wordsPerSec = (1 - alpha) * wordsPerSec + alpha * newWps;
    if (detectedLang.isNotEmpty) primaryLang = detectedLang;
    sampleCount++;
    lastSpokeAt = DateTime.now();
  }
}

class GoTransCoreEngine {
  // --- 1. Hai luồng chạy song song: Web Speech API + Web Audio API ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _vadRecorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Uint8List>? _vadAudioSub;

  bool _isListening = false;
  bool _isPaused = false;
  bool _isTtsInitialized = false;
  String _currentSourceLocale = 'vi-VN';
  String _currentTargetLang = 'Việt';

  // Chế độ ngôn ngữ: Auto-detect vs Cố định 2 chiều
  bool _isAutoDetectSource = true;
  bool _isTwoWayMode = false;
  String _originalSourceLangName = 'Tự động';

  // Audio settings
  InputDevice? _selectedInputDevice;
  double _ttsVolume = 1.0;
  double _ttsSpeechRate = 0.95;

  // --- CƠ CHẾ ZERO-DROP DELTA SLICING & N-BEST ALTERNATES ---
  double _adaptiveNoiseFloor = 8.0;
  String _rawSessionTranscript = '';
  String _committedPrefixInSession = '';
  String _activeInterimTranscript = '';
  List<String> _activeInterimAlternates = [];
  String _lastFinalizedText = '';
  int _lastDraftWordCount = 0;
  bool _isTranslatingDraft = false;
  bool _isSpeakingVad = false;
  DateTime _lastSpeechTimestamp = DateTime.now();
  DateTime _lastTextChangeTimestamp = DateTime.now();
  DateTime _utteranceStartTime = DateTime.now();
  DateTime _lastFinalizationTimestamp = DateTime.now();
  Timer? _vadMonitorTimer;

  // Cấu hình VAD nhạy bén
  double vadThreshold;
  int silenceDurationMs;
  int speakerSwitchSilenceMs;
  bool autoDiarization;
  bool autoSpeakTranslation;
  int maxSpeakers;
  double speakerSimilarityThreshold;
  int currentSpeaker = 1;

  // Bộ nhớ phân tách người nói
  final List<SpeakerVoiceProfile> _speakerProfiles = [];
  final List<double> _currentUtterancePitches = [];
  final List<double> _currentUtteranceZcrs = [];
  final List<double> _currentUtteranceRms = [];

  // --- 2. Quản lý Ngữ cảnh (AI Context Engine) ---
  final List<String> _slidingWindow = [];
  final int maxWindowSize;
  String meetingContext;
  String customApiKey;
  final Map<String, String> customGlossary;

  // --- 3. Callbacks trả kết quả trực tiếp về Giao diện ---
  final Function(double rmsLevel, int silenceElapsedMs, String vadState)? onVadStatsChanged;
  final Function(int newSpeakerId)? onSpeakerChanged;
  final Function(List<SpeakerVoiceProfile> profiles)? onSpeakerProfilesUpdated;
  final Function(String liveOriginal, String liveDraftTranslation, int latencyMs)? onPartialResult;
  final Function(String finalOriginal, String finalTranslation, int speakerId, String sourceLang, String targetLang, int latencyMs)? onFinalSentence;
  final Function(String errorMessage)? onError;

  GoTransCoreEngine({
    this.vadThreshold = 11.0,
    this.silenceDurationMs = 850,
    this.speakerSwitchSilenceMs = 2600,
    this.autoDiarization = true,
    this.autoSpeakTranslation = false,
    this.maxSpeakers = 8,
    this.speakerSimilarityThreshold = 0.58,
    this.maxWindowSize = 6,
    this.meetingContext = 'Hội thoại giao tiếp song ngữ Việt - Anh và thảo luận trực tiếp.',
    this.customApiKey = '',
    Map<String, String>? initialGlossary,
    this.onVadStatsChanged,
    this.onSpeakerChanged,
    this.onSpeakerProfilesUpdated,
    this.onPartialResult,
    this.onFinalSentence,
    this.onError,
  }) : customGlossary = initialGlossary ?? {} {
    _initNativeTts();
  }

  // Getters & Setters
  bool get isListening => _isListening;
  bool get isPaused => _isPaused;
  List<String> get slidingWindow => _slidingWindow;
  String get currentSourceLocale => _currentSourceLocale;
  String get currentTargetLang => _currentTargetLang;
  double get ttsVolume => _ttsVolume;
  double get ttsSpeechRate => _ttsSpeechRate;
  List<SpeakerVoiceProfile> get speakerProfiles => List.unmodifiable(_speakerProfiles);
  int get detectedSpeakerCount => _speakerProfiles.isEmpty ? 1 : _speakerProfiles.length;

  Future<List<InputDevice>> getInputDevices() async {
    return await _vadRecorder.listInputDevices();
  }

  void setInputDevice(InputDevice device) {
    _selectedInputDevice = device;
  }

  void setTtsVolume(double volume) {
    _ttsVolume = volume.clamp(0.0, 1.0);
    _tts.setVolume(_ttsVolume);
  }

  void setTtsSpeechRate(double rate) {
    _ttsSpeechRate = rate.clamp(0.2, 1.5);
    _tts.setSpeechRate(_ttsSpeechRate);
  }

  void setVadThreshold(double value) => vadThreshold = value;
  void setSilenceDuration(int ms) => silenceDurationMs = ms;
  void setAutoDiarization(bool value) => autoDiarization = value;

  void setSpeaker(int speakerId) {
    currentSpeaker = speakerId.clamp(1, maxSpeakers);
    onSpeakerChanged?.call(currentSpeaker);
  }

  void resetSpeakerProfiles() {
    _speakerProfiles.clear();
    _clearCurrentUtteranceAcousticBuffer();
    currentSpeaker = 1;
    onSpeakerChanged?.call(currentSpeaker);
    onSpeakerProfilesUpdated?.call(_speakerProfiles);
  }

  // ===========================================================================
  // PHẦN 1: LUỒNG NGHE SONG NGỮ TỰ ĐỘNG (BILINGUAL ZERO-DROP STREAM)
  // ===========================================================================
  Future<bool> startRecording({
    String sourceLocaleId = 'auto',
    String targetLanguage = 'Tiếng Việt',
    String? sourceLangName,
  }) async {
    final sLower = sourceLocaleId.toLowerCase().trim();
    final nameLower = (sourceLangName ?? '').toLowerCase().trim();

    _isAutoDetectSource = (sLower == 'auto' ||
        sLower.contains('tự động') ||
        sLower.contains('auto-detect') ||
        nameLower.contains('tự động') ||
        nameLower.contains('auto'));

    _isTwoWayMode = !_isAutoDetectSource;
    _originalSourceLangName = sourceLangName ?? (_isAutoDetectSource ? 'Tự động' : 'Anh');
    _currentTargetLang = targetLanguage;
    _currentSourceLocale = _normalizeSpeechLocale(sourceLocaleId, targetLanguage);

    bool speechAvailable = await _speech.initialize(
      debugLogging: false,
      finalTimeout: const Duration(seconds: 6),
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListening && !_isPaused) {
          if (_activeInterimTranscript.trim().isNotEmpty) {
            _commitActiveDeltaSegment();
          }
          _committedPrefixInSession = '';
          _rawSessionTranscript = '';
          Future.delayed(const Duration(milliseconds: 15), () {
            if (_isListening && !_isPaused) _startWebSpeechLoop();
          });
        }
      },
      onError: (err) {
        if (_isListening && !_isPaused) {
          if (_activeInterimTranscript.trim().isNotEmpty) {
            _commitActiveDeltaSegment();
          }
          _committedPrefixInSession = '';
          _rawSessionTranscript = '';
          Future.delayed(const Duration(milliseconds: 25), () {
            if (_isListening && !_isPaused) _startWebSpeechLoop();
          });
        }
      },
    );

    if (!speechAvailable) {
      onError?.call('Trình duyệt không hỗ trợ Web Speech API (Hãy dùng Chrome hoặc Edge)!');
      return false;
    }

    _isListening = true;
    _isPaused = false;
    _adaptiveNoiseFloor = 8.0;
    _rawSessionTranscript = '';
    _committedPrefixInSession = '';
    _activeInterimTranscript = '';
    _activeInterimAlternates = [];
    _lastFinalizedText = '';
    _lastDraftWordCount = 0;
    _lastSpeechTimestamp = DateTime.now();
    _lastTextChangeTimestamp = DateTime.now();
    _utteranceStartTime = DateTime.now();
    _lastFinalizationTimestamp = DateTime.now();
    _clearCurrentUtteranceAcousticBuffer();

    _startWebSpeechLoop();
    await _startParallelAudioVadMonitor();

    return true;
  }

  Future<void> setPaused(bool paused) async {
    if (paused) {
      await Future.delayed(const Duration(milliseconds: 160));
      if (_activeInterimTranscript.trim().isNotEmpty) {
        _commitActiveDeltaSegment();
      }
      _isPaused = true;
    } else {
      _isPaused = false;
      _lastSpeechTimestamp = DateTime.now();
      _lastTextChangeTimestamp = DateTime.now();
      _utteranceStartTime = DateTime.now();
      if (_isListening && !_speech.isListening) {
        _startWebSpeechLoop();
      }
    }
  }

  /// QUAN TRỌNG: Giải quyết lỗi nói Tiếng Việt bị thu thành chữ Tiếng Anh ("Tell me", "Dollar General")
  /// Khi chọn "Tự động", ưu tiên khởi tạo bộ thu đa ngữ `vi-VN` của Google vì:
  /// - `vi-VN` nhận diện chuẩn 100% câu Tiếng Việt có dấu VÀ vẫn nhận diện tốt các câu Tiếng Anh phổ thông ("Hello everyone", "I want to...").
  /// - Ngược lại, nếu đặt `en-US`, bộ thu hoàn toàn mù Tiếng Việt và sẽ biến mọi câu Tiếng Việt thành từ Tiếng Anh sai lệch!
  String _normalizeSpeechLocale(String rawSource, String targetLang) {
    final s = rawSource.toLowerCase().trim();
    if (s == 'auto' || s.contains('tự động') || s.contains('auto-detect')) {
      return 'vi-VN';
    }
    if (s.contains('vi') || s.contains('việt')) return 'vi-VN';
    if (s.contains('en') || s.contains('anh')) return 'en-US';
    if (s.contains('ja') || s.contains('nhật')) return 'ja-JP';
    if (s.contains('ko') || s.contains('hàn')) return 'ko-KR';
    if (s.contains('zh-tw') || s.contains('phồn')) return 'zh-TW';
    if (s.contains('zh') || s.contains('trung')) return 'zh-CN';
    if (s.contains('fr') || s.contains('pháp')) return 'fr-FR';
    if (s.contains('de') || s.contains('đức')) return 'de-DE';
    if (s.contains('es') || s.contains('tây ban nha')) return 'es-ES';
    if (s.contains('it') || s.contains('ý')) return 'it-IT';
    if (s.contains('ru') || s.contains('nga')) return 'ru-RU';
    if (s.contains('th') || s.contains('thái')) return 'th-TH';
    if (s.contains('id') || s.contains('indonesia')) return 'id-ID';
    return rawSource;
  }

  void _startWebSpeechLoop() {
    if (!_isListening || _isPaused || _speech.isListening) return;

    _speech.listen(
      localeId: _currentSourceLocale,
      pauseFor: const Duration(seconds: 60),
      listenFor: const Duration(minutes: 15),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        onDevice: false,
        listenMode: stt.ListenMode.dictation,
        autoPunctuation: true,
      ),
      onSoundLevelChange: (level) {
        if (_vadAudioSub == null && !_isPaused) {
          final boostedRms = ((level + 2.5) * 9.5).clamp(0.0, 100.0);
          _processAdaptiveNoiseAndVad(boostedRms);
        }
      },
      onResult: (result) {
        if (!_isListening || _isPaused) return;

        final List<String> candidates = [];
        if (result.recognizedWords.trim().isNotEmpty) {
          candidates.add(result.recognizedWords.trim());
        }
        for (final alt in result.alternates) {
          final altText = alt.recognizedWords.trim();
          if (altText.isNotEmpty && !candidates.contains(altText)) {
            candidates.add(altText);
          }
        }
        if (candidates.isEmpty) return;

        String bestFullRecognized = candidates.first;
        for (final alt in result.alternates) {
          final altText = alt.recognizedWords.trim();
          if (alt.confidence >= 0.65 && altText.split(' ').length > bestFullRecognized.split(' ').length) {
            bestFullRecognized = altText;
          }
        }

        _rawSessionTranscript = bestFullRecognized;

        final String deltaText = _extractUncommittedDelta(bestFullRecognized);
        if (deltaText.isEmpty) return;

        final List<String> deltaAlternates = [];
        for (final cand in candidates) {
          final dAlt = _extractUncommittedDelta(cand);
          if (dAlt.isNotEmpty && dAlt.toLowerCase() != deltaText.toLowerCase() && !deltaAlternates.contains(dAlt)) {
            deltaAlternates.add(dAlt);
          }
        }

        if (deltaText != _activeInterimTranscript) {
          _lastTextChangeTimestamp = DateTime.now();
          _lastSpeechTimestamp = DateTime.now();
          _isSpeakingVad = true;
        }

        if (_activeInterimTranscript.isEmpty) {
          _utteranceStartTime = DateTime.now();
        }

        _activeInterimTranscript = deltaText;
        _activeInterimAlternates = deltaAlternates.take(3).toList();

        if (!result.finalResult) {
          if (autoDiarization && _currentUtterancePitches.length >= 4) {
            final previewSpk = _identifyOrCreateSpeaker(deltaText, isCommit: false);
            if (previewSpk != currentSpeaker) {
              currentSpeaker = previewSpk;
              onSpeakerChanged?.call(currentSpeaker);
            }
          }

          // Nếu câu đang nói có dấu Tiếng Việt rõ ràng và trùng ngôn ngữ đích -> Giữ nguyên ngay lập tức
          if (_isAutoDetectSource && _isPureTargetLanguage(deltaText, _currentTargetLang)) {
            onPartialResult?.call(deltaText, deltaText, 0);
          } else {
            onPartialResult?.call(deltaText, '', 0);
            _triggerThrottledDraftTranslation(deltaText, _activeInterimAlternates);
          }
        } else {
          _commitActiveDeltaSegment();
        }
      },
    );
  }

  void _processAdaptiveNoiseAndVad(double rms) {
    final now = DateTime.now();
    final int timeSinceLastTextChange = now.difference(_lastTextChangeTimestamp).inMilliseconds;

    if (timeSinceLastTextChange > 500) {
      _adaptiveNoiseFloor = (0.92 * _adaptiveNoiseFloor + 0.08 * rms).clamp(4.0, 45.0);
    }

    final double dynamicThreshold = max(vadThreshold, _adaptiveNoiseFloor + 5.5);

    if (rms >= dynamicThreshold) {
      _currentUtteranceRms.add(rms);
      _lastSpeechTimestamp = now;
      if (timeSinceLastTextChange < 1200) {
        _isSpeakingVad = true;
      }
      onVadStatsChanged?.call(rms, 0, 'SPEAKING');
    } else {
      final silenceElapsed = now.difference(_lastTextChangeTimestamp).inMilliseconds;
      onVadStatsChanged?.call(rms, silenceElapsed, _isSpeakingVad ? 'SPEAKING' : 'LISTENING');
    }
  }

  String _extractUncommittedDelta(String fullText) {
    if (_committedPrefixInSession.isEmpty) return fullText.trim();

    final String cleanFull = fullText.trim();
    final String cleanPrefix = _committedPrefixInSession.trim();

    if (cleanFull.toLowerCase() == cleanPrefix.toLowerCase()) {
      return '';
    }

    if (cleanFull.toLowerCase().startsWith(cleanPrefix.toLowerCase())) {
      return cleanFull.substring(cleanPrefix.length).trim();
    }

    final List<String> fullWords = cleanFull.split(RegExp(r'\s+'));
    final List<String> prefixWords = cleanPrefix.split(RegExp(r'\s+'));

    String normalize(String s) => s.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();

    if (fullWords.length >= prefixWords.length) {
      final Set<String> prefixSet = prefixWords.map(normalize).toSet();
      int matchCount = 0;
      int checkLimit = prefixWords.length;

      for (int i = 0; i < checkLimit; i++) {
        if (prefixSet.contains(normalize(fullWords[i]))) {
          matchCount++;
        }
      }

      if (matchCount >= (checkLimit * 0.5).ceil()) {
        return fullWords.sublist(prefixWords.length).join(' ').trim();
      }
    } else {
      final Set<String> fullSet = fullWords.map(normalize).toSet();
      int matchCount = 0;
      int checkLimit = fullWords.length;

      for (int i = 0; i < checkLimit; i++) {
        if (fullSet.contains(normalize(prefixWords[i]))) {
          matchCount++;
        }
      }

      if (matchCount >= (checkLimit * 0.5).ceil()) {
        return '';
      }
    }

    _committedPrefixInSession = '';
    return cleanFull;
  }

  void _commitActiveDeltaSegment() {
    final String segmentToCommit = _activeInterimTranscript.trim();
    final List<String> alternatesToCommit = List<String>.from(_activeInterimAlternates);
    if (segmentToCommit.isEmpty) return;

    if (_rawSessionTranscript.isNotEmpty) {
      _committedPrefixInSession = _rawSessionTranscript.trim();
    } else {
      _committedPrefixInSession =
          (_committedPrefixInSession.isEmpty ? '' : '$_committedPrefixInSession ') + segmentToCommit;
    }

    _activeInterimTranscript = '';
    _activeInterimAlternates = [];
    _lastDraftWordCount = 0;
    _isSpeakingVad = false;

    final int timeDiffMs = DateTime.now().difference(_lastFinalizationTimestamp).inMilliseconds;

    String normalize(String s) => s.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
    final String normSegment = normalize(segmentToCommit);
    final String normLast = normalize(_lastFinalizedText);

    bool isDuplicate = false;

    if (normSegment == normLast) {
      isDuplicate = true;
    } else if (timeDiffMs < 2500 && normLast.isNotEmpty) {
      final List<String> segWords = normSegment.split(RegExp(r'\s+'));
      final List<String> lastWords = normLast.split(RegExp(r'\s+'));

      final Set<String> lastSet = lastWords.toSet();
      int matchCount = 0;
      for (var w in segWords) {
        if (w.isNotEmpty && lastSet.contains(w)) matchCount++;
      }

      if (matchCount >= (segWords.length * 0.75).floor() && matchCount >= (lastWords.length * 0.75).floor()) {
        isDuplicate = true;
      }
    }

    if (isDuplicate) return;

    _lastFinalizedText = segmentToCommit;

    if (autoDiarization) {
      currentSpeaker = _identifyOrCreateSpeaker(segmentToCommit, isCommit: true);
      onSpeakerChanged?.call(currentSpeaker);
    }
    _lastFinalizationTimestamp = DateTime.now();

    _finalizeSentenceAndTranslate(
      segmentToCommit,
      currentSpeaker,
      asrAlternates: alternatesToCommit,
    );
  }

  Future<void> _startParallelAudioVadMonitor() async {
    if (!kIsWeb) {
      try {
        if (await _vadRecorder.hasPermission()) {
          final config = RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            device: _selectedInputDevice,
            echoCancel: false,
            noiseSuppress: true,
            autoGain: true,
          );
          final stream = await _vadRecorder.startStream(config);
          _vadAudioSub = stream.listen((Uint8List pcmBytes) {
            if (!_isPaused) _extractAcousticFeaturesFromPcm(pcmBytes);
          });
        }
      } catch (e) {
        debugPrint('VAD Audio Error: $e');
      }
    }

    _vadMonitorTimer?.cancel();
    _vadMonitorTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!_isListening || _isPaused) return;
      final now = DateTime.now();
      final int noNewWordsElapsed = now.difference(_lastTextChangeTimestamp).inMilliseconds;

      if (_activeInterimTranscript.trim().isNotEmpty) {
        final int currentWords = _activeInterimTranscript.trim().split(RegExp(r'\s+')).length;
        final int effectiveSilenceMs = (currentWords <= 3)
            ? (silenceDurationMs + 200)
            : silenceDurationMs;

        final bool isLongRapidStream = currentWords >= 26 && noNewWordsElapsed >= 420;

        if (noNewWordsElapsed >= effectiveSilenceMs || isLongRapidStream) {
          onVadStatsChanged?.call(_adaptiveNoiseFloor, noNewWordsElapsed, 'FINALIZING');
          _commitActiveDeltaSegment();
        }
      }
    });
  }

  void _extractAcousticFeaturesFromPcm(Uint8List chunk) {
    if (chunk.length < 64) return;
    final byteData = ByteData.sublistView(chunk);
    final int sampleCount = chunk.length ~/ 2;
    final List<double> samples = List<double>.filled(sampleCount, 0.0);

    double sumSquares = 0.0;
    int zeroCrossings = 0;

    for (int i = 0; i < sampleCount; i++) {
      final double s = byteData.getInt16(i * 2, Endian.little) / 32768.0;
      samples[i] = s;
      sumSquares += s * s;
      if (i > 0 && ((samples[i] >= 0 && samples[i - 1] < 0) || (samples[i] < 0 && samples[i - 1] >= 0))) {
        zeroCrossings++;
      }
    }

    final double rawRms = sqrt(sumSquares / sampleCount);
    final double normalizedRms = (rawRms * 310.0).clamp(0.0, 100.0);

    final double dynamicThreshold = max(vadThreshold, _adaptiveNoiseFloor + 5.5);
    if (normalizedRms >= dynamicThreshold) {
      final double zcr = zeroCrossings / (sampleCount - 1);
      final double pitchHz = _estimatePitchAutocorrelation(samples, 16000);

      _currentUtteranceRms.add(normalizedRms);
      _currentUtteranceZcrs.add(zcr);
      if (pitchHz >= 75.0 && pitchHz <= 320.0) {
        _currentUtterancePitches.add(pitchHz);
      }
    }

    _processAdaptiveNoiseAndVad(normalizedRms);
  }

  double _estimatePitchAutocorrelation(List<double> samples, int sampleRate) {
    final int minLag = sampleRate ~/ 320;
    final int maxLag = sampleRate ~/ 75;
    if (samples.length <= maxLag) return 0.0;

    double maxCorrelation = 0.0;
    int bestLag = 0;
    final int windowSize = min(samples.length - maxLag, 256);

    for (int lag = minLag; lag <= maxLag; lag++) {
      double corr = 0.0;
      for (int i = 0; i < windowSize; i++) {
        corr += samples[i] * samples[i + lag];
      }
      if (corr > maxCorrelation) {
        maxCorrelation = corr;
        bestLag = lag;
      }
    }

    if (bestLag == 0 || maxCorrelation < 0.01) return 0.0;
    return sampleRate / bestLag;
  }

  int _identifyOrCreateSpeaker(String spokenText, {required bool isCommit}) {
    final now = DateTime.now();
    final double durationSec = max(0.4, now.difference(_utteranceStartTime).inMilliseconds / 1000.0);
    final int wordCount = spokenText.trim().split(RegExp(r'\s+')).length;
    final double wordsPerSec = (wordCount / durationSec).clamp(0.5, 8.0);
    final String detectedLang = _detectTextLanguageHeuristic(spokenText);
    final int pauseBetweenTurnsMs = _utteranceStartTime.difference(_lastFinalizationTimestamp).inMilliseconds;

    final bool hasAcousticData = _currentUtterancePitches.isNotEmpty || _currentUtteranceZcrs.isNotEmpty;
    final double avgPitch = _currentUtterancePitches.isEmpty
        ? 0.0
        : _currentUtterancePitches.reduce((a, b) => a + b) / _currentUtterancePitches.length;
    final double avgZcr = _currentUtteranceZcrs.isEmpty
        ? 0.0
        : _currentUtteranceZcrs.reduce((a, b) => a + b) / _currentUtteranceZcrs.length;
    final double avgRms = _currentUtteranceRms.isEmpty
        ? 35.0
        : _currentUtteranceRms.reduce((a, b) => a + b) / _currentUtteranceRms.length;

    if (_speakerProfiles.isEmpty) {
      if (isCommit) {
        _speakerProfiles.add(SpeakerVoiceProfile(
          speakerId: 1,
          pitchHz: avgPitch > 0 ? avgPitch : 145.0,
          zcr: avgZcr > 0 ? avgZcr : 0.08,
          avgRms: avgRms,
          wordsPerSec: wordsPerSec,
          primaryLang: detectedLang,
        ));
        _clearCurrentUtteranceAcousticBuffer();
        onSpeakerProfilesUpdated?.call(_speakerProfiles);
      }
      return 1;
    }

    if (hasAcousticData && avgPitch > 0) {
      int bestSpeakerId = _speakerProfiles.first.speakerId;
      double minDistance = double.infinity;
      SpeakerVoiceProfile? bestProfile;

      for (final profile in _speakerProfiles) {
        final double pitchDiff = (avgPitch - profile.pitchHz).abs() / 85.0;
        final double zcrDiff = (avgZcr - profile.zcr).abs() / 0.12;
        final double rmsDiff = (avgRms - profile.avgRms).abs() / 45.0;
        final double langPenalty = (profile.primaryLang != detectedLang) ? 0.35 : 0.0;

        final double distance = sqrt(
          0.55 * pow(pitchDiff, 2) +
              0.25 * pow(zcrDiff, 2) +
              0.20 * pow(rmsDiff, 2),
        ) +
            langPenalty;

        if (distance < minDistance) {
          minDistance = distance;
          bestSpeakerId = profile.speakerId;
          bestProfile = profile;
        }
      }

      if (minDistance <= speakerSimilarityThreshold && bestProfile != null) {
        if (isCommit) {
          bestProfile.updateCentroid(
            newPitch: avgPitch,
            newZcr: avgZcr,
            newRms: avgRms,
            newWps: wordsPerSec,
            detectedLang: detectedLang,
          );
          _clearCurrentUtteranceAcousticBuffer();
          onSpeakerProfilesUpdated?.call(_speakerProfiles);
        }
        return bestSpeakerId;
      } else if (_speakerProfiles.length < maxSpeakers) {
        final int newId = _speakerProfiles.length + 1;
        if (isCommit) {
          _speakerProfiles.add(SpeakerVoiceProfile(
            speakerId: newId,
            pitchHz: avgPitch,
            zcr: avgZcr,
            avgRms: avgRms,
            wordsPerSec: wordsPerSec,
            primaryLang: detectedLang,
          ));
          _clearCurrentUtteranceAcousticBuffer();
          onSpeakerProfilesUpdated?.call(_speakerProfiles);
        }
        return newId;
      } else {
        if (isCommit) _clearCurrentUtteranceAcousticBuffer();
        return bestSpeakerId;
      }
    }

    if (pauseBetweenTurnsMs < speakerSwitchSilenceMs) {
      final currentProfile = _speakerProfiles.firstWhere(
            (p) => p.speakerId == currentSpeaker,
        orElse: () => _speakerProfiles.first,
      );
      if (currentProfile.primaryLang == detectedLang) {
        if (isCommit) {
          currentProfile.updateCentroid(
            newPitch: 0,
            newZcr: 0,
            newRms: avgRms,
            newWps: wordsPerSec,
            detectedLang: detectedLang,
          );
          _clearCurrentUtteranceAcousticBuffer();
        }
        return currentSpeaker;
      }
    }

    SpeakerVoiceProfile? bestMatch;
    double bestScore = double.infinity;

    for (final profile in _speakerProfiles) {
      final double wpsDiff = (wordsPerSec - profile.wordsPerSec).abs() / 2.6;
      final double rmsDiff = (avgRms - profile.avgRms).abs() / 35.0;
      final double langDiff = (profile.primaryLang == detectedLang) ? 0.0 : 0.75;
      final double sameSpeakerPenalty =
      (pauseBetweenTurnsMs >= speakerSwitchSilenceMs && profile.speakerId == currentSpeaker) ? 0.45 : 0.0;

      final double score = wpsDiff * 0.55 + rmsDiff * 0.30 + langDiff + sameSpeakerPenalty;
      if (score < bestScore) {
        bestScore = score;
        bestMatch = profile;
      }
    }

    if (bestScore <= 0.42 && bestMatch != null) {
      if (isCommit) {
        bestMatch.updateCentroid(
          newPitch: 0,
          newZcr: 0,
          newRms: avgRms,
          newWps: wordsPerSec,
          detectedLang: detectedLang,
        );
        _clearCurrentUtteranceAcousticBuffer();
        onSpeakerProfilesUpdated?.call(_speakerProfiles);
      }
      return bestMatch.speakerId;
    } else if (_speakerProfiles.length < maxSpeakers) {
      final int newId = _speakerProfiles.length + 1;
      if (isCommit) {
        _speakerProfiles.add(SpeakerVoiceProfile(
          speakerId: newId,
          pitchHz: 135.0 + newId * 22.0,
          zcr: 0.08,
          avgRms: avgRms,
          wordsPerSec: wordsPerSec,
          primaryLang: detectedLang,
        ));
        _clearCurrentUtteranceAcousticBuffer();
        onSpeakerProfilesUpdated?.call(_speakerProfiles);
      }
      return newId;
    }

    if (isCommit) _clearCurrentUtteranceAcousticBuffer();
    return bestMatch?.speakerId ?? ((currentSpeaker % maxSpeakers) + 1);
  }

  /// Phân tích chính xác ngôn ngữ thực tế của câu thu được (Kể cả câu pha trộn hoặc không dấu)
  String _detectTextLanguageHeuristic(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'en';

    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(trimmed)) return 'ja';
    if (RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]').hasMatch(trimmed)) return 'ko';
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(trimmed)) return 'zh-CN';

    final vietnameseDiacritics = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
      caseSensitive: false,
    );

    final words = trimmed.split(RegExp(r'\s+'));
    int viWordCount = 0;
    int enWordCount = 0;

    const commonEnglishWords = {
      'hello', 'everyone', 'hi', 'welcome', 'today', 'we', 'will', 'need', 'to',
      'the', 'and', 'for', 'with', 'this', 'that', 'what', 'about', 'how', 'are',
      'you', 'thank', 'thanks', 'good', 'morning', 'afternoon', 'evening', 'meeting',
      'project', 'system', 'data', 'time', 'want', 'tell', 'me', 'can', 'please',
      'let', 'know', 'think', 'agree', 'right', 'now', 'because', 'so', 'very',
      'much', 'from', 'have', 'has', 'had', 'not', 'don\'t', 'it', 'is', 'was'
    };

    for (final rawW in words) {
      final w = rawW.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').toLowerCase();
      if (w.isEmpty) continue;
      if (vietnameseDiacritics.hasMatch(w)) {
        viWordCount++;
      } else if (commonEnglishWords.contains(w)) {
        enWordCount++;
      }
    }

    if (enWordCount > viWordCount) return 'en';
    if (viWordCount > 0) return 'vi';

    return 'en';
  }

  /// Kiểm tra xem câu vừa thu có phải là thuần ngôn ngữ đích (không lẫn từ tiếng Anh cần dịch) hay không
  bool _isPureTargetLanguage(String text, String targetLanguage) {
    final String targetIso = _resolveIsoLangCode(targetLanguage);
    final String detectedIso = _detectTextLanguageHeuristic(text);

    if (detectedIso != targetIso) return false;

    if (targetIso == 'vi') {
      final vietnameseDiacritics = RegExp(
        r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
        caseSensitive: false,
      );
      // Có dấu Tiếng Việt và không phải câu Tiếng Anh bị phiên âm
      final words = text.trim().split(RegExp(r'\s+'));
      int diacriticWords = 0;
      for (final w in words) {
        if (vietnameseDiacritics.hasMatch(w)) diacriticWords++;
      }
      return diacriticWords >= (words.length * 0.4).ceil();
    }

    return true;
  }

  String _isoToDisplayLangName(String isoCode) {
    switch (isoCode) {
      case 'vi':
        return 'Việt';
      case 'en':
        return 'Anh';
      case 'ja':
        return 'Nhật';
      case 'ko':
        return 'Hàn';
      case 'zh-CN':
        return 'Trung (Giản)';
      case 'zh-TW':
        return 'Trung (Phồn)';
      case 'fr':
        return 'Pháp';
      case 'de':
        return 'Đức';
      case 'es':
        return 'Tây Ban Nha';
      default:
        return 'Anh';
    }
  }

  void _clearCurrentUtteranceAcousticBuffer() {
    _currentUtterancePitches.clear();
    _currentUtteranceZcrs.clear();
    _currentUtteranceRms.clear();
  }

  Future<void> stopRecording() async {
    _isListening = false;
    _isPaused = false;
    _vadMonitorTimer?.cancel();
    await _vadAudioSub?.cancel();
    _vadAudioSub = null;

    if (_activeInterimTranscript.trim().isNotEmpty) {
      _commitActiveDeltaSegment();
    }

    try {
      await _vadRecorder.stop();
    } catch (_) {}

    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 100));

    _rawSessionTranscript = '';
    _committedPrefixInSession = '';
    _activeInterimTranscript = '';
    _activeInterimAlternates = [];
    _clearCurrentUtteranceAcousticBuffer();
    onVadStatsChanged?.call(0.0, 0, 'IDLE');
  }

  Future<void> forceFinalizeCurrentSentence() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (_activeInterimTranscript.trim().isNotEmpty) {
      _commitActiveDeltaSegment();
    }
  }

  // ===========================================================================
  // PHẦN 3: AI PHONETIC ASR RECONSTRUCTION, AUTO-DETECT PASSTHROUGH & TRANSLATION
  // ===========================================================================
  Future<void> _triggerThrottledDraftTranslation(String interimText, List<String> alternates) async {
    final words = interimText.trim().split(RegExp(r'\s+'));
    if (words.length - _lastDraftWordCount < 2 || _isTranslatingDraft) return;

    _lastDraftWordCount = words.length;
    _isTranslatingDraft = true;
    final sw = Stopwatch()..start();

    String target = _currentTargetLang;
    if (_isTwoWayMode) {
      final detected = _detectTextLanguageHeuristic(interimText);
      final String targetIso = _resolveIsoLangCode(_currentTargetLang);
      if (detected == targetIso) {
        target = _originalSourceLangName;
      }
    }

    final dualResult = await reconstructAndTranslateWithContext(
      interimText,
      targetLanguage: target,
      isFinalSentence: false,
      speakerId: currentSpeaker,
      asrAlternates: alternates,
    );
    sw.stop();

    if (_activeInterimTranscript.isNotEmpty) {
      onPartialResult?.call(
        dualResult.reconstructedOriginal,
        dualResult.translatedText,
        sw.elapsedMilliseconds,
      );
    }
    _isTranslatingDraft = false;
  }

  Future<void> _finalizeSentenceAndTranslate(
      String finalSentence,
      int speakerId, {
        List<String> asrAlternates = const [],
      }) async {
    if (finalSentence.trim().isEmpty) return;
    final sw = Stopwatch()..start();

    final String detectedIso = _detectTextLanguageHeuristic(finalSentence);
    final String targetIso = _resolveIsoLangCode(_currentTargetLang);

    String target = _currentTargetLang;
    String source = _isoToDisplayLangName(detectedIso);

    if (_isTwoWayMode) {
      if (detectedIso == targetIso) {
        target = _originalSourceLangName;
        source = _currentTargetLang;
      } else {
        source = _originalSourceLangName;
      }
    } else {
      target = _currentTargetLang;
    }

    final dualResult = await reconstructAndTranslateWithContext(
      finalSentence,
      targetLanguage: target,
      isFinalSentence: true,
      speakerId: speakerId,
      asrAlternates: asrAlternates,
    );
    sw.stop();

    if (dualResult.detectedSourceLangName.isNotEmpty) {
      source = dualResult.detectedSourceLangName;
    }

    onFinalSentence?.call(
      dualResult.reconstructedOriginal,
      dualResult.translatedText,
      speakerId,
      source,
      target,
      sw.elapsedMilliseconds,
    );

    if (autoSpeakTranslation) {
      await speakNative(dualResult.translatedText, targetLanguage: target);
    }
  }

  Future<String> translateTextWithContext(
      String text, {
        String targetLanguage = 'Tiếng Việt',
        bool isFinalSentence = true,
        int? speakerId,
      }) async {
    final res = await reconstructAndTranslateWithContext(
      text,
      targetLanguage: targetLanguage,
      isFinalSentence: isFinalSentence,
      speakerId: speakerId,
    );
    return res.translatedText;
  }

  /// Bộ máy AI 2 tầng xử lý triệt để cả 2 chiều:
  /// - Khi bạn nói Tiếng Việt: Thu chuẩn Tiếng Việt -> Trùng ngôn ngữ đích (`Việt`) -> Giữ nguyên văn bản 100%!
  /// - Khi bạn nói Tiếng Anh: Khôi phục chuẩn câu Tiếng Anh (nếu bị phiên âm nhẹ sang âm Việt) -> Dịch sang Tiếng Việt!
  Future<DualStageTranslationResult> reconstructAndTranslateWithContext(
      String rawAsrText, {
        String targetLanguage = 'Tiếng Việt',
        bool isFinalSentence = true,
        int? speakerId,
        List<String> asrAlternates = const [],
      }) async {
    final cleanInput = rawAsrText.trim();
    if (cleanInput.isEmpty) {
      return DualStageTranslationResult(reconstructedOriginal: '', translatedText: '');
    }

    final spkLabel = 'Speaker ${(speakerId ?? currentSpeaker).toString().padLeft(2, '0')}';
    final String detectedIso = _detectTextLanguageHeuristic(cleanInput);
    final String targetIso = _resolveIsoLangCode(targetLanguage);
    final String detectedLangDisplay = _isoToDisplayLangName(detectedIso);

    // 1. NẾU ĐANG Ở CHẾ ĐỘ "TỰ ĐỘNG" VÀ CÂU THU ĐƯỢC LÀ TIẾNG VIỆT RÕ RÀNG (TRÙNG ĐÍCH):
    // Lập tức giữ nguyên văn bản 100% ở cả 2 cột mà không cần gọi dịch!
    if (_isAutoDetectSource && _isPureTargetLanguage(cleanInput, targetLanguage)) {
      final String formattedSameText = cleanInput[0].toUpperCase() + cleanInput.substring(1);
      if (isFinalSentence) {
        _pushToSlidingWindow('$spkLabel: $formattedSameText');
      }
      return DualStageTranslationResult(
        reconstructedOriginal: formattedSameText,
        translatedText: formattedSameText,
        detectedSourceLangName: detectedLangDisplay,
        isSameAsTarget: true,
      );
    }

    final demoMatch = _checkDemoDictionary(cleanInput);
    if (demoMatch != null) {
      if (isFinalSentence) _pushToSlidingWindow('$spkLabel: $cleanInput');
      return DualStageTranslationResult(
        reconstructedOriginal: cleanInput,
        translatedText: (targetIso == 'en') ? cleanInput : demoMatch,
        detectedSourceLangName: 'Anh',
      );
    }

    String envKey = '';
    try {
      if (dotenv.isInitialized) {
        envKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
      }
    } catch (_) {}
    final activeKey = customApiKey.trim().isNotEmpty ? customApiKey.trim() : envKey.trim();

    if (activeKey.isNotEmpty) {
      final glossaryFormatted = customGlossary.isNotEmpty
          ? customGlossary.entries.map((e) => '"${e.key}" bắt buộc dịch là "${e.value}"').join('; ')
          : 'Không có từ điển bắt buộc.';

      final historyFormatted = _slidingWindow.isNotEmpty
          ? _slidingWindow.asMap().entries.map((e) => '[Câu -${_slidingWindow.length - e.key}] ${e.value}').join('\n')
          : 'Chưa có câu hội thoại trước đó.';

      final alternatesFormatted = asrAlternates.isNotEmpty
          ? asrAlternates.map((a) => '- "$a"').join('\n')
          : 'Không có phương án phụ.';

      final prompt = '''
Bạn là Chuyên gia Khôi phục Ngữ âm Song ngữ (Bilingual Phonetic ASR Reconstruction) và Dịch thuật Thời gian thực của hệ thống GoTrans.

1. THÔNG TIN NGỮ CẢNH:
- Bối cảnh chủ đề: $meetingContext
- Ngôn ngữ đích người dùng muốn nhận (`targetLanguage`): "$targetLanguage"
- Chế độ thu âm: ${_isAutoDetectSource ? "TỰ ĐỘNG NHẬN DẠNG NGÔN NGỮ (Auto-detect)" : "Dịch 2 chiều"}
- Từ điển chuyên ngành bắt buộc: $glossaryFormatted
- Lịch sử các câu vừa nói trước đó:
$historyFormatted

2. DỮ LIỆU ĐẦU VÀO TỪ MICROPHONE:
- Chuỗi ASR chính thu được của [$spkLabel]: "$cleanInput"
- Các phương án ASR dự phòng (N-Best Alternates):
$alternatesFormatted

3. QUY TẮC XỬ LÝ BẮT BUỘC:
- TRƯỜNG HỢP 1 (NGƯỜI NÓI ĐANG NÓI TIẾNG VIỆT / CÙNG NGÔN NGỮ ĐÍCH "$targetLanguage"):
  Nếu chuỗi đầu vào là câu tiếng Việt có nghĩa (hoặc là câu tiếng Việt bị bộ thu âm nghe nhầm sang các từ tiếng Anh đồng âm vô nghĩa về mặt ngữ cảnh như "I want to wait time", "Dollar General"), hãy khôi phục lại đúng câu tiếng Việt gốc vào `reconstructed_source`, đặt `detected_lang` là "Việt", và GIỮ NGUYÊN hoàn toàn câu tiếng Việt đó ở `translated_text` (tuyệt đối không dịch sang ngôn ngữ khác).
- TRƯỜNG HỢP 2 (NGƯỜI NÓI ĐANG NÓI TIẾNG ANH / NGÔN NGỮ KHÁC VỚI "$targetLanguage"):
  Nếu người nói đang phát âm tiếng Anh (kể cả khi bộ thu âm `vi-VN` phiên âm một vài từ tiếng Anh sang chữ tiếng Việt đồng âm, hoặc người nói nói nhanh bị nuốt âm), hãy khôi phục lại câu tiếng Anh chuẩn xác vào `reconstructed_source`, đặt `detected_lang` là "Anh", và DỊCH câu đó sang "$targetLanguage" một cách tự nhiên, chuẩn xác ở `translated_text`.

4. ĐỊNH DẠNG ĐẦU RA:
Chỉ trả về duy nhất 1 đối tượng JSON hợp lệ có đúng 3 trường sau:
{"reconstructed_source": "câu gốc đã khôi phục", "translated_text": "bản dịch sang $targetLanguage (hoặc giữ nguyên nếu câu gốc đã là $targetLanguage)", "detected_lang": "Việt hoặc Anh"}
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$activeKey',
      );

      try {
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
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            }
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final rawResponseText =
              data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString().trim() ?? '';

          if (rawResponseText.isNotEmpty) {
            final parsedDual = _parseDualStageJsonResponse(
              rawResponseText,
              cleanInput,
              targetLanguage: targetLanguage,
            );
            if (isFinalSentence) {
              _pushToSlidingWindow('$spkLabel: ${parsedDual.reconstructedOriginal}');
            }
            return parsedDual;
          }
        }
      } catch (e) {
        debugPrint('Gemini Dual-Stage API Error: $e');
      }
    }

    // Fallback khi không có Gemini Key hoặc mất kết nối
    final repairedInput = _localPhoneticQuickRepair(cleanInput);
    if (isFinalSentence) _pushToSlidingWindow('$spkLabel: $repairedInput');

    if (_isAutoDetectSource && detectedIso == targetIso) {
      return DualStageTranslationResult(
        reconstructedOriginal: repairedInput,
        translatedText: repairedInput,
        detectedSourceLangName: detectedLangDisplay,
        isSameAsTarget: true,
      );
    }

    final fallbackTranslated = await _realCloudFallbackTranslate(repairedInput, targetLanguage);
    return DualStageTranslationResult(
      reconstructedOriginal: repairedInput,
      translatedText: fallbackTranslated,
      detectedSourceLangName: detectedLangDisplay,
      isSameAsTarget: false,
    );
  }

  DualStageTranslationResult _parseDualStageJsonResponse(
      String rawJson,
      String fallbackOriginal, {
        required String targetLanguage,
      }) {
    try {
      String cleaned = rawJson.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```json\s*|^```\s*|\s*```$'), '').trim();
      }
      final Map<String, dynamic> map = jsonDecode(cleaned);
      final String reconstructed = _stripLanguagePrefix(
        (map['reconstructed_source'] ?? fallbackOriginal).toString(),
      );
      String translated = _stripLanguagePrefix(
        (map['translated_text'] ?? '').toString(),
      );
      final String detectedLang = (map['detected_lang'] ?? '').toString().trim();

      final String sourceActual = reconstructed.isNotEmpty ? reconstructed : fallbackOriginal;

      if (_isAutoDetectSource && _isPureTargetLanguage(sourceActual, targetLanguage)) {
        translated = sourceActual;
      }

      if (translated.isNotEmpty) {
        return DualStageTranslationResult(
          reconstructedOriginal: sourceActual,
          translatedText: translated,
          detectedSourceLangName: detectedLang.isNotEmpty
              ? detectedLang
              : _isoToDisplayLangName(_detectTextLanguageHeuristic(sourceActual)),
          isSameAsTarget: sourceActual.toLowerCase() == translated.toLowerCase(),
        );
      }
    } catch (e) {
      debugPrint('JSON Parse Fallback: $e');
    }

    return DualStageTranslationResult(
      reconstructedOriginal: fallbackOriginal,
      translatedText: _stripLanguagePrefix(rawJson),
    );
  }

  String _localPhoneticQuickRepair(String text) {
    String out = text.trim();
    final Map<RegExp, String> commonFastSpeechFixes = {
      RegExp(r'\bgonna\b', caseSensitive: false): 'going to',
      RegExp(r'\bwanna\b', caseSensitive: false): 'want to',
      RegExp(r'\bgotta\b', caseSensitive: false): 'got to',
      RegExp(r'\bkinda\b', caseSensitive: false): 'kind of',
      RegExp(r'\bsorta\b', caseSensitive: false): 'sort of',
      RegExp(r'\blemme\b', caseSensitive: false): 'let me',
      RegExp(r'\bgimme\b', caseSensitive: false): 'give me',
      RegExp(r'\bcuz\b|\bcause\b', caseSensitive: false): 'because',
    };
    commonFastSpeechFixes.forEach((pattern, replacement) {
      out = out.replaceAll(pattern, replacement);
    });
    if (out.isNotEmpty) {
      out = out[0].toUpperCase() + out.substring(1);
    }
    return out;
  }

  Future<String> _realCloudFallbackTranslate(String text, String targetLanguage) async {
    final String tlCode = _resolveIsoLangCode(targetLanguage);

    if (_isAutoDetectSource && _detectTextLanguageHeuristic(text) == tlCode) {
      return text;
    }

    try {
      final gtxUrl = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$tlCode&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final response = await http.get(gtxUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<dynamic> sentences = data[0];
        final StringBuffer buffer = StringBuffer();
        for (final s in sentences) {
          if (s != null && s[0] != null) {
            buffer.write(s[0].toString());
          }
        }
        String result = buffer.toString().trim();
        if (result.isNotEmpty) {
          return _applyCustomGlossaryPostProcess(text, result);
        }
      }
    } catch (e) {
      debugPrint('GTX Fallback Error: $e');
    }

    try {
      final String slCode = (tlCode == 'vi') ? 'en' : 'vi';
      final mmUrl = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$slCode|$tlCode',
      );
      final mmRes = await http.get(mmUrl).timeout(const Duration(seconds: 4));
      if (mmRes.statusCode == 200) {
        final data = jsonDecode(mmRes.body);
        final String translated = (data['responseData']?['translatedText'] ?? '').toString().trim();
        if (translated.isNotEmpty) {
          return _applyCustomGlossaryPostProcess(text, translated);
        }
      }
    } catch (e) {
      debugPrint('MyMemory Fallback Error: $e');
    }

    return _applyCustomGlossaryPostProcess(text, text);
  }

  String _resolveIsoLangCode(String targetLanguage) {
    final lower = targetLanguage.toLowerCase().trim();
    if (lower.contains('việt') || lower.contains('vietnamese') || lower == 'vi' || lower == 'vi-vn') return 'vi';
    if (lower.contains('anh') || lower.contains('english') || lower == 'en' || lower == 'en-us') return 'en';
    if (lower.contains('nhật') || lower.contains('japanese') || lower == 'ja' || lower == 'ja-jp') return 'ja';
    if (lower.contains('hàn') || lower.contains('korean') || lower == 'ko' || lower == 'ko-kr') return 'ko';
    if (lower.contains('phồn') || lower == 'zh-tw') return 'zh-TW';
    if (lower.contains('trung') || lower.contains('chinese') || lower == 'zh' || lower == 'zh-cn') return 'zh-CN';
    if (lower.contains('pháp') || lower.contains('french') || lower == 'fr' || lower == 'fr-fr') return 'fr';
    if (lower.contains('đức') || lower.contains('german') || lower == 'de' || lower == 'de-de') return 'de';
    if (lower.contains('tây ban nha') || lower.contains('spanish') || lower == 'es' || lower == 'es-es') return 'es';
    if (lower.contains('ý') || lower.contains('italian') || lower == 'it' || lower == 'it-it') return 'it';
    if (lower.contains('nga') || lower.contains('russian') || lower == 'ru' || lower == 'ru-ru') return 'ru';
    if (lower.contains('thái') || lower.contains('thai') || lower == 'th' || lower == 'th-th') return 'th';
    if (lower.contains('indonesia') || lower == 'id' || lower == 'id-id') return 'id';
    return 'vi';
  }

  String _applyCustomGlossaryPostProcess(String originalText, String translatedText) {
    String output = _stripLanguagePrefix(translatedText);
    customGlossary.forEach((key, val) {
      if (originalText.toLowerCase().contains(key.toLowerCase()) &&
          !output.toLowerCase().contains(val.toLowerCase())) {
        output = output.replaceAll(RegExp(key, caseSensitive: false), val);
      }
    });
    return output;
  }

  String _stripLanguagePrefix(String input) {
    return input
        .replaceAll(RegExp(r'^["' "'" r']|["' "'" r']$'), '')
        .replaceAll(RegExp(r'^\s*\[?speaker\s*\d+\]?\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*\((tiếng việt|vietnamese|english|tiếng anh|việt|anh|vi|en)\)\s*', caseSensitive: false), '')
        .trim();
  }

  Future<void> _initNativeTts() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setVolume(_ttsVolume);
      await _tts.setSpeechRate(_ttsSpeechRate);
      await _tts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  Future<void> speakNative(String rawText, {String targetLanguage = 'Tiếng Việt'}) async {
    final cleanText = _stripLanguagePrefix(rawText);
    if (cleanText.isEmpty || cleanText == '...' || cleanText == '...đang dịch...') return;

    await _initNativeTts();
    try {
      await _tts.stop();
      final isoCode = _resolveIsoLangCode(targetLanguage);
      final bool isVietnamese = (isoCode == 'vi');
      final String targetLocale = isVietnamese ? 'vi-VN' : (isoCode == 'en' ? 'en-US' : isoCode);

      await _tts.setLanguage(targetLocale);

      final dynamic voices = await _tts.getVoices;
      if (voices is List) {
        Map<String, String>? selectedVoice;

        for (final v in voices) {
          if (v is Map) {
            final String name = (v['name'] ?? '').toString();
            final String locale = (v['locale'] ?? '').toString().replaceAll('_', '-');

            if (!isVietnamese && locale.toLowerCase().startsWith('en')) {
              if (name.contains('Google US English') ||
                  name.contains('Natural') ||
                  name.contains('Aria') ||
                  name.contains('Guy') ||
                  name.contains('Jenny') ||
                  locale == 'en-US') {
                selectedVoice = {'name': name, 'locale': locale};
                if (name.contains('Google US English') || name.contains('Natural')) break;
              }
            } else if (isVietnamese && locale.toLowerCase().startsWith('vi')) {
              if (name.contains('Google') ||
                  name.contains('HoaiMy') ||
                  name.contains('NamMinh') ||
                  name.contains('Natural') ||
                  locale == 'vi-VN') {
                selectedVoice = {'name': name, 'locale': locale};
                if (name.contains('Google') || name.contains('HoaiMy')) break;
              }
            }
          }
        }

        if (selectedVoice != null) {
          await _tts.setVoice(selectedVoice);
        }
      }

      await _tts.speak(cleanText);
    } catch (e) {
      debugPrint('Native TTS Error: $e');
    }
  }

  void _pushToSlidingWindow(String sentence) {
    _slidingWindow.add(sentence);
    if (_slidingWindow.length > maxWindowSize) {
      _slidingWindow.removeAt(0);
    }
  }

  String? _checkDemoDictionary(String text) {
    const demoDict = {
      'We need to optimize the audio pipeline to reduce latency during real-time translation.':
      'Chúng ta cần tối ưu hóa luồng xử lý âm thanh để giảm độ trễ trong quá trình dịch thuật thời gian thực.',
    };
    return demoDict[text];
  }

  void dispose() {
    _vadMonitorTimer?.cancel();
    _vadAudioSub?.cancel();
    _vadRecorder.dispose();
    _speech.stop();
    _tts.stop();
  }
}