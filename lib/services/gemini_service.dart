import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  late final GenerativeModel _model;
  bool _isConfigured = false;
  
  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('Gemini Service Error: Không tìm thấy GEMINI_API_KEY trong file .env');
      return;
    }
    
    // Kiểm tra sơ bộ định dạng Key của Google
    if (!apiKey.startsWith('AIzaSy')) {
      debugPrint('CẢNH BÁO: GEMINI_API_KEY có vẻ không đúng định dạng (nên bắt đầu bằng AIzaSy).');
    }
    
    try {
      _model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );
      _isConfigured = true;
      debugPrint('Gemini Service: Đã cấu hình model gemini-3-flash-preview thành công.');
    } catch (e) {
      debugPrint('Lỗi khởi tạo Gemini Model: $e');
    }
  }

  /// Dịch văn bản trực tiếp qua Google Generative AI
  Future<String> translate(String text, String sourceLang, String targetLang) async {
    if (text.trim().isEmpty) return '';
    
    if (!_isConfigured) {
      return 'Lỗi: Chưa cấu hình API Key hợp lệ trong file .env. Vui lòng kiểm tra lại.';
    }

    final prompt = '''
    Bạn là một chuyên gia thông dịch viên cao cấp.
    Hãy dịch đoạn văn bản sau từ $sourceLang sang $targetLang.
    Chỉ trả về bản dịch duy nhất, không thêm lời giải thích hay bất kỳ ký tự nào khác.
    
    Văn bản cần dịch: "$text"
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final result = response.text?.trim() ?? '';
      
      if (result.isEmpty) {
        return 'Lỗi: AI trả về kết quả rỗng.';
      }
      
      return result;
    } catch (e) {
      debugPrint('Gemini Translation Error: $e');
      
      String errorMsg = e.toString();
      if (errorMsg.contains('403') || errorMsg.contains('permission')) {
        return 'Lỗi: API Key không có quyền truy cập (403). Hãy kiểm tra lại Key.';
      } else if (errorMsg.contains('400')) {
        return 'Lỗi: API Key hoặc yêu cầu không hợp lệ (400).';
      } else if (errorMsg.contains('429')) {
        return 'Lỗi: Hết hạn mức sử dụng miễn phí (Too many requests).';
      }
      
      return 'Lỗi AI: ${errorMsg.length > 50 ? errorMsg.substring(0, 50) + "..." : errorMsg}';
    }
  }

  /// Tóm tắt cuộc hội thoại qua Google Generative AI
  Future<String> summarizeConversation(String conversationText) async {
    if (conversationText.trim().isEmpty) return 'Cuộc hội thoại trống.';
    
    if (!_isConfigured) {
      return 'Lỗi: Chưa cấu hình API Key hợp lệ trong file .env. Vui lòng kiểm tra lại.';
    }

    final prompt = '''
    Bạn là một trợ lý AI thông minh. Hãy tóm tắt lại cuộc hội thoại dưới đây một cách ngắn gọn, súc tích và nêu bật các ý chính.
    
    Cuộc hội thoại:
    $conversationText
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final result = response.text?.trim() ?? '';
      
      if (result.isEmpty) {
        return 'Lỗi: AI trả về kết quả rỗng.';
      }
      
      return result;
    } catch (e) {
      debugPrint('Gemini Summarize Error: $e');
      
      String errorMsg = e.toString();
      if (errorMsg.contains('403') || errorMsg.contains('permission')) {
        return 'Lỗi: API Key không có quyền truy cập (403).';
      } else if (errorMsg.contains('429')) {
        return 'Lỗi: Hết hạn mức sử dụng miễn phí.';
      }
      return 'Lỗi tóm tắt: ${errorMsg.length > 50 ? errorMsg.substring(0, 50) + "..." : errorMsg}';
    }
  }

  /// Đặt tên chủ đề ngắn gọn cho cuộc hội thoại
  Future<String> generateTopicName(String conversationText) async {
    if (conversationText.trim().isEmpty) return 'Cuộc hội thoại trống';
    if (!_isConfigured) return 'Hội thoại chưa đặt tên';

    final prompt = '''
    Bạn là một trợ lý AI. Hãy đọc cuộc hội thoại dưới đây và đặt MỘT TÊN CHỦ ĐỀ thật ngắn gọn (tối đa 6-8 từ, không dùng dấu ngoặc kép, không giải thích thêm).
    
    Cuộc hội thoại:
    $conversationText
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text?.trim() ?? '';
      
      if (result.isEmpty) return 'Chủ đề hội thoại';
      // Xóa dấu ngoặc kép nếu AI vô tình thêm vào
      return result.replaceAll('"', '').replaceAll("'", "");
    } catch (e) {
      debugPrint('Gemini Topic Error: $e');
      return 'Hội thoại chưa đặt tên';
    }
  }
}
