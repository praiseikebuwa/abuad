class AuthErrorHandler {
  static String getErrorMessage(Object error) {
    final msg = error.toString();
    if (msg.contains('user-not-found') || msg.contains('Invalid credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (msg.contains('email-already-in-use') || msg.contains('already registered')) {
      return 'An account already exists with this email.';
    }
    if (msg.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    return msg.replaceAll('Exception:', '').trim();
  }
}
