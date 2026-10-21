import os
import time
import io
import soundfile as sf
from openai import OpenAI

class OpenAITranscriber:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    def transcribe(self, audio_data, sample_rate=16000):
        start_time = time.perf_counter()
        
        # Chuyển đổi numpy array thành buffer file wav để gửi cho OpenAI
        buffer = io.BytesIO()
        sf.write(buffer, audio_data, sample_rate, format='wav')
        buffer.seek(0)
        buffer.name = "audio.wav"

        try:
            transcript = self.client.audio.transcriptions.create(
                model="whisper-1",
                file=buffer
            )
            latency = (time.perf_counter() - start_time) * 1000
            return {
                "text": transcript.text,
                "latency_ms": latency
            }
        except Exception as e:
            print(f"STT Error: {e}")
            return {"text": "", "latency_ms": 0}
