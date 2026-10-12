import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/landing_page.dart';
import 'screens/translation_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    print("Lỗi khởi tạo Firebase: $e");
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF03A9F4)), // Xanh nước biển nhạt (Light Blue)
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: isFirebaseInitialized 
          ? const AuthWrapper() 
          : const Scaffold(
              body: Center(
                child: Text('Firebase chưa được cấu hình đúng.\nVui lòng chạy "flutterfire configure" hoặc kiểm tra lại tệp cấu hình.'),
              ),
            ),
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
