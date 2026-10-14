package com.example.app_dich_thuat

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.tasks.await
import com.google.firebase.auth.AuthCredential
import com.google.firebase.auth.FacebookAuthProvider

class AuthManager {
    private val auth = FirebaseAuth.getInstance()

    // Lấy ID người dùng
    fun getCurrentUserId(): String? = auth.currentUser?.uid

    // Đăng nhập
    suspend fun login(email: String, pass: String): Boolean {
        return try { auth.signInWithEmailAndPassword(email, pass).await(); true }
        catch (e: Exception) { false }
    }

    // Đăng ký
    suspend fun register(email: String, pass: String): Boolean {
        return try { auth.createUserWithEmailAndPassword(email, pass).await(); true }
        catch (e: Exception) { false }
    }
    suspend fun loginWithCredential(credential: AuthCredential): Boolean {
        return try {
            auth.signInWithCredential(credential).await()
            true
        } catch (e: Exception) {
            false
        }
    // Hàm mới xử lý đăng nhập bằng Token của Facebook
    suspend fun loginWithFacebookToken(accessToken: String): Boolean {
        return try {
            // Biến đổi token của Facebook thành thẻ của Firebase
            val credential = FacebookAuthProvider.getCredential(accessToken)
            auth.signInWithCredential(credential).await()
            true
        } catch (e: Exception) {
            false
        }
}