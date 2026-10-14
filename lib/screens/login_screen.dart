import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF03A9F4);
    const Color backgroundStart = Color(0xFFF0F9FF);
    const Color backgroundEnd = Color(0xFFE0F2FE);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backgroundStart, backgroundEnd],
          ),
        ),
        child: Stack(
          children: [
            // Back Button
            Positioned(
              top: 30,
              left: 30,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16, color: Colors.black87),
                    SizedBox(width: 5),
                    Text(
                      'Quay lại',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Centered Card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Container(
                  width: 480,
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryBlue, Color(0xFF4FC3F7)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Mừng bạn đến với GoTrans!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Đăng nhập để dịch giọng nói theo thời gian thực,\nnhanh chóng, tự nhiên và liền mạch',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Social Buttons
                        _socialButton(
                          icon: Icons.g_mobiledata, 
                          text: 'Tiếp tục với Google', 
                          isPrimary: true,
                          onPressed: () async {
                            dynamic result = await _auth.signInWithGoogle();
                            if (result == null) {
                              setState(() => error = 'Đăng nhập Google thất bại');
                            } else {
                              if (mounted) Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _socialButton(
                          icon: Icons.facebook, 
                          text: 'Tiếp tục với Facebook',
                          onPressed: () async {
                            dynamic result = await _auth.signInWithFacebook();
                            if (result == null) {
                              setState(() => error = 'Đăng nhập Facebook thất bại');
                            } else {
                              if (mounted) Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _socialButton(
                          icon: Icons.apple, 
                          text: 'Tiếp tục với Apple',
                        ),
                        const SizedBox(height: 12),
                        _socialButton(
                          icon: Icons.window, 
                          text: 'Tiếp tục với Microsoft',
                        ),
                        
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade200)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Hoặc tiếp tục với',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade200)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Form Fields
                        _buildLabel('Địa chỉ email'),
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: _inputDecoration('ten@example.com'),
                          validator: (val) => val!.isEmpty ? 'Vui lòng nhập email' : null,
                          onChanged: (val) => setState(() => email = val),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('Mật khẩu'),
                            TextButton(
                              onPressed: () {}, 
                              child: const Text(
                                'Quên mật khẩu?',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration('••••••••').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) => val!.length < 6 ? 'Mật khẩu phải ít nhất 6 ký tự' : null,
                          onChanged: (val) => setState(() => password = val),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                dynamic result = await _auth.signInWithEmailAndPassword(email, password);
                                if (result == null) {
                                  setState(() => error = 'Thông tin đăng nhập không chính xác');
                                } else {
                                  // Khi đăng nhập thành công, đóng LoginScreen để quay lại AuthWrapper
                                  if (mounted) Navigator.pop(context);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Đăng nhập',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        
                        if (error.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(error, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Chưa có tài khoản? ',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              child: const Text(
                                'Đăng ký',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        const Text(
                          'Bằng việc tiếp tục, bạn đồng ý với chính sách riêng tư',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Chat Bubble
            Positioned(
              bottom: 30,
              right: 30,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF03A9F4), width: 1.5),
      ),
    );
  }

  Widget _socialButton({required IconData icon, required String text, bool isPrimary = false, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(icon, color: isPrimary ? Colors.white : const Color(0xFF1E293B)),
        label: Text(
          text,
          style: TextStyle(
            color: isPrimary ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF0F172A) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: isPrimary ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
