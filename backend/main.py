import base64
import io
import os
import subprocess
import time
import tempfile

import imageio_ffmpeg
import soundfile as sf
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
from flask_cors import CORS

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, "..", ".env"), override=False)
load_dotenv(os.path.join(BASE_DIR, ".env"), override=False)

AI_PROVIDER = os.getenv("AI_PROVIDER", "openai").strip().lower()
if AI_PROVIDER == "gemini":
    from stt.gemini_transcriber import GeminiTranscriber
    from translation.gemini_translator import GeminiTranslationEngine
    from translation.gemini_tts import GeminiTTSEngine

    transcriber = GeminiTranscriber()
    translator = GeminiTranslationEngine()
    tts_engine = GeminiTTSEngine()
elif AI_PROVIDER == "openai":
    try:
        from stt.openai_transcriber import OpenAITranscriber
        from translation.openai_translator import OpenAITranslationEngine
        from translation.openai_tts import OpenAITTSEngine

        transcriber = OpenAITranscriber()
        translator = OpenAITranslationEngine()
        tts_engine = OpenAITTSEngine()
    except ImportError:
        print("Lỗi: Không tìm thấy các module STT/Translation. Đảm bảo cấu trúc thư mục đúng.")
        transcriber = None
        translator = None
        tts_engine = None
else:
    raise ValueError("AI_PROVIDER phải là 'gemini' hoặc 'openai'.")

app = Flask(__name__)
CORS(app)
app.config["SECRET_KEY"] = "speech-translator-local"
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading", max_http_buffer_size=5_000_000)

client_audio_buffers = {}
client_last_process_time = {}

if AI_PROVIDER == "gemini":
    try:
        from stt.gemini_live_socket import configure_live_socketio
        configure_live_socketio(socketio, translator, tts_engine)
    except ImportError: pass
elif AI_PROVIDER == "openai":
    try:
        from stt.openai_live_socket import configure_openai_live_socketio
        configure_openai_live_socketio(socketio, translator, tts_engine)
    except ImportError: pass


def decode_audio(audio_bytes):
    """Giải mã âm thanh Raw PCM (Dùng chung cho cả Web và Mobile)"""
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()

    with tempfile.NamedTemporaryFile(delete=False, suffix='.raw') as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        ffmpeg_cmd = [ffmpeg_exe, "-hide_banner", "-loglevel", "error", "-y"]
        ffmpeg_cmd.extend(["-f", "s16le", "-ar", "16000", "-ac", "1"])

        ffmpeg_cmd.extend([
            "-i", tmp_path,
            "-f", "wav", "-ac", "1", "-ar", "16000", "pipe:1"
        ])

        result = subprocess.run(
            ffmpeg_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=15,
        )

        if len(result.stdout) < 100:
            err_msg = result.stderr.decode('utf-8', errors='ignore')
            raise ValueError(f"FFmpeg trả về rỗng. Lỗi: {err_msg}")

        audio, sample_rate = sf.read(io.BytesIO(result.stdout), dtype="float32")
        return audio, int(sample_rate)
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


@app.get("/")
def index():
    return "Backend is running"

@app.get("/api/health")
def health():
    return jsonify({"status": "ok", "provider": AI_PROVIDER})

@socketio.on("connect")
def handle_connect():
    client_audio_buffers[request.sid] = bytearray()
    client_last_process_time[request.sid] = 0
    emit("connection_status", {"connected": True, "provider": AI_PROVIDER})

@socketio.on("disconnect")
def handle_disconnect():
    if request.sid in client_audio_buffers:
        del client_audio_buffers[request.sid]
    if request.sid in client_last_process_time:
        del client_last_process_time[request.sid]

@socketio.on("end_audio_stream")
def handle_end_stream():
    """Làm mới dữ liệu khi kết thúc 1 câu"""
    if request.sid in client_audio_buffers:
        client_audio_buffers[request.sid] = bytearray()
        client_last_process_time[request.sid] = 0


