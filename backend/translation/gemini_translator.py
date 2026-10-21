import os
from google import genai # Hoặc import google.generativeai as genai tùy theo SDK bạn đang cài

class GeminiTranslationEngine:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        # Khởi tạo client Gemini mới nhất
        self.client = genai.Client(api_key=self.api_key)

    def translate_stream(self, text: str, target_lang: str = "English"):
        """
        Hàm dịch thuật hỗ trợ Stream từng phần (chunks/words).
        """
        if not text.strip():
            return

        prompt = f"Translate the following text to {target_lang}. Provide only the translated text naturally: {text}"

        try:
            # Sử dụng models.generate_content_stream để lấy dữ liệu dạng luồng
            response = self.client.models.generate_content_stream(
                model='gemini-3.0-flash',
                contents=prompt,
            )
            for chunk in response:
                if chunk.text:
                    yield chunk.text
        except Exception as e:
            print(f"Lỗi Gemini Translation Stream: {e}")
            yield ""