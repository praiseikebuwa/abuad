import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../user/data/user_repository.dart';
export '../../user/data/user_repository.dart' show AppUser, userRepositoryProvider, userProvider, isFollowingProvider, isBlockedProvider;
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authRepositoryProvider).currentUserId;
});


class AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  AuthRepository();

  AppUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.uid;
  Stream<AppUser?> get authStateChanges => _controller.stream;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final refreshToken = prefs.getString('refreshToken');

      if (accessToken != null && accessToken.isNotEmpty) {
        await ApiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        final res = await ApiClient.get('/auth/me');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true && data['data'] != null) {
            _currentUser = AppUser.fromMap(data['data']);
            _controller.add(_currentUser);
            return;
          }
        }
        // If access token expired, try refreshing token
        if (refreshToken != null) {
          final refreshed = await ApiClient.refreshToken();
          if (refreshed) {
            final res2 = await ApiClient.get('/auth/me');
            if (res2.statusCode == 200) {
              final data2 = jsonDecode(res2.body);
              if (data2['success'] == true && data2['data'] != null) {
                _currentUser = AppUser.fromMap(data2['data']);
                _controller.add(_currentUser);
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('AuthRepository.init error: $e');
    }
  }

  void setCurrentUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<Map<String, dynamic>?> signInWithEmailAndPassword(String email, String password) async {
    final response = await ApiClient.post('/auth/login', {
      'emailOrUsername': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final accessToken = data['data']['accessToken'];
        final refreshToken = data['data']['refreshToken'];
        ApiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        _currentUser = AppUser.fromMap(data['data']['user']);
        _controller.add(_currentUser);
        return data['data']['user'];
      }
    }
    throw Exception('Login failed: ${response.body}');
  }

  Future<Map<String, dynamic>?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    final response = await ApiClient.post('/auth/register', {
      'email': email,
      'password': password,
      'fullName': fullName,
      'username': username,
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final accessToken = data['data']['accessToken'];
        final refreshToken = data['data']['refreshToken'];
        ApiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        _currentUser = AppUser.fromMap(data['data']['user']);
        _controller.add(_currentUser);
        return data['data']['user'];
      }
    }
    throw Exception('Registration failed: ${response.body}');
  }

  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google sign-in is disabled. Please sign in with email and password.');
  }

  bool get isPasswordLinked => true;

  Future<void> changePassword({String? currentPassword, String? newPassword}) async {
    await ApiClient.post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> linkWithEmailPassword(String email, String password) async {}

  Future<void> deleteAccount() async {
    await ApiClient.post('/auth/delete-account', {});
  }

  Future<void> signOut() async {
    try {
      await ApiClient.post('/auth/logout', {});
    } catch (_) {}
    ApiClient.clearTokens();
    _currentUser = null;
    _controller.add(null);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await ApiClient.post('/auth/forgot-password', {'email': email});
  }
}

