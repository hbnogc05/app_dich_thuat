package com.example.app_dich_thuat

import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

data class TranslationRecord(
    val userId: String = "",
    val originalText: String = "",
    val translatedText: String = "",
    val sourceLang: String = "",
    val targetLang: String = "",
    val timestamp: Long = System.currentTimeMillis()
)

class DatabaseManager {
    private val db = FirebaseFirestore.getInstance()

    suspend fun saveHistory(record: TranslationRecord): Boolean {
        return try {
            db.collection("translation_history").add(record).await()
            true
        } catch (e: Exception) { false }
    }
}