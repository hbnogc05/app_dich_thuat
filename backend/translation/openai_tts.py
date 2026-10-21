import os
import time
from openai import OpenAI

class OpenAITTSEngine:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    def synthesize(self, text, voice="alloy"):
        start_time = time.perf_counter()
        try:
            response = self.client.audio.speech.create(
                model="tts-1",
                voice=voice,
                input=text
            )
            # Trả về bytes âm thanh
            audio_bytes = response.content
            latency = (time.perf_counter() - start_time) * 1000
            return {
                "audio": audio_bytes,
                "latency_ms": latency
            }
        except Exception as e:
            print(f"TTS Error: {e}")
            return {"audio": None, "latency_ms": 0}
