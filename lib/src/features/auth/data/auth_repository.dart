import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../user/data/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._firebaseAuth, this._firestore);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      final handle = email.split('@')[0];
      final appUser = AppUser(
        uid: user.uid,
        displayName: handle,
        email: email,
        handle: handle,
        isVerified: false,
        followersCount: 0,
        followingCount: 0,
        status: 'online',
      );

      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
