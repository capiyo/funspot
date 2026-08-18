import 'package:firebase_auth/firebase_auth.dart';

class FirebaseOtpService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _verificationId;

  // Send OTP to phone number
  static Future<bool> sendOtp(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verifies on some devices
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw Exception(e.message);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Verify OTP code
  static Future<bool> verifyOtp(String otpCode) async {
    try {
      if (_verificationId == null) {
        return false;
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sign out from Firebase (clean up)
  static Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
  }
}
