import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Register with email, password and full name
  Future<User?> registerWithEmailAndPassword(String email, String password, String fullName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      
      // Update the display name in Firebase Auth
      await user?.updateDisplayName(fullName);
      await user?.reload();
      
      return _auth.currentUser;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '621700551720-s4fqdsaur5onaeg7r4prcs7aod5esjmp.apps.googleusercontent.com' : null,
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      if (googleAuth != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential result = await _auth.signInWithCredential(credential);
        return result.user;
      }
      return null;
    } catch (e) {
      print("Google Sign In Error: $e");
      return null;
    }
  }

  // Sign in with Facebook
  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult loginResult = await FacebookAuth.instance.login();
      
      if (loginResult.status == LoginStatus.success) {
        final AccessToken accessToken = loginResult.accessToken!;
        final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.token);
        UserCredential result = await _auth.signInWithCredential(credential);
        return result.user;
      } else {
        print("Facebook Login Failed: ${loginResult.message}");
        return null;
      }
    } catch (e) {
      print("Facebook Sign In Error: $e");
      return null;
    }
  }

  // Sign out
  Future signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Auth change user stream
  Stream<User?> get user {
    return _auth.authStateChanges();
  }
}
