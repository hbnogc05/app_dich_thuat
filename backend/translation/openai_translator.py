import os
import time
from openai import OpenAI

class OpenAITranslationEngine:
    def __init__(self):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    def translate(self, text, target_lang="Vietnamese"):
        start_time = time.perf_counter()
        try:
            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": f"You are a professional translator. Translate the following text to {target_lang}. Only provide the translation text."},
                    {"role": "user", "content": text}
                ]
            )
            translated_text = response.choices[0].message.content.strip()
            latency = (time.perf_counter() - start_time) * 1000
            return {
                "text": translated_text,
                "latency_ms": latency
            }
        except Exception as e:
            print(f"Translation Error: {e}")
            return {"text": text, "latency_ms": 0}

    def translate_stream(self, text, target_lang="Vietnamese"):
        """
        Dịch thuật streaming sử dụng OpenAI API.
        """
        if not text.strip():
            return

        try:
            stream = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": f"You are a professional translator. Translate the following text to {target_lang}. Only provide the translation text."},
                    {"role": "user", "content": text}
                ],
                stream=True
            )
            for chunk in stream:
                if chunk.choices[0].delta.content is not None:
                    yield chunk.choices[0].delta.content
        except Exception as e:
            print(f"OpenAI Translation Stream Error: {e}")
            yield ""
