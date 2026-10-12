import 'package:flutter/material.dart';
import '../services/translation_service.dart';

class OneWayTranslationScreen extends StatefulWidget {
  const OneWayTranslationScreen({super.key});

  @override
  State<OneWayTranslationScreen> createState() => _OneWayTranslationScreenState();
}

class _OneWayTranslationScreenState extends State<OneWayTranslationScreen> {
  final TranslationService _translationService = TranslationService();
  final TextEditingController _controller = TextEditingController();
  String _translatedText = '';
  String _targetLang = 'vi';
  bool _isTranslating = false;

  final Map<String, String> _languages = {
    'vi': 'Tiếng Việt',
    'en': 'Tiếng Anh',
    'fr': 'Tiếng Pháp',
    'ja': 'Tiếng Nhật',
    'ko': 'Tiếng Hàn',
    'zh-cn': 'Tiếng Trung',
  };

  void _translate() async {
    if (_controller.text.isEmpty) return;
    setState(() => _isTranslating = true);
    
    String result = await _translationService.translateText(_controller.text, _targetLang);
    
    if (mounted) {
      setState(() {
        _translatedText = result;
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    const Color backgroundGray = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Dịch một chiều',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dịch văn bản',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập nội dung bạn muốn dịch sang ngôn ngữ mục tiêu.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                ),
                const SizedBox(height: 32),
                
                // Input Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        maxLines: 8,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          hintText: 'Nhập nội dung cần dịch...',
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _targetLang,
                                items: _languages.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                                onChanged: (val) => setState(() => _targetLang = val!),
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _isTranslating ? null : _translate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isTranslating 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Dịch thuật', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Result Card
                if (_translatedText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BẢN DỊCH', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SelectableText(
                          _translatedText,
                          style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white60),
                            onPressed: () {
                              // Optional: Add copy to clipboard logic
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
