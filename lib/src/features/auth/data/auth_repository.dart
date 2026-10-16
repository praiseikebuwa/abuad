import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_client.dart';
import '../../../core/services/socket_service.dart';
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
  bool _isSigningOut = false;

  AuthRepository();

  AppUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.uid;
  Stream<AppUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  Future<void> init() async {
    try {
      ApiClient.onSessionExpired = () {
        if (!_isSigningOut) {
          debugPrint('⚠️ Session expired received from ApiClient. Signing out...');
          signOut();
        }
      };

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final refreshToken = prefs.getString('refreshToken');
      final cachedUserRaw = prefs.getString('cachedUser');

      if (accessToken != null && accessToken.isNotEmpty) {
        // 1. Instantly restore cached user if valid token exists
        if (cachedUserRaw != null && cachedUserRaw.isNotEmpty) {
          try {
            final data = jsonDecode(cachedUserRaw);
            _currentUser = AppUser.fromMap(data);
            _controller.add(_currentUser);
          } catch (_) {}
        }

        await ApiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        SocketService.instance.connect();
        // 2. Refresh profile in background without stalling the UI
        unawaited(_syncUserProfile(prefs));
      } else {
        // No valid token stored; ensure session is clean
        _currentUser = null;
        _controller.add(null);
        await prefs.remove('cachedUser');
      }
    } catch (e) {
      debugPrint('AuthRepository.init error: $e');
    }
  }

  Future<void> _syncUserProfile([SharedPreferences? existingPrefs]) async {
    try {
      final res = await ApiClient.get('/auth/me');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          _currentUser = AppUser.fromMap(data['data']);
          _controller.add(_currentUser);
          final prefs = existingPrefs ?? await SharedPreferences.getInstance();
          await prefs.setString('cachedUser', jsonEncode(_currentUser!.toMap()));
          return;
        }
      }
      final prefs = existingPrefs ?? await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      if (refreshToken != null) {
        final refreshed = await ApiClient.refreshToken();
        if (refreshed) {
          final res2 = await ApiClient.get('/auth/me');
          if (res2.statusCode == 200) {
            final data2 = jsonDecode(res2.body);
            if (data2['success'] == true && data2['data'] != null) {
              _currentUser = AppUser.fromMap(data2['data']);
              _controller.add(_currentUser);
              await prefs.setString('cachedUser', jsonEncode(_currentUser!.toMap()));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('AuthRepository._syncUserProfile error: $e');
    }
  }

  void setCurrentUser(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
    if (user != null) {
      SharedPreferences.getInstance().then((p) => p.setString('cachedUser', jsonEncode(user.toMap())));
    }
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
        await ApiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        _currentUser = AppUser.fromMap(data['data']['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedUser', jsonEncode(_currentUser!.toMap()));
        _controller.add(_currentUser);
        SocketService.instance.connect();
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
        await ApiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
        _currentUser = AppUser.fromMap(data['data']['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedUser', jsonEncode(_currentUser!.toMap()));
        _controller.add(_currentUser);
        SocketService.instance.connect();
        return data['data']['user'];
      }
    }
    throw Exception('Registration failed: ${response.body}');
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
    if (_isSigningOut) return;
    _isSigningOut = true;
    try {
      SocketService.instance.disconnect();
      final token = ApiClient.accessToken;
      if (token != null) {
        try {
          await http.post(
            Uri.parse('${ApiClient.baseUrl}/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({}),
          ).timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      await ApiClient.clearTokens();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cachedUser');
      _currentUser = null;
      _controller.add(null);
    } finally {
      _isSigningOut = false;
    }
  }

  /// Requests a reset link by email (sent by the backend via Brevo SMTP).
  /// Returns the server's confirmation message; throws with a readable message on failure.
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      final response = await ApiClient.post('/auth/forgot-password', {'email': email})
          .timeout(const Duration(seconds: 15));
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 && data['success'] == true) {
        return (data['message'] as String?) ??
            'If an account exists for that email, a reset link has been sent.';
      }

      final errorMsg = data['error'] ?? data['details'] ?? data['message'];
      if (errorMsg != null && errorMsg.toString().isNotEmpty) {
        throw Exception(errorMsg.toString());
      }

      if (response.statusCode == 504 || response.statusCode == 502) {
        throw Exception('The email service is taking longer than expected. Please try again shortly.');
      }

      throw Exception('Could not send reset email (code ${response.statusCode}). Please try again.');
    } on TimeoutException {
      throw Exception('Request timed out. Please check your internet connection and try again.');
    } catch (e) {
      final str = e.toString().replaceFirst('Exception: ', '');
      if (str.contains('Client load failed') || str.contains('XMLHttpRequest error') || str.contains('SocketException')) {
        throw Exception('Unable to connect to the authentication server. Please check your network connection.');
      }
      throw Exception(str);
    }
  }
}

