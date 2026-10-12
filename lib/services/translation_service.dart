import 'package:translator/translator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> translateText(String input, String targetLanguageCode) async {
    if (input.isEmpty) return "";
    try {
      var translation = await _translator.translate(input, to: targetLanguageCode);
      
      // Lưu vào Firestore nếu người dùng đã đăng nhập
      User? user = _auth.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).collection('history').add({
          'originalText': input,
          'translatedText': translation.text,
          'targetLanguage': targetLanguageCode,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      return translation.text;
    } catch (e) {
      print("Translation error: $e");
      return "Error during translation";
    }
  }

  // Lấy lịch sử dịch thuật của người dùng
  Stream<QuerySnapshot> getTranslationHistory() {
    User? user = _auth.currentUser;
    if (user != null) {
      return _db
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }
}
