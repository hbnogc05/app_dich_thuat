import 'package:flutter/material.dart';
import 'login_screen.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    const Color lightBlue = Color(0xFFB3E5FC);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Top Banner (Light Blue Gradient)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryBlue, lightBlue],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'MIỄN PHÍ',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        ' Mới: GoTransVoice — Text To Voice & nhận bản giọng AI không giới hạn — dùng thử miễn phí ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                    ],
                  ),
                  const Positioned(
                    right: 20,
                    child: Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            // 2. Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 25),
              child: Row(
                children: [
                  // Logo
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: primaryBlue, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        'GoTrans',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF333333),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Nav Links
                  _buildNavLink('Trang chủ', isActive: true),
                  _buildNavLink('Bảng giá'),
                  _buildNavLink('Tải xuống'),
                  _buildNavLink('Liên hệ'),
                  _buildNavLink('Doanh nghiệp'),
                  const SizedBox(width: 40),
                  // Login Button (Header)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Đăng nhập',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Language Switcher
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          'Tiếng Việt',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),

            // 3. Hero Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Big Title
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 85,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                        height: 1.1,
                        letterSpacing: -3,
                      ),
                      children: [
                        const TextSpan(text: 'Bất cứ gì bạn nghĩ,\ncứ '),
                        const TextSpan(
                          text: 'GoTrans',
                          style: TextStyle(color: primaryBlue),
                        ),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Icon(Icons.auto_awesome, color: primaryBlue, size: 60),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Subtitle Text
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFF444444),
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: 'Trải nghiệm sức mạnh từ '),
                          const TextSpan(
                            text: 'nền tảng thông dịch AI hàng đầu',
                            style: TextStyle(
                              color: primaryBlue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' cho giới chuyên gia. '),
                          const TextSpan(
                            text: 'GoTrans',
                            style: TextStyle(color: primaryBlue),
                          ),
                          const TextSpan(
                            text: ' giúp bạn truyền tải\ntrọn vẹn ý tưởng và cảm xúc trong thời gian thực, dù là họp nhóm hay sự kiện tầm cỡ quốc tế.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // CTA Button (Hero) - Fixed to navigate to Login
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black45,
                    ),
                    child: const Text(
                      'Trải nghiệm miễn phí ngay',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(String title, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          color: isActive ? Colors.black : Colors.black87,
        ),
      ),
    );
  }
}
