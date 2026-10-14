package com.example.app_dich_thuat

import com.google.ai.client.generativeai.GenerativeModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class TranslationService {
    private val model = GenerativeModel(
        modelName = "gemini-1.5-flash",
        apiKey = "AIzaSyBu7CWUFNDmAb8pciCt6eqFRQmXZoKn54Q" // (KEY)
    )

    suspend fun translate(text: String, source: String, target: String): String? {
        return withContext(Dispatchers.IO) {
            try {
                val prompt = "Dịch nội dung sau từ $source sang $target, chỉ trả lời bằng văn bản đã dịch: $text"
                model.generateContent(prompt).text?.trim()
            } catch (e: Exception) { null }
        }
    }
}