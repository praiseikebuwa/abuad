import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Check if user has an email/password provider linked
  bool get isPasswordLinked {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  // Sign In with Email and Password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign Up with Email and Password
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Note: Profile creation will be handled by a Cloud Function or manually after this call
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    final actionCodeSettings = ActionCodeSettings(
      url: 'https://abuadapp.web.app/login',
      handleCodeInApp: true,
      androidPackageName: 'com.egcasy.abuad',
      androidInstallApp: true,
      androidMinimumVersion: '1',
      iOSBundleId: 'com.egcasy.abuad',
    );
    await _auth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  // Email Verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final actionCodeSettings = ActionCodeSettings(
      url: 'https://abuadapp.web.app/login',
      handleCodeInApp: true,
      androidPackageName: 'com.egcasy.abuad',
      androidInstallApp: true,
      androidMinimumVersion: '1',
      iOSBundleId: 'com.egcasy.abuad',
    );

    await user.sendEmailVerification(actionCodeSettings);
  }

  // Change Password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final email = user.email;
    if (email == null) throw Exception('User email not found');

    // Re-authenticate user
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          throw Exception('Incorrect current password');
        } else if (e.code == 'weak-password') {
          throw Exception('New password is too weak');
        }
      }
      throw Exception('Failed to change password: $e');
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Link Email/Password to current account
  Future<void> linkWithEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    try {
      await user.linkWithCredential(credential);
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'credential-already-in-use') {
          throw Exception('This email is already linked to another account.');
        } else if (e.code == 'email-already-in-use') {
          throw Exception('This email address is already in use.');
        }
      }
      throw Exception('Failed to link account: $e');
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await user.delete();
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw Exception(
          'Please log out and log back in to delete your account.',
        );
      }
      throw Exception('Failed to delete account: $e');
    }
  }
}
