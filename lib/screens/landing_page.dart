import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'login_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    const Color lightBlue = Color(0xFFB3E5FC);
    const Color waterBlue = Color(0xFF00E5FF); // Bright water blue
    const Color deepWaterBlue = Color(0xFF0288D1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Top Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [deepWaterBlue, primaryBlue],
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
                            color: deepWaterBlue,
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
                  _buildNavLink('Trang chủ', isActive: true),
                  _buildNavLink('Bảng giá'),
                  _buildNavLink('Tải xuống'),
                  _buildNavLink('Liên hệ'),
                  _buildNavLink('Doanh nghiệp'),
                  const SizedBox(width: 40),
                  _HoverButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.black, Color(0xFF212121)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: waterBlue.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.language, size: 16, color: primaryBlue),
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

            const SizedBox(height: 20),

            // 3. Hero Section with Water Effects
            Stack(
              alignment: Alignment.center,
              children: [
                // Animated Water Waves Background
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _WavePainter(
                          animationValue: _waveController.value,
                          color: waterBlue.withValues(alpha: 0.05),
                        ),
                      );
                    },
                  ),
                ),

                // Decorative Water Blobs
                Positioned(
                  top: -100,
                  left: -50,
                  child: _buildBlob(500, waterBlue.withValues(alpha: 0.1), useGradient: true),
                ),
                Positioned(
                  bottom: -100,
                  right: -100,
                  child: _buildBlob(400, deepWaterBlue.withValues(alpha: 0.05), useGradient: true),
                ),

                // Floating Icons & Bubbles
                _FloatingElement(
                  controller: _floatController,
                  offset: const Offset(-480, -150),
                  child: Icon(Icons.waves, color: waterBlue.withValues(alpha: 0.8), size: 40),
                ),
                _FloatingElement(
                  controller: _floatController,
                  offset: const Offset(500, 100),
                  delay: 0.5,
                  child: Icon(Icons.opacity, color: primaryBlue.withValues(alpha: 0.6), size: 45),
                ),
                _FloatingElement(
                  controller: _floatController,
                  offset: const Offset(-400, 220),
                  delay: 0.8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: waterBlue.withValues(alpha: 0.5), width: 2),
                    ),
                  ),
                ),
                _FloatingElement(
                  controller: _floatController,
                  offset: const Offset(420, -200),
                  delay: 0.3,
                  child: Icon(Icons.language, color: waterBlue.withValues(alpha: 0.4), size: 50),
                ),

                // Hero Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
                  child: Column(
                    children: [
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
                              style: TextStyle(
                                color: primaryBlue,
                                shadows: [
                                  Shadow(
                                    color: waterBlue,
                                    offset: Offset(0, 4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: AnimatedBuilder(
                                animation: _floatController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: math.sin(_floatController.value * 2 * math.pi) * 0.1,
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 15),
                                      child: Icon(Icons.auto_awesome, color: primaryBlue, size: 60),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                      // CTA Button with Hover Effect
                      _HoverButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.black, Color(0xFF333333)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Trải nghiệm miễn phí ngay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          color: isActive ? const Color(0xFF0288D1) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildBlob(double size, Color color, {bool useGradient = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: useGradient
            ? RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              )
            : null,
        color: useGradient ? null : color,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    final y1 = size.height * 0.7 + math.sin(animationValue * 2 * math.pi) * 20;
    final y2 = size.height * 0.7 + math.cos(animationValue * 2 * math.pi) * 20;

    path.moveTo(0, size.height);
    path.lineTo(0, y1);
    path.quadraticBezierTo(size.width * 0.25, y1 - 30, size.width * 0.5, y1);
    path.quadraticBezierTo(size.width * 0.75, y1 + 30, size.width, y1);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, y2);
    path2.quadraticBezierTo(size.width * 0.25, y2 + 30, size.width * 0.5, y2);
    path2.quadraticBezierTo(size.width * 0.75, y2 - 30, size.width, y2);
    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, Paint()..color = color.withValues(alpha: 0.03));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FloatingElement extends StatelessWidget {
  final AnimationController controller;
  final Widget child;
  final Offset offset;
  final double delay;

  const _FloatingElement({
    required this.controller,
    required this.child,
    required this.offset,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double t = (controller.value + delay) % 1.0;
        final double dy = math.sin(t * 2 * math.pi) * 20;
        final double dx = math.cos(t * 2 * math.pi) * 10;
        return Transform.translate(
          offset: offset + Offset(dx, dy),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _HoverButton({required this.child, required this.onPressed});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
