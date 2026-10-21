import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AsrStreamEvent {
  final String transcript;
  final int speakerId;          // Kết quả từ thuật toán Speaker Diarization
  final String detectedLang;    // Kết quả từ thuật toán Spoken LID
  final bool isFinal;           // Câu đã hoàn chỉnh hay đang nói dở

  AsrStreamEvent({
    required this.transcript,
    required this.speakerId,
    required this.detectedLang,
    required this.isFinal,
  });
}

class GoTransAsrStreamService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  WebSocketChannel? _wsChannel;
  Timer? _keepAliveTimer;
  Timer? _vadSilenceTimer;

  // Cấu hình thuật toán VAD
  double vadRmsThreshold = 18.0; // Ngưỡng năng lượng âm thanh (0 - 100)
  int silenceDurationMs = 900;   // Ngừng nói 900ms -> Báo chốt câu
  bool _isSpeaking = false;

  // Callbacks trả về cho Engine tổng
  final Function(double rms)? onVadLevel;
  final Function(String vadState)? onVadStateChanged; // LISTENING, SPEAKING, FINALIZING
  final Function(AsrStreamEvent event)? onAsrResult;
  final Function(String error)? onError;

  GoTransAsrStreamService({
    this.onVadLevel,
    this.onVadStateChanged,
    this.onAsrResult,
    this.onError,
  });

  /// Khởi chạy đồng thời: WebSocket Streaming ASR (Diarization + LID) & Audio PCM Stream
  Future<bool> startStreaming({required String deepgramOrCustomWsKey}) async {
    try {
      if (!await _recorder.hasPermission()) {
        onError?.call('Trình duyệt chưa được cấp quyền Microphone!');
        return false;
      }

      // 1. Kết nối WebSocket ASR với các tham số thuật toán:
      // - model=nova-2: Kiến trúc Conformer/Transformer độ trễ cực thấp
      // - diarize=true: Bật thuật toán Speaker Diarization (Phân cụm d-vectors)
      // - language=multi: Bật thuật toán Spoken LID (Tự động nhận diện ngôn ngữ)
      // - interim_results=true: Trả kết quả tức thời khi đang nói
      final wsUri = Uri.parse(
        'wss://api.deepgram.com/v1/listen'
            '?encoding=linear16&sample_rate=16000&channels=1'
            '&model=nova-2&smart_format=true&diarize=true&language=multi&interim_results=true',
      );

      _wsChannel = WebSocketChannel.connect(
        wsUri,
        protocols: ['token', deepgramOrCustomWsKey],
      );

      // 2. Lắng nghe gói JSON trả về theo thời gian thực
      _wsChannel!.stream.listen(
        _parseIncomingAsrJson,
        onError: (e) => onError?.call('Lỗi luồng ASR WebSocket: $e'),
      );

      // Giữ kết nối WebSocket không bị ngắt khi phòng họp im lặng lâu
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        _wsChannel?.sink.add(jsonEncode({'type': 'KeepAlive'}));
      });

      // 3. Mở luồng thu âm PCM 16-bit 16kHz trực tiếp từ trình duyệt Web
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final audioStream = await _recorder.startStream(config);
      onVadStateChanged?.call('LISTENING');

      _audioSub = audioStream.listen((Uint8List pcmChunk) {
        // Tính toán năng lượng âm thanh RMS cho thuật toán VAD
        final double rms = _computeNormalizedRms(pcmChunk);
        onVadLevel?.call(rms);

        if (rms >= vadRmsThreshold) {
          // Phát hiện tiếng người nói -> Đẩy gói byte âm thanh lên WebSocket ngay lập tức
          _isSpeaking = true;
          onVadStateChanged?.call('SPEAKING');
          _wsChannel?.sink.add(pcmChunk);

          // Reset bộ đếm khoảng lặng
          _vadSilenceTimer?.cancel();
          _vadSilenceTimer = Timer(Duration(milliseconds: silenceDurationMs), () {
            _isSpeaking = false;
            onVadStateChanged?.call('FINALIZING');
            // Ép Server ASR chốt câu ngay khi người nói ngừng nghỉ
            _wsChannel?.sink.add(jsonEncode({'type': 'Finalize'}));
          });
        } else if (_isSpeaking) {
          // Vẫn gửi thêm các byte đuôi âm trong khoảng nghỉ ngắn để không bị cụt chữ cuối
          _wsChannel?.sink.add(pcmChunk);
        }
      });

      return true;
    } catch (e) {
      onError?.call('Không thể khởi tạo luồng âm thanh Web: $e');
      return false;
    }
  }

  /// Bóc tách kết quả: Transcript + Speaker Diarization + Spoken LID
  void _parseIncomingAsrJson(dynamic rawMessage) {
    try {
      final data = jsonDecode(rawMessage as String);
      if (data['type'] != 'Results') return;

      final channel = data['channel'];
      final alternatives = channel?['alternatives'] as List?;
      if (alternatives == null || alternatives.isEmpty) return;

      final bestAlt = alternatives[0];
      final String transcript = (bestAlt['transcript'] ?? '').toString().trim();
      if (transcript.isEmpty) return;

      final bool isFinal = data['is_final'] ?? false;

      // Trích xuất nhãn người nói (Speaker Diarization) từ mảng words
      int speakerId = 1;
      final words = bestAlt['words'] as List?;
      if (words != null && words.isNotEmpty && words.first['speaker'] != null) {
        speakerId = (words.first['speaker'] as int) + 1;
      }

      // Trích xuất ngôn ngữ tự động nhận diện (Spoken LID)
      String detectedLang = 'auto';
      if (channel['detected_language'] != null) {
        detectedLang = channel['detected_language'].toString();
      } else if (words != null && words.isNotEmpty && words.first['language'] != null) {
        detectedLang = words.first['language'].toString();
      }

      onAsrResult?.call(AsrStreamEvent(
        transcript: transcript,
        speakerId: speakerId,
        detectedLang: detectedLang,
        isFinal: isFinal,
      ));
    } catch (e) {
      debugPrint('Lỗi parse JSON ASR: $e');
    }
  }

  /// Công thức tính RMS chuẩn hóa (0 -> 100) từ mảng byte PCM 16-bit Little Endian
  double _computeNormalizedRms(Uint8List chunk) {
    if (chunk.length < 2) return 0.0;
    final byteData = ByteData.sublistView(chunk);
    double sumSquares = 0.0;
    final sampleCount = chunk.length ~/ 2;

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }

    final rawRms = sqrt(sumSquares / sampleCount);
    // Chuẩn hóa biên độ giọng nói thông thường (0 -> 6000) sang thang 0 -> 100 cho UI
    return ((rawRms / 6000.0) * 100.0).clamp(0.0, 100.0);
  }

  Future<void> stopStreaming() async {
    _vadSilenceTimer?.cancel();
    _keepAliveTimer?.cancel();
    await _audioSub?.cancel();
    await _recorder.stop();
    await _wsChannel?.sink.close();
    onVadStateChanged?.call('IDLE');
  }
}