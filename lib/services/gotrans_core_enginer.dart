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
  // --- 1. Quản lý Luồng Thu âm & Lọc Nhiễu Động (Adaptive Noise Cancellation) ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _vadRecorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Uint8List>? _vadAudioSub;

  bool _isListening = false;
  bool _isPaused = false;
  bool _isTtsInitialized = false;
  String _currentSourceLocale = 'en-US';
  String _currentTargetLang = 'Tiếng Việt';

  // Audio settings
  InputDevice? _selectedInputDevice;
  double _ttsVolume = 1.0;
  double _ttsSpeechRate = 0.95;

  // --- CƠ CHẾ LỌC NHIỄU NỀN ĐỘNG (ADAPTIVE NOISE FLOOR) & DELTA SLICING ---
  double _adaptiveNoiseFloor = 10.0;     // Tự động học mức tiếng ồn nền của phòng
  String _rawSessionTranscript = '';     // Chuỗi cộng dồn của phiên hiện tại
  String _committedPrefixInSession = ''; // Phần chuỗi đã chốt trong phiên
  String _activeInterimTranscript = '';  // Phần chữ mới phát sinh (Delta)
  String _lastFinalizedText = '';
  int _lastDraftWordCount = 0;
  bool _isTranslatingDraft = false;
  bool _isSpeakingVad = false;
  DateTime _lastSpeechTimestamp = DateTime.now();
  DateTime _lastTextChangeTimestamp = DateTime.now(); // Theo dõi lúc chữ thực sự thay đổi (Chống kẹt VAD khi phòng ồn)
  DateTime _utteranceStartTime = DateTime.now();
  DateTime _lastFinalizationTimestamp = DateTime.now();
  Timer? _vadMonitorTimer;

  // Cấu hình VAD & Diarization
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
  final Function(String finalOriginal, String finalTranslation, int speakerId, int latencyMs)? onFinalSentence;
  final Function(String errorMessage)? onError;

  GoTransCoreEngine({
    this.vadThreshold = 14.0,
    this.silenceDurationMs = 700, // Chốt câu nhạy sau 700ms khi không có chữ mới
    this.speakerSwitchSilenceMs = 2600,
    this.autoDiarization = true,
    this.autoSpeakTranslation = false,
    this.maxSpeakers = 8,
    this.speakerSimilarityThreshold = 0.58,
    this.maxWindowSize = 5,
    this.meetingContext = 'Cuộc họp kỹ thuật triển khai hệ thống AI thu âm thời gian thực và tối ưu hóa độ trễ truyền tải.',
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

  void setInputDevice(InputDevice device) => _selectedInputDevice = device;

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
  // PHẦN 1: THU ÂM CHỐNG ỒN & TỰ ĐỘNG HIỆU CHỈNH NỀN TẠP ÂM (NOISE FLOOR)
  // ===========================================================================
  Future<bool> startRecording({
    String sourceLocaleId = 'en-US',
    String targetLanguage = 'Tiếng Việt',
  }) async {
    _currentSourceLocale = _normalizeSpeechLocale(sourceLocaleId, targetLanguage);
    _currentTargetLang = targetLanguage;

    bool speechAvailable = await _speech.initialize(
      debugLogging: false,
      finalTimeout: const Duration(seconds: 5),
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
        // Khi môi trường ồn gây lỗi 'no-speech' hoặc 'network', tự động nối lại ngay lập tức mà không tắt mic
        if (_isListening && !_isPaused) {
          if (_activeInterimTranscript.trim().isNotEmpty) {
            _commitActiveDeltaSegment();
          }
          _committedPrefixInSession = '';
          _rawSessionTranscript = '';
          Future.delayed(const Duration(milliseconds: 30), () {
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
    _adaptiveNoiseFloor = 10.0;
    _rawSessionTranscript = '';
    _committedPrefixInSession = '';
    _activeInterimTranscript = '';
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
      await Future.delayed(const Duration(milliseconds: 150));
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
        _committedPrefixInSession = '';
        _rawSessionTranscript = '';
        _startWebSpeechLoop();
      }
    }
  }

  String _normalizeSpeechLocale(String rawSource, String targetLang) {
    final s = rawSource.toLowerCase().trim();
    if (s == 'auto' || s.contains('tự động') || s.contains('auto-detect')) {
      final t = targetLang.toLowerCase().trim();
      if (t.contains('vi') || t.contains('việt')) {
        return 'en-US';
      } else {
        return 'vi-VN';
      }
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
    return 'en-US';
  }

  void _startWebSpeechLoop() {
    if (!_isListening || _isPaused || _speech.isListening) return;

    _speech.listen(
      localeId: _currentSourceLocale,
      pauseFor: const Duration(seconds: 60),
      listenFor: const Duration(minutes: 15),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false, // Bắt buộc false để không bị văng khi có tiếng ồn lớn đột ngột
        onDevice: false,      // Sử dụng mô hình Cloud Conformer lớn nhất để lọc tiếng ồn tốt nhất
        listenMode: stt.ListenMode.dictation,
        autoPunctuation: true,
      ),
      onSoundLevelChange: (level) {
        if (_vadAudioSub == null && !_isPaused) {
          final fallbackRms = ((level + 2) * 8.5).clamp(0.0, 100.0);
          _processAdaptiveNoiseAndVad(fallbackRms);
        }
      },
      onResult: (result) {
        if (_isPaused) return;

        // Chọn phương án nhận diện tốt nhất từ danh sách alternates (Nếu môi trường ồn)
        String fullRecognized = result.recognizedWords.trim();
        if (result.alternates.length > 1) {
          for (final alt in result.alternates) {
            if (alt.confidence > 0.75 && alt.recognizedWords.trim().length > fullRecognized.length) {
              fullRecognized = alt.recognizedWords.trim();
              break;
            }
          }
        }

        if (fullRecognized.isEmpty) return;
        _rawSessionTranscript = fullRecognized;

        final String deltaText = _extractUncommittedDelta(fullRecognized);
        if (deltaText.isEmpty) return;

        // Chỉ cập nhật _lastTextChangeTimestamp khi thực sự có chữ mới xuất hiện!
        // Điều này giúp hệ thống chốt câu chính xác ngay cả khi phòng rất ồn (RMS luôn cao)
        if (deltaText != _activeInterimTranscript) {
          _lastTextChangeTimestamp = DateTime.now();
          _lastSpeechTimestamp = DateTime.now();
          _isSpeakingVad = true;
        }

        if (_activeInterimTranscript.isEmpty) {
          _utteranceStartTime = DateTime.now();
        }

        if (!result.finalResult) {
          _activeInterimTranscript = deltaText;

          if (autoDiarization && _currentUtterancePitches.length >= 4) {
            final previewSpk = _identifyOrCreateSpeaker(deltaText, isCommit: false);
            if (previewSpk != currentSpeaker) {
              currentSpeaker = previewSpk;
              onSpeakerChanged?.call(currentSpeaker);
            }
          }

          onPartialResult?.call(deltaText, '', 0);
          _triggerThrottledDraftTranslation(deltaText);
        } else {
          _activeInterimTranscript = deltaText;
          _commitActiveDeltaSegment();
          _committedPrefixInSession = '';
          _rawSessionTranscript = '';
        }
      },
    );
  }

  /// Thuật toán lọc nhiễu nền động (Adaptive Noise Floor):
  /// Tự động nâng ngưỡng VAD nếu phòng ồn để không bị kẹt trạng thái SPEAKING
  void _processAdaptiveNoiseAndVad(double rms) {
    final now = DateTime.now();
    final int timeSinceLastTextChange = now.difference(_lastTextChangeTimestamp).inMilliseconds;

    // Nếu quá 500ms không có chữ mới nào được nhận diện, coi âm thanh hiện tại là tiếng ồn nền (Noise Floor)
    if (timeSinceLastTextChange > 500) {
      _adaptiveNoiseFloor = (0.92 * _adaptiveNoiseFloor + 0.08 * rms).clamp(5.0, 55.0);
    }

    // Ngưỡng VAD thực tế = Max(Ngưỡng cài đặt, Tiếng ồn nền + 8.0 dB)
    final double dynamicThreshold = max(vadThreshold, _adaptiveNoiseFloor + 8.0);

    if (rms >= dynamicThreshold) {
      _currentUtteranceRms.add(rms);
      _lastSpeechTimestamp = now;
      // Tránh việc tiếng ồn nền giữ trạng thái SPEAKING mãi mãi nếu không có chữ nào mới
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

    if (fullWords.length > prefixWords.length) {
      int matchCount = 0;
      for (int i = 0; i < prefixWords.length; i++) {
        if (fullWords[i].toLowerCase() == prefixWords[i].toLowerCase()) {
          matchCount++;
        }
      }
      if (matchCount >= (prefixWords.length * 0.55).floor()) {
        return fullWords.sublist(prefixWords.length).join(' ').trim();
      }
    }

    if (fullWords.length < prefixWords.length) {
      _committedPrefixInSession = '';
      return cleanFull;
    }

    return cleanFull;
  }

  void _commitActiveDeltaSegment() {
    final String segmentToCommit = _activeInterimTranscript.trim();
    if (segmentToCommit.isEmpty) return;

    if (_rawSessionTranscript.isNotEmpty) {
      _committedPrefixInSession = _rawSessionTranscript.trim();
    } else {
      _committedPrefixInSession =
          (_committedPrefixInSession.isEmpty ? '' : '$_committedPrefixInSession ') + segmentToCommit;
    }

    _activeInterimTranscript = '';
    _lastDraftWordCount = 0;
    _isSpeakingVad = false;

    if (segmentToCommit.toLowerCase() == _lastFinalizedText.toLowerCase() &&
        DateTime.now().difference(_lastFinalizationTimestamp).inMilliseconds < 1500) {
      return;
    }

    _lastFinalizedText = segmentToCommit;

    if (autoDiarization) {
      currentSpeaker = _identifyOrCreateSpeaker(segmentToCommit, isCommit: true);
      onSpeakerChanged?.call(currentSpeaker);
    }
    _lastFinalizationTimestamp = DateTime.now();

    _finalizeSentenceAndTranslate(segmentToCommit, currentSpeaker);
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
            echoCancel: false,   // Tắt Echo Cancel khi thu từ loa ngoài điện thoại để không bị cắt mất tiếng video!
            noiseSuppress: true, // Giữ lọc tạp âm môi trường
            autoGain: true,      // Tự động khuếch đại âm lượng nhỏ từ loa điện thoại
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

      // QUAN TRỌNG TRONG MÔI TRƯỜNG ỒN:
      // Dựa vào thời gian chữ ngừng thay đổi (_lastTextChangeTimestamp) kết hợp với âm lượng
      // Ngay cả khi phòng rất ồn làm mic luôn báo có âm thanh, hễ bạn bấm Pause video 750ms
      // (không có chữ mới sinh ra) là hệ thống tự động cắt câu và dịch ngay!
      final int noNewWordsElapsed = now.difference(_lastTextChangeTimestamp).inMilliseconds;

      if (_activeInterimTranscript.trim().isNotEmpty && noNewWordsElapsed >= silenceDurationMs) {
        onVadStatsChanged?.call(_adaptiveNoiseFloor, noNewWordsElapsed, 'FINALIZING');
        _commitActiveDeltaSegment();
      }
    });
  }

  // ===========================================================================
  // PHẦN 2: THUẬT TOÁN TRÍCH XUẤT ĐẶC TRƯNG GIỌNG NÓI & PHÂN CỤM ĐA SPEAKER
  // ===========================================================================
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
    final double normalizedRms = (rawRms * 260.0).clamp(0.0, 100.0);

    final double dynamicThreshold = max(vadThreshold, _adaptiveNoiseFloor + 8.0);
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

  String _detectTextLanguageHeuristic(String text) {
    final vietnameseRegex = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
      caseSensitive: false,
    );
    return vietnameseRegex.hasMatch(text) ? 'vi' : 'en';
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
    try {
      await _vadRecorder.stop();
    } catch (_) {}
    await _speech.stop();
    _rawSessionTranscript = '';
    _committedPrefixInSession = '';
    _activeInterimTranscript = '';
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
  // PHẦN 3: SỬA LỖI NGHE NHẦM DO TIẾNG ỒN (ASR ERROR RECOVERY) & DỊCH ĐA TẦNG
  // ===========================================================================
  Future<void> _triggerThrottledDraftTranslation(String interimText) async {
    final words = interimText.trim().split(RegExp(r'\s+'));
    if (words.length - _lastDraftWordCount < 2 || _isTranslatingDraft) return;

    _lastDraftWordCount = words.length;
    _isTranslatingDraft = true;
    final sw = Stopwatch()..start();

    final draftTranslated = await translateTextWithContext(
      interimText,
      targetLanguage: _currentTargetLang,
      isFinalSentence: false,
      speakerId: currentSpeaker,
    );
    sw.stop();

    if (_activeInterimTranscript.isNotEmpty) {
      onPartialResult?.call(_activeInterimTranscript, draftTranslated, sw.elapsedMilliseconds);
    }
    _isTranslatingDraft = false;
  }

  Future<void> _finalizeSentenceAndTranslate(String finalSentence, int speakerId) async {
    if (finalSentence.trim().isEmpty) return;
    final sw = Stopwatch()..start();

    final finalTranslation = await translateTextWithContext(
      finalSentence,
      targetLanguage: _currentTargetLang,
      isFinalSentence: true,
      speakerId: speakerId,
    );
    sw.stop();

    onFinalSentence?.call(finalSentence, finalTranslation, speakerId, sw.elapsedMilliseconds);

    if (autoSpeakTranslation) {
      await speakNative(finalTranslation, targetLanguage: _currentTargetLang);
    }
  }

  /// Dịch thuật tích hợp AI Phonetic Error Correction:
  /// Tự động khôi phục các từ bị nhận diện sai do tạp âm/tiếng ồn trước khi dịch
  Future<String> translateTextWithContext(
      String text, {
        String targetLanguage = 'Tiếng Việt',
        bool isFinalSentence = true,
        int? speakerId,
      }) async {
    final cleanInput = text.trim();
    if (cleanInput.isEmpty) return '';

    final spkLabel = 'Speaker ${(speakerId ?? currentSpeaker).toString().padLeft(2, '0')}';

    final demoMatch = _checkDemoDictionary(cleanInput);
    if (demoMatch != null) {
      if (isFinalSentence) _pushToSlidingWindow('$spkLabel: $cleanInput');
      return demoMatch;
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

      final prompt = '''
Bạn là AI Context Engine của hệ thống dịch thuật hội nghị thời gian thực GoTrans.
- Bối cảnh cuộc họp: $meetingContext
- Từ điển chuyên ngành bắt buộc (Custom Glossary): $glossaryFormatted
- Lịch sử hội thoại kèm nhãn người nói (Sliding Window Context):
$historyFormatted

LƯU Ý QUAN TRỌNG VỀ MÔI TRƯỜNG ỒN (ASR NOISE CORRECTION):
Văn bản đầu vào được thu từ Microphone trong môi trường có tạp âm nên một số từ có thể bị bộ nhận diện giọng nói nghe nhầm sang từ đồng âm (homophones) hoặc bị đứt chữ. Hãy tự động suy luận và khôi phục lại từ đúng dựa trên ngữ cảnh các câu trước đó rồi mới dịch sang $targetLanguage.
Chỉ trả về duy nhất nội dung bản dịch hoàn chỉnh, không giải thích, không kèm nhãn Speaker hay tên ngôn ngữ:
"$cleanInput"
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
            'generationConfig': {'temperature': 0.15}
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final translated = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString().trim() ?? '';
          if (translated.isNotEmpty) {
            if (isFinalSentence) _pushToSlidingWindow('$spkLabel: $cleanInput');
            return _stripLanguagePrefix(translated);
          }
        }
      } catch (e) {
        debugPrint('Gemini API Error: $e');
      }
    }

    if (isFinalSentence) _pushToSlidingWindow('$spkLabel: $cleanInput');
    return await _realCloudFallbackTranslate(cleanInput, targetLanguage);
  }

  Future<String> _realCloudFallbackTranslate(String text, String targetLanguage) async {
    final String tlCode = _resolveIsoLangCode(targetLanguage);

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

  // ===========================================================================
  // PHẦN 4: BỘ PHÁT ÂM GIỌNG BẢN ĐỊA (NATIVE SPEAKER TTS ENGINE)
  // ===========================================================================
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