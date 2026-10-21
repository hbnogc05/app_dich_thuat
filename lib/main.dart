import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/landing_page.dart';
import 'screens/translation_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Nạp biến môi trường từ file .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Không tìm thấy file .env: $e");
  }

  // 2. Khởi tạo Firebase
  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Lỗi khởi tạo Firebase: $e");
  }

  runApp(MyApp(isFirebaseInitialized: isFirebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseInitialized;
  const MyApp({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoTrans - Thông dịch AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF38BDF8),
        cardColor: const Color(0xFF1E293B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF03A9F4),
          brightness: Brightness.dark,
          primary: const Color(0xFF38BDF8),
          surface: const Color(0xFF1E293B),
        ),
      ),
      home: isFirebaseInitialized
          ? const AuthWrapper()
      // Nếu Firebase lỗi cấu hình, vẫn cho phép mở thẳng TranslationScreen để test thuật toán
          : const TranslationScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const TranslationScreen();
        }

        return const LandingPage();
      },
    );
  }
}
