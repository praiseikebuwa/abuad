import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../user/data/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Stream<User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((event) {
        return event.session?.user;
      });

  User? get currentUser => _supabase.auth.currentUser;

  // Sign In with Email and Password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  // Sign Up with Email and Password
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
    // Note: Profile creation is handled by Database Trigger (schema.sql)
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}