# SỰ KIỆN MỚI: Xử lý luồng Text gửi trực tiếp từ Flutter Speech-To-Text
@socketio.on("text_stream")
def handle_text_stream(data):
    started = time.perf_counter()
    chunk_id = data.get("chunk_id") if isinstance(data, dict) else None

    try:
        if not isinstance(data, dict):
            return

        source_text = data.get("text", "").strip()
        target_lang = data.get("target_lang", "Tiếng Anh")
        is_final = data.get("is_final", False)

        if not source_text or not translator:
            return

        # Chặn gọi API dịch thuật quá dồn dập (Throttle 0.5s) trừ khi là kết quả chốt câu
        now = time.time()
        if not is_final and now - client_last_process_time.get(request.sid, 0) < 0.5:
            return
        client_last_process_time[request.sid] = now

        accumulated_target_text = ""

        # Gọi Stream dịch thuật và phát kết quả liên tục
        for text_chunk in translator.translate_stream(source_text, target_lang=target_lang):
            accumulated_target_text += text_chunk

            emit("translation_result", {
                "chunk_id": chunk_id,
                "source_text": source_text,
                "target_text": accumulated_target_text,
                "is_final": False,
                "total_ms": (time.perf_counter() - started) * 1000,
                "message": "streaming",
            })

        if is_final:
            emit("translation_result", {
                "chunk_id": chunk_id,
                "source_text": source_text,
                "target_text": accumulated_target_text,
                "is_final": True,
                "message": "success",
            })

    except Exception as e:
        print(f"[LỖI XỬ LÝ TEXT STREAM]: {str(e)}")


@socketio.on("audio_chunk")
def handle_audio_chunk(data):
    started = time.perf_counter()
    chunk_id = data.get("chunk_id") if isinstance(data, dict) else None
    try:
        if not isinstance(data, dict):
            return

        audio_b64 = data.get("audio")
        is_web = data.get("is_web", False)
        source_lang = data.get("source_lang", "Tiếng Việt")
        target_lang = data.get("target_lang", "Tiếng Anh")

        if not isinstance(audio_b64, str) or not audio_b64:
            return

        audio_bytes = base64.b64decode(audio_b64, validate=True)

        if request.sid not in client_audio_buffers:
            client_audio_buffers[request.sid] = bytearray()

        client_audio_buffers[request.sid].extend(audio_bytes)

        now = time.time()
        if now - client_last_process_time.get(request.sid, 0) < 1.0:
            return
        client_last_process_time[request.sid] = now

        try:
            audio, sample_rate = decode_audio(bytes(client_audio_buffers[request.sid]))
        except ValueError:
            return

        if len(audio) < sample_rate // 2 or not transcriber:
            return

        stt_result = transcriber.transcribe(audio, sample_rate=sample_rate)
        source_text = stt_result.get("text", "").strip()

        if not source_text:
            return

        accumulated_target_text = ""

        for text_chunk in translator.translate_stream(source_text, target_lang=target_lang):
            accumulated_target_text += text_chunk

            emit("translation_result", {
                "chunk_id": chunk_id,
                "source_text": source_text,
                "target_text": accumulated_target_text,
                "is_final": False,
                "total_ms": (time.perf_counter() - started) * 1000,
                "message": "streaming",
            })

        emit("translation_result", {
            "chunk_id": chunk_id,
            "source_text": source_text,
            "target_text": accumulated_target_text,
            "is_final": True,
            "message": "success",
        })

    except Exception as e:
        print(f"[LỖI XỬ LÝ AUDIO]: {str(e)}")

if __name__ == "__main__":
    print("🚀 Khởi động Server thành công! Hệ thống Streaming đã sẵn sàng...")
    socketio.run(
        app, host="0.0.0.0", port=5000, debug=True,
        allow_unsafe_werkzeug=True,
    )